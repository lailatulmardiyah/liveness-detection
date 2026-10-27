import 'package:flutter/material.dart';
import '../pages/camera_page.dart';

class LivenessCameraView extends StatelessWidget {
  const LivenessCameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 350,
        width: double.infinity,
        child: const CameraPage(
          embedded: true,
        ),
      ),
    );
  }
}