import 'package:flutter/material.dart';

class DetectionPage extends StatefulWidget {
  const DetectionPage({super.key});

  @override
  State<DetectionPage> createState() => _DetectionPageState();
}

class _DetectionPageState extends State<DetectionPage> {
  // Status sementara untuk tampilan.
  // Nanti nilainya akan berasal dari hasil liveness anggota 2.
  bool faceDetected = false;
  bool blinkDetected = false;
  bool headMovementDetected = false;
  bool mouthMovementDetected = false;

  double livenessScore = 0.0;
  bool isLive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Liveness Detection'),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // =========================
            // AREA KAMERA
            // =========================
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    'KAMERA',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // =========================
            // STATUS WAJAH
            // =========================
            Text(
              faceDetected
                  ? 'Wajah terdeteksi'
                  : 'Wajah belum terdeteksi',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 15),

            // =========================
            // HASIL DETEKSI
            // =========================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _statusRow(
                    'Kedipan',
                    blinkDetected,
                  ),

                  _statusRow(
                    'Gerakan Kepala',
                    headMovementDetected,
                  ),

                  _statusRow(
                    'Gerakan Mulut',
                    mouthMovementDetected,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // =========================
            // SCORE 
            // =========================
            Text(
              'Liveness Score: ${(livenessScore * 100).toStringAsFixed(0)}%',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            // =========================
            // HASIL AKHIR
            // =========================
            Text(
              isLive ? 'LIVE' : 'BELUM TERDETEKSI',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isLive ? Colors.green : Colors.orange,
              ),
            ),

            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // Widget kecil untuk menampilkan status setiap pemeriksaan.
  Widget _statusRow(String title, bool detected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.cancel,
            color: detected ? Colors.green : Colors.red,
          ),

          const SizedBox(width: 10),

          Text(
            title,
            style: const TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }
}