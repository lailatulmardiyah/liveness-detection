import 'dart:io';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

import '../services/liveness_random_forest.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  Map<String, double> _calculateTextureFeatures(CameraImage image, Face face) {
    final plane = image.planes[0];

    final bytes = plane.bytes;
    final bytesPerRow = plane.bytesPerRow;

    final imageWidth = image.width;
    final imageHeight = image.height;

    int left = face.boundingBox.left.floor();
    int top = face.boundingBox.top.floor();
    int right = face.boundingBox.right.ceil();
    int bottom = face.boundingBox.bottom.ceil();

    // Batasi bounding box agar tidak keluar dari gambar.
    left = left.clamp(1, imageWidth - 2);
    top = top.clamp(1, imageHeight - 2);
    right = right.clamp(left + 1, imageWidth - 1);
    bottom = bottom.clamp(top + 1, imageHeight - 1);

    double sum = 0;
    double sumSquared = 0;
    int count = 0;

    double laplacianSum = 0;
    double laplacianSquaredSum = 0;
    int laplacianCount = 0;

    int edgeCount = 0;

    // Sampling agar perhitungan tidak terlalu berat.
    const step = 2;

    for (int y = top; y < bottom; y += step) {
      for (int x = left; x < right; x += step) {
        final index = y * bytesPerRow + x;

        if (index < 0 || index >= bytes.length) {
          continue;
        }

        final center = bytes[index].toDouble();

        sum += center;
        sumSquared += center * center;
        count++;

        // Pastikan tetangga tersedia.
        if (x > left && x < right - 1 && y > top && y < bottom - 1) {
          final leftPixel = bytes[y * bytesPerRow + (x - 1)].toDouble();

          final rightPixel = bytes[y * bytesPerRow + (x + 1)].toDouble();

          final topPixel = bytes[(y - 1) * bytesPerRow + x].toDouble();

          final bottomPixel = bytes[(y + 1) * bytesPerRow + x].toDouble();

          // Laplacian 3x3 sederhana:
          // L = kiri + kanan + atas + bawah - 4 * tengah
          final laplacian =
              leftPixel + rightPixel + topPixel + bottomPixel - (4 * center);

          laplacianSum += laplacian;
          laplacianSquaredSum += laplacian * laplacian;
          laplacianCount++;

          // Gradient sederhana untuk edge density.
          final gradientX = (rightPixel - leftPixel).abs();
          final gradientY = (bottomPixel - topPixel).abs();

          final gradient = gradientX + gradientY;

          if (gradient > 40) {
            edgeCount++;
          }
        }
      }
    }

    if (count == 0 || laplacianCount == 0) {
      return {
        'laplacian_variance': 0,
        'edge_density': 0,
        'intensity_mean': 0,
        'intensity_std': 0,
      };
    }

    final intensityMean = sum / count;

    final intensityVariance =
        (sumSquared / count) - (intensityMean * intensityMean);

    final laplacianMean = laplacianSum / laplacianCount;

    final laplacianVariance =
        (laplacianSquaredSum / laplacianCount) -
        (laplacianMean * laplacianMean);

    final edgeDensity = edgeCount / laplacianCount;

    return {
      'laplacian_variance': laplacianVariance < 0 ? 0 : laplacianVariance,

      'edge_density': edgeDensity,

      'intensity_mean': intensityMean,

      'intensity_std': intensityVariance <= 0 ? 0 : sqrt(intensityVariance),
    };
  }

  // ============================================================
  // 1. CAMERA
  // ============================================================

  CameraController? _cameraController;

  bool _isCameraInitialized = false;

  // Mencegah beberapa frame diproses bersamaan.
  bool _isProcessing = false;
  DateTime? _lastProcessedTime;

  // Nomor frame yang berhasil diproses.
  int _frameNumber = 0;
  String _sessionId = '';

  // ============================================================
  // 2. HASIL DETEKSI MATA
  // ============================================================

  double? _leftEyeProbability;
  double? _rightEyeProbability;

  // Jumlah wajah yang terdeteksi pada frame terakhir.
  int _faceCount = 0;

  double? _headEulerAngleX;
  double? _headEulerAngleY;
  double? _headEulerAngleZ;

  // Threshold texture hasil eksperimen
  static const double _laplacianThreshold = 163.0;

  // Hasil klasifikasi texture
  String _textureClassification = '-';

  // Hasil klasifikasi dari model Random Forest
  LivenessRandomForest? _livenessModel;
  String _modelClassification = '-';
  bool _isModelReady = false;

  // File CSV untuk menyimpan data eksperimen.
  File? _csvFile;

  // Membuat file CSV.
  Future<void> _initializeCsv() async {
    final directory = await getApplicationDocumentsDirectory();

    final file = File('${directory.path}/face_liveness_texture_data_v2.csv');

    _csvFile = file;

    // Jika file belum ada, buat header CSV.
    if (!await file.exists()) {
      await file.writeAsString(
        'session_id,frame,timestamp,face_count,left_eye_probability,right_eye_probability,head_euler_angle_x,head_euler_angle_y,head_euler_angle_z,laplacian_variance,edge_density,intensity_mean,intensity_std,model_classification,real_votes,replay_votes,confidence_vote_fraction,texture_classification\n',
      );
    }

    debugPrint('CSV tersimpan di: ${file.path}');
  }

  // Menyimpan data setiap frame ke CSV.
  Future<void> _saveFrameToCsv({
    required String sessionId,
    required int frame,
    required String timestamp,
    required int faceCount,
    required double? leftEye,
    required double? rightEye,
    required double? headX,
    required double? headY,
    required double? headZ,
    required double laplacianVariance,
    required double edgeDensity,
    required double intensityMean,
    required double intensityStd,

    required String modelClassification,
    required int realVotes,
    required int replayVotes,
    required double confidenceVoteFraction,
    required String textureClassification,
  }) async {
    if (_csvFile == null) {
      return;
    }

    final row = [
      sessionId,
      frame,
      timestamp,
      faceCount,
      leftEye ?? '',
      rightEye ?? '',
      headX ?? '',
      headY ?? '',
      headZ ?? '',
      laplacianVariance,
      edgeDensity,
      intensityMean,
      intensityStd,

      modelClassification,
      realVotes,
      replayVotes,
      confidenceVoteFraction,
      textureClassification,
    ];

    await _csvFile!.writeAsString(
      '${const ListToCsvConverter().convert([row])}\n',
      mode: FileMode.append,
    );
  }
  // ============================================================
  // 3. FACE DETECTOR ML KIT
  // ============================================================

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      // WAJIB untuk mendapatkan classification
      // seperti eye-open probability.
      enableClassification: true,

      // Belum diperlukan untuk eksperimen blink
      // berbasis eyeOpenProbability.
      enableLandmarks: false,

      // Belum diperlukan.
      enableContours: false,

      // Belum diperlukan.
      enableTracking: false,

      // Kita mengutamakan kecepatan karena
      // gambar berasal dari kamera secara real-time.
      performanceMode: FaceDetectorMode.fast,
    ),
  );

  // ============================================================
  // 4. INITIALIZATION
  // ============================================================

  @override
  void initState() {
    super.initState();

    _sessionId = DateTime.now().toIso8601String();
    _lastProcessedTime = null;

    _initializeCsv();
    _initializeCamera();
    _loadLivenessModel();
  }

  Future<void> _loadLivenessModel() async {
    try {
      final model = await LivenessRandomForest.load();

      if (!mounted) return;

      setState(() {
        _livenessModel = model;
        _isModelReady = true;
      });

      debugPrint('Model Random Forest berhasil dimuat.');
    } catch (e) {
      debugPrint('Gagal memuat model Random Forest: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      // Mengambil semua kamera yang tersedia.
      final cameras = await availableCameras();

      if (cameras.isEmpty) {
        debugPrint('Tidak ada kamera yang tersedia.');
        return;
      }

      // Mencari kamera depan.
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Membuat CameraController.
      _cameraController = CameraController(
        frontCamera,

        // Resolusi medium cukup untuk eksperimen awal.
        ResolutionPreset.low,

        // Kita tidak membutuhkan audio.
        enableAudio: false,

        // ML Kit Commons merekomendasikan NV21
        // untuk image stream Android.
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      // Inisialisasi kamera.
      await _cameraController!.initialize();

      if (!mounted) {
        return;
      }

      setState(() {
        _isCameraInitialized = true;
      });

      // Mulai menerima frame kamera.
      await _cameraController!.startImageStream(_processCameraImage);
    } catch (e) {
      debugPrint('Gagal menginisialisasi kamera: $e');
    }
  }

  // ============================================================
  // 5. MEMPROSES SETIAP FRAME KAMERA
  // ============================================================

  Future<void> _processCameraImage(CameraImage image) async {
    // Membatasi pengambilan sampel menjadi maksimal
    // sekitar 10 sampel per detik.
    final now = DateTime.now();

    if (_lastProcessedTime != null &&
        now.difference(_lastProcessedTime!) <
            const Duration(milliseconds: 100)) {
      return;
    }

    // Jika frame sebelumnya masih diproses,
    // frame baru dilewati.
    if (_isProcessing) {
      return;
    }

    // Catat waktu saat frame diterima untuk diproses.
    _lastProcessedTime = now;

    _isProcessing = true;

    try {
      // --------------------------------------------------------
      // A. CameraImage -> InputImage
      // --------------------------------------------------------

      final inputImage = _inputImageFromCameraImage(image);

      if (inputImage == null) {
        return;
      }

      // --------------------------------------------------------
      // B. InputImage -> ML Kit FaceDetector
      // --------------------------------------------------------

      final faces = await _faceDetector.processImage(inputImage);

      // --------------------------------------------------------
      // C. Tidak ada wajah
      // --------------------------------------------------------

      if (faces.isEmpty) {
        if (mounted) {
          setState(() {
            _faceCount = 0;
            _leftEyeProbability = null;
            _rightEyeProbability = null;
          });
        }

        return;
      }

      // --------------------------------------------------------
      // D. Ambil wajah pertama
      // --------------------------------------------------------

      final face = faces.first;

      final textureFeatures = _calculateTextureFeatures(image, face);

      final model = _livenessModel;

      String modelClassification = '-';
      int realVotes = 0;
      int replayVotes = 0;
      double confidenceVoteFraction = 0.0;

      if (model != null) {
        final prediction = model.predict(
          laplacianVariance: (textureFeatures['laplacian_variance'] ?? 0)
              .toDouble(),
          edgeDensity: (textureFeatures['edge_density'] ?? 0).toDouble(),
          intensityMean: (textureFeatures['intensity_mean'] ?? 0).toDouble(),
          intensityStd: (textureFeatures['intensity_std'] ?? 0).toDouble(),
        );

        modelClassification = prediction['label'] as String;

        realVotes = prediction['real_votes'] as int;
        replayVotes = prediction['replay_votes'] as int;

        confidenceVoteFraction = (prediction['confidence_vote_fraction'] as num)
            .toDouble();
      }

      final laplacianVariance = textureFeatures['laplacian_variance'] ?? 0;

      final textureClassification = laplacianVariance >= _laplacianThreshold
          ? 'REAL'
          : 'REPLAY';

      // --------------------------------------------------------
      // E. Tambahkan nomor frame
      // --------------------------------------------------------

      _frameNumber++;

      // --------------------------------------------------------
      // F. Ambil probability mata
      // --------------------------------------------------------

      final leftEye = face.leftEyeOpenProbability;

      final rightEye = face.rightEyeOpenProbability;

      final headX = face.headEulerAngleX;
      final headY = face.headEulerAngleY;
      final headZ = face.headEulerAngleZ;

      // --------------------------------------------------------
      // G. Tampilkan hasil ke UI
      // --------------------------------------------------------

      if (mounted) {
        setState(() {
          _faceCount = faces.length;

          _leftEyeProbability = leftEye;

          _rightEyeProbability = rightEye;

          _headEulerAngleX = headX;

          _headEulerAngleY = headY;

          _headEulerAngleZ = headZ;

          _textureClassification = textureClassification;

          _modelClassification = modelClassification;
        });
      }

      await _saveFrameToCsv(
        sessionId: _sessionId,
        frame: _frameNumber,
        timestamp: now.toIso8601String(),
        faceCount: faces.length,
        leftEye: leftEye,
        rightEye: rightEye,
        headX: headX,
        headY: headY,
        headZ: headZ,
        laplacianVariance: textureFeatures['laplacian_variance'] ?? 0,
        edgeDensity: textureFeatures['edge_density'] ?? 0,
        intensityMean: textureFeatures['intensity_mean'] ?? 0,
        intensityStd: textureFeatures['intensity_std'] ?? 0,

        modelClassification: modelClassification,
        realVotes: realVotes,
        replayVotes: replayVotes,
        confidenceVoteFraction: confidenceVoteFraction,
        textureClassification: textureClassification,
      );

      // --------------------------------------------------------
      // H. Debug console
      // --------------------------------------------------------

      debugPrint(
        'Session: $_sessionId | '
        'Frame $_frameNumber | '
        'Faces: ${faces.length} | '
        'Left: ${leftEye?.toStringAsFixed(3) ?? "null"} | '
        'Right: ${rightEye?.toStringAsFixed(3) ?? "null"} | '
        'HeadX: ${headX?.toStringAsFixed(2) ?? "null"} | '
        'HeadY: ${headY?.toStringAsFixed(2) ?? "null"} | '
        'HeadZ: ${headZ?.toStringAsFixed(2) ?? "null"} | '
        'Laplacian: '
        '${textureFeatures['laplacian_variance']?.toStringAsFixed(2) ?? "0"} | '
        'Texture Classification: $textureClassification | '
        'Edge: '
        '${textureFeatures['edge_density']?.toStringAsFixed(4) ?? "0"} | '
        'Intensity Mean: '
        '${textureFeatures['intensity_mean']?.toStringAsFixed(2) ?? "0"} | '
        'Intensity Std: '
        '${textureFeatures['intensity_std']?.toStringAsFixed(2) ?? "0"}',
      );
    } catch (e) {
      debugPrint('Error saat memproses frame: $e');
    } finally {
      // Mengizinkan frame berikutnya diproses.
      _isProcessing = false;
    }
  }

  // ============================================================
  // 6. CAMERAIMAGE -> INPUTIMAGE
  // ============================================================

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    final camera = _cameraController;

    if (camera == null) {
      return null;
    }

    final cameraDescription = camera.description;

    // Sensor orientation kamera.
    final sensorOrientation = cameraDescription.sensorOrientation;

    // Untuk eksperimen Android portrait dengan kamera depan,
    // kita gunakan rotation berdasarkan sensor kamera.
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);

    if (rotation == null) {
      return null;
    }

    // Pastikan frame memiliki satu plane.
    if (image.planes.length != 1) {
      debugPrint('Jumlah plane: ${image.planes.length}');

      return null;
    }

    final plane = image.planes.first;

    // Format frame.
    final format = InputImageFormatValue.fromRawValue(image.format.raw);

    if (format == null) {
      return null;
    }

    return InputImage.fromBytes(
      bytes: plane.bytes,

      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),

        rotation: rotation,

        format: format,

        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
  // ============================================================
  // 7. DISPOSE
  // ============================================================

  @override
  void dispose() {
    _cameraController?.dispose();

    _faceDetector.close();

    super.dispose();
  }

  // ============================================================
  // 8. UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final controller = _cameraController;

    // Kamera belum siap.
    if (!_isCameraInitialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Eksperimen Face Detection')),

      body: Column(
        children: [
          // ------------------------------------------------------
          // CAMERA PREVIEW
          // ------------------------------------------------------

          Expanded(child: CameraPreview(controller)),

          // ------------------------------------------------------
          // INFORMATION PANEL
          // ------------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),

            child: Column(
              children: [
                Text(
                  'Frame: $_frameNumber',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Wajah terdeteksi: $_faceCount',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 8),

                Text(
                  'Left Eye: '
                  '${_leftEyeProbability?.toStringAsFixed(3) ?? "-"}',
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 4),

                Text(
                  'Right Eye: '
                  '${_rightEyeProbability?.toStringAsFixed(3) ?? "-"}',
                  style: const TextStyle(fontSize: 18),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head X: '
                  '${_headEulerAngleX?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head Y: '
                  '${_headEulerAngleY?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head Z: '
                  '${_headEulerAngleZ?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(fontSize: 16),
                ),

                const SizedBox(height: 10),

                Text(
                  'Texture: $_textureClassification',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                Text(
                  'Threshold Laplacian: $_laplacianThreshold',
                  style: const TextStyle(fontSize: 14),
                ),

                const SizedBox(height: 8),

                Text(
                  'Random Forest: '
                  '${_isModelReady ? _modelClassification : "Memuat model..."}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Data di atas adalah hasil deteksi ML Kit '
                  'per frame. Belum merupakan deteksi blink.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
