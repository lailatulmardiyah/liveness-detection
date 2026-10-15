import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/liveness_result.dart';
import 'blink_detector.dart';
import 'head_pose_detector.dart';
import 'temporal_analyzer.dart';


enum LivenessAction {
  blink,
  turnLeft,
  turnRight,
}

class LivenessAnalyzer {
  final BlinkDetector blinkDetector;
  final HeadPoseDetector headPoseDetector;
  final TemporalAnalyzer temporalAnalyzer;

  LivenessAction selectedAction = LivenessAction.blink;

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

    
if (direction == HeadDirection.left) {
  _turnedLeft = true;
}

if (direction == HeadDirection.right) {
  _turnedRight = true;
}


    // ==========================================
    // 4. HITUNG SCORE
    // ==========================================

    
final double score = switch (selectedAction) {
  LivenessAction.blink =>
    _blinkDetected ? 1.0 : 0.0,
  LivenessAction.turnLeft =>
    _turnedLeft ? 1.0 : 0.0,
  LivenessAction.turnRight =>
    _turnedRight ? 1.0 : 0.0,
};


    // ==========================================
    // 5. CEK LIVE
    // ==========================================

    
late final bool isLive;

switch (selectedAction) {
  case LivenessAction.blink:
    isLive = _blinkDetected;
    break;

  case LivenessAction.turnLeft:
    isLive = _turnedLeft;
    break;

  case LivenessAction.turnRight:
    isLive = _turnedRight;
    break;
}


    // ==========================================
    // 6. TENTUKAN STEP
    // ==========================================

   
String currentStep;

switch (selectedAction) {
  case LivenessAction.blink:
    currentStep = _blinkDetected ? 'COMPLETED' : 'BLINK';
    break;

  case LivenessAction.turnLeft:
    currentStep = _turnedLeft ? 'COMPLETED' : 'TURN LEFT';
    break;

  case LivenessAction.turnRight:
    currentStep = _turnedRight ? 'COMPLETED' : 'TURN RIGHT';
    break;
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