import 'dart:collection';
import 'dart:math';

import 'nuts_and_bolts_level_recipes.dart';
import 'nuts_and_bolts_model.dart';
import 'nuts_and_bolts_solver.dart';

enum NutsAndBoltsDifficulty { easy, normal, hard }

extension NutsAndBoltsDifficultyLabel on NutsAndBoltsDifficulty {
  String get label => switch (this) {
    NutsAndBoltsDifficulty.easy => 'Easy',
    NutsAndBoltsDifficulty.normal => 'Normal',
    NutsAndBoltsDifficulty.hard => 'Hard',
  };
}

class NutsAndBoltsBranchingMetadata {
  const NutsAndBoltsBranchingMetadata({
    required this.initialLegalMoves,
    required this.mixedColorBoundaries,
    required this.exploredStates,
  });

  final int initialLegalMoves;
  final int mixedColorBoundaries;
  final int exploredStates;
}

class NutsAndBoltsLevel {
  NutsAndBoltsLevel({
    required this.id,
    required this.difficulty,
    required this.number,
    required this.capacity,
    required this.helperBoltCount,
    required List<List<int>> bolts,
    required this.minimumSolutionMoves,
    required this.branching,
    this.generationAttempt = 0,
  }) : bolts = UnmodifiableListView([
         for (final bolt in bolts) UnmodifiableListView(List<int>.of(bolt)),
       ]);

  final String id;
  final NutsAndBoltsDifficulty difficulty;
  final int number;
  final int capacity;
  final int helperBoltCount;
  final List<List<int>> bolts;
  final int minimumSolutionMoves;
  final NutsAndBoltsBranchingMetadata branching;
  final int generationAttempt;

  int get colorCount => bolts.length - helperBoltCount;
  NutsAndBoltsModel createModel() =>
      NutsAndBoltsModel(bolts: bolts, capacity: capacity);
}

/// Deterministic 180-level launch catalog with prevalidated solver metadata.
class NutsAndBoltsLevelCatalog {
  NutsAndBoltsLevelCatalog._();

  static const levelsPerDifficulty = 60;
  static const totalLevels = 180;
  static final List<NutsAndBoltsLevel> levels = _buildCatalog();

  static List<NutsAndBoltsLevel> forDifficulty(
    NutsAndBoltsDifficulty difficulty,
  ) => List.unmodifiable(
    levels.where((level) => level.difficulty == difficulty),
  );

  static NutsAndBoltsLevel level(
    NutsAndBoltsDifficulty difficulty,
    int number,
  ) {
    if (number < 1 || number > levelsPerDifficulty) {
      throw RangeError.range(number, 1, levelsPerDifficulty, 'number');
    }
    return levels[difficulty.index * levelsPerDifficulty + number - 1];
  }

  static List<NutsAndBoltsLevel> _buildCatalog() {
    final result = <NutsAndBoltsLevel>[];
    final definitions = <String>{};
    for (final difficulty in NutsAndBoltsDifficulty.values) {
      final recipes = nutsAndBoltsLevelRecipes[difficulty.index];
      if (recipes.length != levelsPerDifficulty) {
        throw StateError('${difficulty.name} must define 60 level recipes');
      }
      for (var number = 1; number <= levelsPerDifficulty; number++) {
        final recipe = recipes[number - 1];
        final candidate = _buildCandidate(difficulty, number, recipe.attempt);
        if (candidate.bolts.where((bolt) => bolt.isEmpty).length !=
            candidate.helperBoltCount) {
          throw StateError('${candidate.id} has incorrect helper-bolt data');
        }
        final definition = NutsAndBoltsSolver.stateKey(candidate.bolts);
        if (!definitions.add(definition)) {
          throw StateError('${candidate.id} duplicates an earlier puzzle');
        }
        result.add(
          NutsAndBoltsLevel(
            id: candidate.id,
            difficulty: difficulty,
            number: number,
            capacity: candidate.capacity,
            helperBoltCount: candidate.helperBoltCount,
            bolts: candidate.bolts,
            minimumSolutionMoves: recipe.minimumMoves,
            branching: NutsAndBoltsBranchingMetadata(
              initialLegalMoves: candidate.createModel().legalMoves.length,
              mixedColorBoundaries: _mixedBoundaries(candidate.bolts),
              exploredStates: recipe.exploredStates,
            ),
            generationAttempt: recipe.attempt,
          ),
        );
      }
    }
    return List.unmodifiable(result);
  }

