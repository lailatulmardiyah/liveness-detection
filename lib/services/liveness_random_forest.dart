import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Native Dart inference for the exported Random Forest.
/// Feature order must match the training CSV exactly.
class LivenessRandomForest {
  LivenessRandomForest._(this._trees);

  final List<_ForestTree> _trees;

  static const List<String> featureOrder = <String>[
    'laplacian_variance',
    'edge_density',
    'intensity_mean',
    'intensity_std',
  ];

  static Future<LivenessRandomForest> load({
    String assetPath = 'assets/models/liveness_random_forest.json',
  }) async {
    final raw = await rootBundle.loadString(assetPath);
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    final rawTrees = parsed['trees'] as List<dynamic>;
    final trees = rawTrees.map((item) {
      final t = item as Map<String, dynamic>;
      return _ForestTree(
        (t['children_left'] as List<dynamic>).map((v) => (v as num).toInt()).toList(),
        (t['children_right'] as List<dynamic>).map((v) => (v as num).toInt()).toList(),
        (t['feature'] as List<dynamic>).map((v) => (v as num).toInt()).toList(),
        (t['threshold'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        (t['value'] as List<dynamic>).map((row) =>
          (row as List<dynamic>).map((v) => (v as num).toDouble()).toList()
        ).toList(),
      );
    }).toList();
    return LivenessRandomForest._(trees);
  }

  /// Returns a map with `label` (REAL/REPLAY), tree vote counts, and vote fraction.
  /// The vote fraction is not a calibrated probability.
  Map<String, dynamic> predict({
    required double laplacianVariance,
    required double edgeDensity,
    required double intensityMean,
    required double intensityStd,
  }) {
    final x = <double>[
      laplacianVariance,
      edgeDensity,
      intensityMean,
      intensityStd,
    ];
    if (x.any((v) => !v.isFinite)) {
      throw ArgumentError('Fitur liveness harus berupa angka finite.');
    }

    var replayVotes = 0;
    var realVotes = 0;

    for (final tree in _trees) {
      var node = 0;
      while (tree.left[node] != -1 && tree.right[node] != -1) {
        final featureIndex = tree.feature[node];
        node = x[featureIndex] <= tree.threshold[node]
            ? tree.left[node]
            : tree.right[node];
      }

      final counts = tree.value[node];
      final predictedClass = counts[1] >= counts[0] ? 1 : 0;
      if (predictedClass == 1) {
        realVotes++;
      } else {
        replayVotes++;
      }
    }

    final total = realVotes + replayVotes;
    final isReal = realVotes > replayVotes;
    return <String, dynamic>{
      'label': isReal ? 'REAL' : 'REPLAY',
      'real_votes': realVotes,
      'replay_votes': replayVotes,
      'confidence_vote_fraction': (isReal ? realVotes : replayVotes) / total,
    };
  }
}

class _ForestTree {
  const _ForestTree(
    this.left,
    this.right,
    this.feature,
    this.threshold,
    this.value,
  );

  final List<int> left;
  final List<int> right;
  final List<int> feature;
  final List<double> threshold;
  final List<List<double>> value;
}
