import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  // ============================================================
  // 1. CAMERA
  // ============================================================

  CameraController? _cameraController;

  bool _isCameraInitialized = false;

  // Mencegah beberapa frame diproses bersamaan.
  bool _isProcessing = false;

  // Nomor frame yang berhasil diproses.
  int _frameNumber = 0;

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

  // File CSV untuk menyimpan data eksperimen.
File? _csvFile;

// Membuat file CSV.
Future<void> _initializeCsv() async {
  final directory = await getApplicationDocumentsDirectory();

  final file = File(
    '${directory.path}/eye_probability_data.csv',
  );

  _csvFile = file;

  // Jika file belum ada, buat header CSV.
  if (!await file.exists()) {
    await file.writeAsString(
      'frame,timestamp,face_count,left_eye_probability,right_eye_probability,head_euler_angle_x,head_euler_angle_y,head_euler_angle_z\n',
    );
  }

  debugPrint('CSV tersimpan di: ${file.path}');
}

// Menyimpan data setiap frame ke CSV.
Future<void> _saveFrameToCsv({
  required int frame,
  required int faceCount,
  required double? leftEye,
  required double? rightEye,
  required double? headX,
  required double? headY,
  required double? headZ,
}) async {
  if (_csvFile == null) {
    return;
  }

  final timestamp = DateTime.now().toIso8601String();

  final row = [
    frame,
    timestamp,
    faceCount,
    leftEye ?? '',
    rightEye ?? '',
    headX ?? '',
    headY ?? '',
    headZ ?? '',
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

     _initializeCsv();
    _initializeCamera();
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
        (camera) =>
            camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      // Membuat CameraController.
      _cameraController = CameraController(
        frontCamera,

        // Resolusi medium cukup untuk eksperimen awal.
        ResolutionPreset.medium,

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
      await _cameraController!.startImageStream(
        _processCameraImage,
      );
    } catch (e) {
      debugPrint(
        'Gagal menginisialisasi kamera: $e',
      );
    }
  }

  // ============================================================
  // 5. MEMPROSES SETIAP FRAME KAMERA
  // ============================================================

  Future<void> _processCameraImage(
    CameraImage image,
  ) async {
    // Jika frame sebelumnya masih diproses,
    // frame baru dilewati.
    if (_isProcessing) {
      return;
    }

    _isProcessing = true;

    try {
      // --------------------------------------------------------
      // A. CameraImage -> InputImage
      // --------------------------------------------------------

      final inputImage =
          _inputImageFromCameraImage(image);

      if (inputImage == null) {
        return;
      }

      // --------------------------------------------------------
      // B. InputImage -> ML Kit FaceDetector
      // --------------------------------------------------------

      final faces = await _faceDetector.processImage(
        inputImage,
      );

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

      // --------------------------------------------------------
      // E. Tambahkan nomor frame
      // --------------------------------------------------------

      _frameNumber++;

      // --------------------------------------------------------
      // F. Ambil probability mata
      // --------------------------------------------------------

      final leftEye =
          face.leftEyeOpenProbability;

      final rightEye =
          face.rightEyeOpenProbability;
      
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
  });
}

await _saveFrameToCsv(
  frame: _frameNumber,
  faceCount: faces.length,
  leftEye: leftEye,
  rightEye: rightEye,
  headX: headX,
  headY: headY,
  headZ: headZ,
);

      // --------------------------------------------------------
      // H. Debug console
      // --------------------------------------------------------

      debugPrint(
      'Frame $_frameNumber | '
      'Faces: ${faces.length} | '
      'Left: ${leftEye?.toStringAsFixed(3) ?? "null"} | '
      'Right: ${rightEye?.toStringAsFixed(3) ?? "null"} | '
      'HeadX: ${headX?.toStringAsFixed(2) ?? "null"} | '
      'HeadY: ${headY?.toStringAsFixed(2) ?? "null"} | '
      'HeadZ: ${headZ?.toStringAsFixed(2) ?? "null"}',
);
    } catch (e) {
      debugPrint(
        'Error saat memproses frame: $e',
      );
    } finally {
      // Mengizinkan frame berikutnya diproses.
      _isProcessing = false;
    }
  }

  // ============================================================
  // 6. CAMERAIMAGE -> INPUTIMAGE
  // ============================================================

  InputImage? _inputImageFromCameraImage(
  CameraImage image,
) {
  final camera = _cameraController;

  if (camera == null) {
    return null;
  }

  final cameraDescription = camera.description;

  // Sensor orientation kamera.
  final sensorOrientation =
      cameraDescription.sensorOrientation;

  // Untuk eksperimen Android portrait dengan kamera depan,
  // kita gunakan rotation berdasarkan sensor kamera.
  final rotation =
      InputImageRotationValue.fromRawValue(
    sensorOrientation,
  );

  if (rotation == null) {
    return null;
  }

  // Pastikan frame memiliki satu plane.
  if (image.planes.length != 1) {
    debugPrint(
      'Jumlah plane: ${image.planes.length}',
    );

    return null;
  }

  final plane = image.planes.first;

  // Format frame.
  final format =
      InputImageFormatValue.fromRawValue(
    image.format.raw,
  );

  if (format == null) {
    return null;
  }

  return InputImage.fromBytes(
    bytes: plane.bytes,

    metadata: InputImageMetadata(
      size: Size(
        image.width.toDouble(),
        image.height.toDouble(),
      ),

      rotation: rotation,

      format: format,

      bytesPerRow:
          plane.bytesPerRow,
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Eksperimen Face Detection',
        ),
      ),

      body: Column(
        children: [
          // ------------------------------------------------------
          // CAMERA PREVIEW
          // ------------------------------------------------------

          Expanded(
            child: CameraPreview(
              controller,
            ),
          ),

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
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Left Eye: '
                  '${_leftEyeProbability?.toStringAsFixed(3) ?? "-"}',
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Right Eye: '
                  '${_rightEyeProbability?.toStringAsFixed(3) ?? "-"}',
                  style: const TextStyle(
                    fontSize: 18,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head X: '
                  '${_headEulerAngleX?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head Y: '
                  '${_headEulerAngleY?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Head Z: '
                  '${_headEulerAngleZ?.toStringAsFixed(2) ?? "-"}°',
                  style: const TextStyle(
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 10),

                const Text(
                  'Data di atas adalah hasil deteksi ML Kit '
                  'per frame. Belum merupakan deteksi blink.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}