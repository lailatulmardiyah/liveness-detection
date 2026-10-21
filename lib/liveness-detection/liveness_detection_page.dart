import 'package:flutter/material.dart';
import 'liveness_status_card.dart';
import 'liveness_result_card.dart';
import '../pages/camera_page.dart';

class LivenessDetectionPage extends StatefulWidget {
  const LivenessDetectionPage({super.key});

  @override
  State<LivenessDetectionPage> createState() =>
      _LivenessDetectionPageState();
}

class _LivenessDetectionPageState
    extends State<LivenessDetectionPage> {
  String status = 'Siap memulai';
  bool isStarted = false;
  bool showResult = false;

  
Future<void> startDetection() async {
  setState(() {
    isStarted = true;
    showResult = false;
    status = 'Membuka kamera...';
  });

  try {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CameraPage(),
      ),
    );
  } finally {
    if (!mounted) return;

    setState(() {
      isStarted = false;
      status = 'Siap memulai';
    });
  }
}


  void resetDetection() {
    setState(() {
      isStarted = false;
      showResult = false;
      status = 'Siap memulai';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text(
          'Face Liveness Detection',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF17365D),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Verifikasi Wajah',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF17365D),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan wajah terlihat jelas dan berada '
                'di tengah area kamera.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 24),

              // Placeholder UI, belum terhubung ke kamera.
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: const Color(0xFF172B4D),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 190,
                      height: 220,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF60D6FF),
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: const Icon(
                        Icons.face_retouching_natural,
                        color: Colors.white,
                        size: 100,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Area kamera',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              LivenessStatusCard(status: status),

              const SizedBox(height: 20),

              if (showResult) ...[
                const LivenessResultCard(
                  score: 0,
                  isLive: false,
                ),
                const SizedBox(height: 20),
              ],

              ElevatedButton.icon(
                onPressed: isStarted ? null : startDetection,
                icon: const Icon(Icons.camera_alt),
                label: const Text('Mulai Deteksi'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769AA),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              if (isStarted) ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: resetDetection,
                  child: const Text('Kembali'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
