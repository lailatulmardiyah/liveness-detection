import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class MouthDetector {
  final double smileThreshold;

  MouthDetector({
    this.smileThreshold = 0.70,
  });

  bool detectSmile(Face face) {
    final probability = face.smilingProbability;

    if (probability == null) {
      return false;
    }

    return probability >= smileThreshold;
  }

  void reset() {}
}