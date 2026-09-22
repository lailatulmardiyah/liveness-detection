import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class BlinkDetector {
  bool _eyesWereOpen = false;
  bool _eyesWereClosed = false;

  // Threshold awal.
  // Nanti bisa disesuaikan berdasarkan hasil eksperimen.
  final double openThreshold;
  final double closedThreshold;

  BlinkDetector({
    this.openThreshold = 0.70,
    this.closedThreshold = 0.30,
  });

  bool detectBlink(Face face) {
    final leftEye = face.leftEyeOpenProbability;
    final rightEye = face.rightEyeOpenProbability;

    // Kalau ML Kit tidak memberikan nilai mata,
    // kita tidak bisa mendeteksi blink.
    if (leftEye == null || rightEye == null) {
      return false;
    }

    final bool eyesOpen =
        leftEye >= openThreshold &&
        rightEye >= openThreshold;

    final bool eyesClosed =
        leftEye <= closedThreshold &&
        rightEye <= closedThreshold;

    // Kondisi mata kembali terbuka
    // setelah sebelumnya tertutup.
    if (eyesOpen) {
      if (_eyesWereClosed) {
        _eyesWereClosed = false;
        _eyesWereOpen = true;

        return true;
      }

      _eyesWereOpen = true;
    }

    // Mata tertutup setelah sebelumnya terbuka.
    if (eyesClosed && _eyesWereOpen) {
      _eyesWereClosed = true;
    }

    return false;
  }

  void reset() {
    _eyesWereOpen = false;
    _eyesWereClosed = false;
  }
}