class LivenessResult {
  final bool blinkDetected;
  final bool turnedLeft;
  final bool turnedRight;

  final double score;
  final bool isLive;

  final String currentStep;

  const LivenessResult({
    required this.blinkDetected,
    required this.turnedLeft,
    required this.turnedRight,
    required this.score,
    required this.isLive,
    required this.currentStep,
  });

  factory LivenessResult.initial() {
    return const LivenessResult(
      blinkDetected: false,
      turnedLeft: false,
      turnedRight: false,
      score: 0.0,
      isLive: false,
      currentStep: 'BLINK',
    );
  }
}