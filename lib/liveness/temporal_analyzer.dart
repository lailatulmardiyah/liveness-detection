import 'head_pose_detector.dart';

class TemporalAnalyzer {
  final int maxHistory;

  final List<HeadDirection> _headHistory = [];

  TemporalAnalyzer({
    this.maxHistory = 30,
  });

  void addHeadDirection(HeadDirection direction) {
    if (direction == HeadDirection.unknown) {
      return;
    }

    _headHistory.add(direction);

    if (_headHistory.length > maxHistory) {
      _headHistory.removeAt(0);
    }
  }

  bool hasTurnedLeft() {
    return _hasPattern(
      HeadDirection.left,
    );
  }

  bool hasTurnedRight() {
    return _hasPattern(
      HeadDirection.right,
    );
  }

  bool _hasPattern(HeadDirection target) {
    if (_headHistory.length < 3) {
      return false;
    }

    // Kita mencari pola:
    //
    // CENTER → TARGET → CENTER
    //
    // Contoh:
    // CENTER → LEFT → CENTER

    for (int i = 1; i < _headHistory.length - 1; i++) {
      final previous = _headHistory[i - 1];
      final current = _headHistory[i];
      final next = _headHistory[i + 1];

      if (previous == HeadDirection.center &&
          current == target &&
          next == HeadDirection.center) {
        return true;
      }
    }

    return false;
  }

  List<HeadDirection> get history {
    return List.unmodifiable(_headHistory);
  }

  void reset() {
    _headHistory.clear();
  }
}