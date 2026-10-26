
import 'package:flutter/material.dart';

class LivenessResultCard extends StatelessWidget {
  final double score;
  final bool? isLive;

  const LivenessResultCard({
    super.key,
    required this.score,
    required this.isLive,
  });

  @override
  Widget build(BuildContext context) {
    final double safeScore = score.clamp(0.0, 100.0).toDouble();
    final bool pending = isLive == null;

    final Color resultColor = pending
        ? const Color(0xFFDA7900)
        : isLive!
            ? Colors.green.shade700
            : Colors.red.shade700;

    final String resultText = pending
        ? 'Menunggu hasil pemeriksaan...'
        : isLive!
            ? 'Liveness terverifikasi'
            : 'Liveness belum terverifikasi';

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Liveness Score',
                style: TextStyle(
                  color: Color(0xFF23477F),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  SizedBox(
                    width: 100,
                    height: 100,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: safeScore / 100,
                            strokeWidth: 9,
                            backgroundColor:
                                const Color(0xFFDDE2EB),
                            color: const Color(0xFF23477F),
                          ),
                        ),
                        Text(
                          '${safeScore.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            color: Color(0xFF23477F),
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  const Expanded(
                    child: Text(
                      'Skor liveness akan diperbarui '
                      'setelah analisis selesai.',
                      style: TextStyle(
                        color: Color(0xFF647392),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF5E9),
            border: Border.all(
              color: const Color(0xFFFFDFB5),
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 29,
                backgroundColor: Color(0xFFFFE7C7),
                child: Icon(
                  Icons.hourglass_empty,
                  color: Color(0xFFDE8500),
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hasil Akhir',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF23477F),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      resultText,
                      style: TextStyle(
                        fontSize: 12,
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (pending)
                const SizedBox.shrink()
              else
                Icon(
                  isLive! ? Icons.check_circle : Icons.info_outline,
                  color: resultColor,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
