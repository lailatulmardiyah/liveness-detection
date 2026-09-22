import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

enum HeadDirection {
  left,
  center,
  right,
  unknown,
}

class HeadPoseDetector {
  final double turnThreshold;

  HeadPoseDetector({
    this.turnThreshold = 15.0,
  });

  HeadDirection detect(Face face) {
    final double? angleY = face.headEulerAngleY;

    if (angleY == null) {
      return HeadDirection.unknown;
    }

    if (angleY < -turnThreshold) {
      return HeadDirection.left;
    }

    if (angleY > turnThreshold) {
      return HeadDirection.right;
    }

    return HeadDirection.center;
  }

  void reset() {}
}