
import 'package:flutter/material.dart';

const Color livenessNavy = Color(0xFF23477F);
const Color livenessMuted = Color(0xFF647392);

class LivenessStatusCard extends StatelessWidget {
  final String title;
  final String description;
  final bool detected;

  const LivenessStatusCard({
    super.key,
    required this.title,
    required this.description,
    required this.detected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              color: Color(0xFFDCE5FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.face_retouching_natural,
              color: livenessNavy,
              size: 32,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: livenessNavy,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: livenessMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: detected
                  ? const Color(0xFFDDF7E5)
                  : const Color(0xFFFFEDD5),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              detected ? 'TERDETEKSI' : 'MENUNGGU',
              style: TextStyle(
                color: detected
                    ? Colors.green.shade800
                    : const Color(0xFFDA7900),
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
