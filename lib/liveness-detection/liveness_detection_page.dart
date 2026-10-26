import 'package:flutter/material.dart';
import '../pages/camera_page.dart';


import 'liveness_status_card.dart';
import 'liveness_result_card.dart';

class LivenessDetectionPage extends StatefulWidget {
  const LivenessDetectionPage({super.key});

  @override
  State<LivenessDetectionPage> createState() =>
      _LivenessDetectionPageState();
}

class _LivenessDetectionPageState
    extends State<LivenessDetectionPage> {
  // Nilai awal untuk prototipe UI.
  // Nantinya diganti dengan hasil deteksi kamera dan algoritma.
  bool faceDetected = false;
  bool blinkDetected = false;
  bool headMovementDetected = false;
  bool mouthMovementDetected = false;

  double livenessScore = 0;
  bool? isLive;

  void _refreshStatus() {
    // Belum menjalankan deteksi sungguhan.
    // Tombol ini hanya mengembalikan UI ke status awal.
    setState(() {
      faceDetected = false;
      blinkDetected = false;
      headMovementDetected = false;
      mouthMovementDetected = false;
      livenessScore = 0;
      isLive = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Status tampilan diperbarui. '
          'Deteksi kamera belum dihubungkan.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FD),
      appBar: AppBar(
        backgroundColor: const Color(0xFF23477F),
        foregroundColor: Colors.white,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: const Text(
          'Face Liveness Detection',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Pengaturan belum tersedia.'),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCameraArea(),
              const SizedBox(height: 18),

              LivenessStatusCard(
                title: 'Status Wajah',
                description: faceDetected
                    ? 'Wajah terdeteksi'
                    : 'Wajah belum terdeteksi',
                detected: faceDetected,
              ),
              const SizedBox(height: 18),

              _buildChecksCard(),
              const SizedBox(height: 18),

              LivenessResultCard(
                score: livenessScore,
                isLive: isLive,
              ),
              const SizedBox(height: 18),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: _refreshStatus,
                  icon: const Icon(Icons.refresh),
                  label: const Text(
                    'Perbarui Status',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF23477F),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              const Center(
                child: Text(
                  'Pastikan wajah terlihat jelas di depan '
                  'kamera untuk hasil yang akurat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF647392),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  
Widget _buildCameraArea() {
  return InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const CameraPage(),
        ),
      );
    },
    child: Container(
      height: 250,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF777980),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.camera_alt_outlined,
                  color: Colors.white,
                  size: 65,
                ),
                SizedBox(height: 10),
                Text(
                  'Tekan untuk membuka kamera',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          // Label LIVE
          Positioned(
            top: 14,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    color: Colors.red,
                    size: 10,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'LIVE',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bingkai wajah
          
 // Bingkai wajah yang lebih besar
Center(
  child: Container(
    width: 220,
    height: 200,
    decoration: BoxDecoration(
      border: Border.all(
        color: Colors.white,
        width: 3,
      ),
      borderRadius: BorderRadius.circular(30),
    ),
  ),
),


          // Informasi status wajah
          Positioned(
            bottom: 14,
            left: 12,
            right: 12,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  faceDetected
                      ? 'Wajah berhasil terdeteksi'
                      : 'Tekan untuk membuka kamera',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}


  Widget _buildChecksCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF3FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFD9E5FF),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pemeriksaan Liveness',
            style: TextStyle(
              color: Color(0xFF23477F),
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _checkItem(
                  icon: Icons.remove_red_eye_outlined,
                  title: 'Kedipan Mata',
                  detected: blinkDetected,
                  color: const Color(0xFFD6E5FF),
                  iconColor: const Color(0xFF2366CF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _checkItem(
                  icon: Icons.face_outlined,
                  title: 'Gerakan Kepala',
                  detected: headMovementDetected,
                  color: const Color(0xFFE5D9FF),
                  iconColor: const Color(0xFF6542C0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _checkItem(
                  icon: Icons.mood_outlined,
                  title: 'Gerakan Mulut',
                  detected: mouthMovementDetected,
                  color: const Color(0xFFFFDCE8),
                  iconColor: const Color(0xFFD82F70),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _checkItem({
    required IconData icon,
    required String title,
    required bool detected,
    required Color color,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 25),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF23477F),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        Text(
          detected ? 'Selesai' : '-',
          style: const TextStyle(
            color: Color(0xFF647392),
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 5,
          ),
          decoration: BoxDecoration(
            color: detected
                ? const Color(0xFFDDF7E5)
                : const Color(0xFFE1E6EF),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            detected ? 'Selesai' : 'Menunggu',
            style: TextStyle(
              fontSize: 10,
              color: detected
                  ? Colors.green.shade800
                  : const Color(0xFF647392),
            ),
          ),
        ),
      ],
    );
  }
}