  static NutsAndBoltsLevel _buildCandidate(
    NutsAndBoltsDifficulty difficulty,
    int number,
    int attempt,
  ) {
    final capacity = _capacity(difficulty, number);
    final colors = _colorCount(difficulty, number);
    final helpers = difficulty == NutsAndBoltsDifficulty.hard ? 1 : 2;
    final targetDepth = _targetDepth(difficulty, number) + attempt % 4;
    final seed =
        190001 + difficulty.index * 100000 + number * 997 + attempt * 7919;
    final bolts = _reverseScramble(
      colors: colors,
      capacity: capacity,
      helpers: helpers,
      steps: targetDepth,
      seed: seed,
    );
    return NutsAndBoltsLevel(
      id: '${difficulty.name}-${number.toString().padLeft(2, '0')}',
      difficulty: difficulty,
      number: number,
      capacity: capacity,
      helperBoltCount: helpers,
      bolts: bolts,
      minimumSolutionMoves: 0,
      branching: const NutsAndBoltsBranchingMetadata(
        initialLegalMoves: 0,
        mixedColorBoundaries: 0,
        exploredStates: 0,
      ),
      generationAttempt: attempt,
    );
  }

  static List<List<int>> _reverseScramble({
    required int colors,
    required int capacity,
    required int helpers,
    required int steps,
    required int seed,
  }) {
    final random = Random(seed);
    final bolts = <List<int>>[
      for (var color = 0; color < colors; color++)
        List.filled(capacity, color, growable: true),
      for (var helper = 0; helper < helpers; helper++) <int>[],
    ];
    (int, int)? previous;
    final maximumSteps = steps + capacity * colors * 4;
    for (var step = 0; step < maximumSteps; step++) {
      final candidates = <(int, int)>[];
      for (var destination = 0; destination < bolts.length; destination++) {
        final from = bolts[destination];
        if (from.isEmpty) continue;
        final color = from.last;
        final underneathMatches =
            from.length == 1 || from[from.length - 2] == color;
        if (!underneathMatches) continue;
        for (var source = 0; source < bolts.length; source++) {
          if (source == destination || bolts[source].length == capacity) {
            continue;
          }
          if (bolts[source].isNotEmpty && bolts[source].last == color) {
            continue;
          }
          if (previous == (source, destination)) continue;
          candidates.add((source, destination));
        }
      }
      if (candidates.isEmpty) break;
      final choice = candidates[random.nextInt(candidates.length)];
      final color = bolts[choice.$2].removeLast();
      bolts[choice.$1].add(color);
      previous = (choice.$2, choice.$1);
      if (step + 1 >= steps &&
          bolts.where((bolt) => bolt.isEmpty).length == helpers) {
        break;
      }
    }
    return bolts;
  }

  static bool _matchesBand(
    NutsAndBoltsDifficulty difficulty,
    int number,
    int moves,
  ) {
    final stage = (number - 1) ~/ 10;
    final minimum = switch (difficulty) {
      NutsAndBoltsDifficulty.easy => 3 + stage,
      NutsAndBoltsDifficulty.normal => 6 + stage,
      NutsAndBoltsDifficulty.hard => 8 + stage,
    };
    return moves >= minimum;
  }

  static int _targetDepth(NutsAndBoltsDifficulty difficulty, int number) {
    final stage = (number - 1) ~/ 10;
    return switch (difficulty) {
      NutsAndBoltsDifficulty.easy => 5 + stage * 2,
      NutsAndBoltsDifficulty.normal => 9 + stage * 2,
      NutsAndBoltsDifficulty.hard => 12 + stage * 2,
    };
  }

  static int _capacity(NutsAndBoltsDifficulty difficulty, int number) =>
      switch (difficulty) {
        NutsAndBoltsDifficulty.easy => number <= 20 ? 3 : 4,
        NutsAndBoltsDifficulty.normal => 4,
        NutsAndBoltsDifficulty.hard => number <= 30 ? 4 : 5,
      };

  static int _colorCount(NutsAndBoltsDifficulty difficulty, int number) {
    final zeroBased = number - 1;
    return switch (difficulty) {
      NutsAndBoltsDifficulty.easy => 3 + zeroBased * 3 ~/ levelsPerDifficulty,
      NutsAndBoltsDifficulty.normal => 5 + zeroBased * 4 ~/ levelsPerDifficulty,
      NutsAndBoltsDifficulty.hard => 8 + zeroBased * 5 ~/ levelsPerDifficulty,
    };
  }

