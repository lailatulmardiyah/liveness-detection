import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/liveness_result.dart';
import 'blink_detector.dart';
import 'head_pose_detector.dart';
import 'temporal_analyzer.dart';

class LivenessAnalyzer {
  final BlinkDetector blinkDetector;
  final HeadPoseDetector headPoseDetector;
  final TemporalAnalyzer temporalAnalyzer;

  bool _blinkDetected = false;
  bool _turnedLeft = false;
  bool _turnedRight = false;

  LivenessAnalyzer({
    BlinkDetector? blinkDetector,
    HeadPoseDetector? headPoseDetector,
    TemporalAnalyzer? temporalAnalyzer,
  })  : blinkDetector = blinkDetector ?? BlinkDetector(),
        headPoseDetector =
            headPoseDetector ?? HeadPoseDetector(),
        temporalAnalyzer =
            temporalAnalyzer ?? TemporalAnalyzer();

  LivenessResult processFace(Face face) {
    // ==========================================
    // 1. DETEKSI BLINK
    // ==========================================

    final bool blink =
        blinkDetector.detectBlink(face);

    if (blink) {
      _blinkDetected = true;
    }

    // ==========================================
    // 2. DETEKSI POSISI KEPALA
    // ==========================================

    final HeadDirection direction =
        headPoseDetector.detect(face);

    temporalAnalyzer.addHeadDirection(direction);

    // ==========================================
    // 3. CEK GERAKAN KEPALA
    // ==========================================

    if (temporalAnalyzer.hasTurnedLeft()) {
      _turnedLeft = true;
    }

    if (temporalAnalyzer.hasTurnedRight()) {
      _turnedRight = true;
    }

    // ==========================================
    // 4. HITUNG SCORE
    // ==========================================

    int completed = 0;

    if (_blinkDetected) {
      completed++;
    }

    if (_turnedLeft) {
      completed++;
    }

    if (_turnedRight) {
      completed++;
    }

    final double score = completed / 3.0;

    // ==========================================
    // 5. CEK LIVE
    // ==========================================

    final bool isLive =
        _blinkDetected &&
        _turnedLeft &&
        _turnedRight;

    // ==========================================
    // 6. TENTUKAN STEP
    // ==========================================

    String currentStep;

    if (!_blinkDetected) {
      currentStep = 'BLINK';
    } else if (!_turnedLeft) {
      currentStep = 'TURN LEFT';
    } else if (!_turnedRight) {
      currentStep = 'TURN RIGHT';
    } else {
      currentStep = 'COMPLETED';
    }

    return LivenessResult(
      blinkDetected: _blinkDetected,
      turnedLeft: _turnedLeft,
      turnedRight: _turnedRight,
      score: score,
      isLive: isLive,
      currentStep: currentStep,
    );
  }

  void reset() {
    _blinkDetected = false;
    _turnedLeft = false;
    _turnedRight = false;

    blinkDetector.reset();
    headPoseDetector.reset();
    temporalAnalyzer.reset();
  }
}