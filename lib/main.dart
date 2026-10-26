
import 'package:flutter/material.dart';
import 'liveness-detection/liveness_detection_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const LivenessDetectionApp());
}

class LivenessDetectionApp extends StatelessWidget {
  const LivenessDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Face Liveness Detection',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF3F6FD),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF23477F),
        ),
      ),
    home: const LivenessDetectionPage(),
    );
  }
}
