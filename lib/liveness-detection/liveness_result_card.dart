
import 'package:flutter/material.dart';

class LivenessResultCard extends StatelessWidget {
  final double score;
  final bool isLive;

  const LivenessResultCard({
    super.key,
    required this.score,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final resultColor = isLive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE0E7EF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Hasil Deteksi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                isLive ? Icons.check_circle : Icons.cancel,
                color: resultColor,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isLive ? 'Wajah terindikasi hidup' : 'Belum terverifikasi',
                  style: TextStyle(
                    color: resultColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Skor: ${score.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }
}
