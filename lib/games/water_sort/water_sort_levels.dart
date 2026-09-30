import 'dart:collection';

import 'water_sort_model.dart';

enum WaterSortDifficulty { easy, normal, hard }

extension WaterSortDifficultyLabel on WaterSortDifficulty {
  String get label => switch (this) {
    WaterSortDifficulty.easy => 'Easy',
    WaterSortDifficulty.normal => 'Normal',
    WaterSortDifficulty.hard => 'Hard',
  };
}

class WaterSortBranchingMetadata {
  const WaterSortBranchingMetadata({
    required this.initialLegalMoves,
    required this.mixedColorBoundaries,
  });

  final int initialLegalMoves;
  final int mixedColorBoundaries;
}

class WaterSortLevel {
  WaterSortLevel({
    required this.id,
    required this.difficulty,
    required this.number,
    required this.capacity,
    required this.helperTubeCount,
    required List<List<int>> tubes,
    required this.minimumSolutionMoves,
    required this.branching,
  }) : tubes = UnmodifiableListView([
         for (final tube in tubes) UnmodifiableListView(List<int>.of(tube)),
       ]);

  final String id;
  final WaterSortDifficulty difficulty;
  final int number;
  final int capacity;
  final int helperTubeCount;
  final List<List<int>> tubes;
  final int minimumSolutionMoves;
  final WaterSortBranchingMetadata branching;

  int get colorCount => tubes.length - helperTubeCount;
  WaterSortModel createModel() =>
      WaterSortModel(tubes: tubes, capacity: capacity);
}

/// Compact deterministic launch catalog with 60 levels per difficulty.
class WaterSortLevelCatalog {
  WaterSortLevelCatalog._();

  static const levelsPerDifficulty = 60;
  static const totalLevels = 180;

  static final List<WaterSortLevel> levels = List.unmodifiable([
    for (final difficulty in WaterSortDifficulty.values)
      for (var number = 1; number <= levelsPerDifficulty; number++)
        _buildLevel(difficulty, number),
  ]);

  static List<WaterSortLevel> forDifficulty(WaterSortDifficulty difficulty) =>
      List.unmodifiable(
        levels.where((level) => level.difficulty == difficulty),
      );

  static WaterSortLevel level(WaterSortDifficulty difficulty, int number) {
    if (number < 1 || number > levelsPerDifficulty) {
      throw RangeError.range(number, 1, levelsPerDifficulty, 'number');
    }
    return levels[difficulty.index * levelsPerDifficulty + number - 1];
  }

  static WaterSortLevel _buildLevel(
    WaterSortDifficulty difficulty,
    int number,
  ) {
    const capacity = WaterSortModel.defaultTubeCapacity;
    final colorCount = _colorCount(difficulty, number);
    final helpers = difficulty == WaterSortDifficulty.hard ? 1 : 2;
    final pattern = _patternFor(number);
    final colorRotation = (number * 7 + difficulty.index * 3) % colorCount;
    final tubes = <List<int>>[
      for (var tube = 0; tube < colorCount; tube++)
        [
          for (final offset in pattern.offsets)
            (tube + offset + colorRotation) % colorCount,
        ],
      for (var helper = 0; helper < helpers; helper++) <int>[],
    ];
    final model = WaterSortModel(tubes: tubes, capacity: capacity);
    var boundaries = 0;
    for (final tube in tubes) {
      for (var index = 1; index < tube.length; index++) {
        if (tube[index] != tube[index - 1]) boundaries++;
      }
    }
    return WaterSortLevel(
      id: '${difficulty.name}-${number.toString().padLeft(2, '0')}',
      difficulty: difficulty,
      number: number,
      capacity: capacity,
      helperTubeCount: helpers,
      tubes: tubes,
      minimumSolutionMoves: pattern.solutionMultiplier * colorCount + 1,
      branching: WaterSortBranchingMetadata(
        initialLegalMoves: model.legalMoves.length,
        mixedColorBoundaries: boundaries,
      ),
    );
  }

  static int _colorCount(WaterSortDifficulty difficulty, int number) {
    final zeroBased = number - 1;
    return switch (difficulty) {
      WaterSortDifficulty.easy => 3 + zeroBased * 3 ~/ levelsPerDifficulty,
      WaterSortDifficulty.normal => 5 + zeroBased * 4 ~/ levelsPerDifficulty,
      WaterSortDifficulty.hard => 8 + zeroBased * 5 ~/ levelsPerDifficulty,
    };
  }

  static _WaterSortPattern _patternFor(int number) {
    const introductory = [
      _WaterSortPattern([0, 0, 1, 1], 1),
      _WaterSortPattern([0, 0, 1, 2], 2),
    ];
    const established = [
      _WaterSortPattern([0, 1, 1, 2], 2),
      _WaterSortPattern([0, 1, 2, 2], 2),
      _WaterSortPattern([0, 0, 1, 2], 2),
    ];
    const combined = [
      _WaterSortPattern([0, 1, 2, 3], 3),
      _WaterSortPattern([0, 1, 0, 2], 3),
      _WaterSortPattern([0, 1, 2, 0], 3),
      _WaterSortPattern([0, 1, 2, 1], 3),
    ];
    const mastery = [
      _WaterSortPattern([0, 1, 0, 1], 3),
      _WaterSortPattern([0, 1, 2, 0], 3),
    ];
    if (number <= 10) return introductory[(number - 1) % 2];
    if (number <= 30) return established[(number - 11) % 3];
    if (number <= 50) return combined[(number - 31) % 4];
    return mastery[(number - 51) % 2];
  }
}

class _WaterSortPattern {
  const _WaterSortPattern(this.offsets, this.solutionMultiplier);

  final List<int> offsets;
  final int solutionMultiplier;
}