  static int _mixedBoundaries(List<List<int>> bolts) {
    var result = 0;
    for (final bolt in bolts) {
      for (var index = 1; index < bolt.length; index++) {
        if (bolt[index] != bolt[index - 1]) result++;
      }
    }
    return result;
  }
}

/// Release-time validation for generated or curated level definitions.
abstract final class NutsAndBoltsLevelValidator {
  static NutsAndBoltsSolution validateLevel(
    NutsAndBoltsLevel level, {
    NutsAndBoltsSolver solver = const NutsAndBoltsSolver(),
  }) {
    final model = level.createModel();
    if (model.isComplete) {
      throw StateError('${level.id} is already solved');
    }
    final counts = <int, int>{};
    for (final bolt in level.bolts) {
      for (final color in bolt) {
        counts.update(color, (count) => count + 1, ifAbsent: () => 1);
      }
    }
    if (counts.length != level.colorCount ||
        counts.values.any((count) => count != level.capacity)) {
      throw StateError('${level.id} has unbalanced color counts');
    }
    final solution = solver.solve(model);
    if (solution == null) {
      throw StateError('${level.id} is impossible within the solver bound');
    }
    if (solution.moveCount != level.minimumSolutionMoves) {
      throw StateError('${level.id} minimum solution metadata is incorrect');
    }
    if (!_matchesDefinition(level, solution.moveCount)) {
      throw StateError('${level.id} is incorrectly classified');
    }
    if (level.branching.initialLegalMoves != model.legalMoves.length ||
        level.branching.mixedColorBoundaries !=
            NutsAndBoltsLevelCatalog._mixedBoundaries(level.bolts) ||
        level.branching.exploredStates != solution.exploredStates) {
      throw StateError('${level.id} branching metadata is incorrect');
    }
    return solution;
  }

  static Map<String, NutsAndBoltsSolution> validateCatalog(
    Iterable<NutsAndBoltsLevel> levels, {
    NutsAndBoltsSolver solver = const NutsAndBoltsSolver(),
  }) {
    final list = levels.toList(growable: false);
    if (list.length != NutsAndBoltsLevelCatalog.totalLevels) {
      throw StateError('Catalog must contain exactly 180 levels');
    }
    final ids = <String>{};
    final definitions = <String>{};
    final solutions = <String, NutsAndBoltsSolution>{};
    for (final difficulty in NutsAndBoltsDifficulty.values) {
      final band = list
          .where((level) => level.difficulty == difficulty)
          .toList(growable: false);
      if (band.length != NutsAndBoltsLevelCatalog.levelsPerDifficulty ||
          !band.indexed.every((entry) => entry.$2.number == entry.$1 + 1)) {
        throw StateError('${difficulty.name} must contain ordered levels 1-60');
      }
    }
    for (final level in list) {
      if (!ids.add(level.id)) {
        throw StateError('Duplicate level ID ${level.id}');
      }
      final definition = NutsAndBoltsSolver.stateKey(level.bolts);
      if (!definitions.add(definition)) {
        throw StateError('Duplicate puzzle definition ${level.id}');
      }
      solutions[level.id] = validateLevel(level, solver: solver);
    }
    return Map.unmodifiable(solutions);
  }

  static bool _matchesDefinition(NutsAndBoltsLevel level, int moves) {
    final expectedHelpers = level.difficulty == NutsAndBoltsDifficulty.hard
        ? 1
        : 2;
    return level.number >= 1 &&
        level.number <= NutsAndBoltsLevelCatalog.levelsPerDifficulty &&
        level.capacity ==
            NutsAndBoltsLevelCatalog._capacity(
              level.difficulty,
              level.number,
            ) &&
        level.colorCount ==
            NutsAndBoltsLevelCatalog._colorCount(
              level.difficulty,
              level.number,
            ) &&
        level.helperBoltCount == expectedHelpers &&
        level.bolts.where((bolt) => bolt.isEmpty).length == expectedHelpers &&
        NutsAndBoltsLevelCatalog._matchesBand(
          level.difficulty,
          level.number,
          moves,
        );
  }
}
