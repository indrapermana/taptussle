import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_model.dart';
import 'package:tap_tussle/games/water_sort/water_sort_solver.dart';

void main() {
  group('WaterSortLevelCatalog', () {
    test('contains 60 ordered levels per difficulty and 180 total', () {
      expect(WaterSortLevelCatalog.levels, hasLength(180));
      expect(
        WaterSortLevelCatalog.levels.map((level) => level.id).toSet(),
        hasLength(180),
      );
      for (final difficulty in WaterSortDifficulty.values) {
        final levels = WaterSortLevelCatalog.forDifficulty(difficulty);
        expect(levels, hasLength(60));
        expect(
          levels.map((level) => level.number),
          orderedEquals([for (var number = 1; number <= 60; number++) number]),
        );
        expect(WaterSortLevelCatalog.level(difficulty, 1), same(levels.first));
        expect(WaterSortLevelCatalog.level(difficulty, 60), same(levels.last));
      }
      expect(
        () => WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 0),
        throwsRangeError,
      );
    });

    test('difficulty bands use the confirmed colors and helper tubes', () {
      final easy = WaterSortLevelCatalog.forDifficulty(
        WaterSortDifficulty.easy,
      );
      final normal = WaterSortLevelCatalog.forDifficulty(
        WaterSortDifficulty.normal,
      );
      final hard = WaterSortLevelCatalog.forDifficulty(
        WaterSortDifficulty.hard,
      );
      expect(easy.map((level) => level.colorCount).toSet(), {3, 4, 5});
      expect(normal.map((level) => level.colorCount).toSet(), {5, 6, 7, 8});
      expect(hard.map((level) => level.colorCount).toSet(), {8, 9, 10, 11, 12});
      expect(easy, everyElement(_hasHelpers(2)));
      expect(normal, everyElement(_hasHelpers(2)));
      expect(hard, everyElement(_hasHelpers(1)));
      expect(
        hard.last.minimumSolutionMoves,
        greaterThan(normal[29].minimumSolutionMoves),
      );
      expect(
        normal.last.minimumSolutionMoves,
        greaterThan(easy[29].minimumSolutionMoves),
      );
    });

    test('every definition is balanced, immutable, and records branching', () {
      for (final level in WaterSortLevelCatalog.levels) {
        final counts = <int, int>{};
        for (final tube in level.tubes) {
          expect(
            tube.length,
            lessThanOrEqualTo(level.capacity),
            reason: level.id,
          );
          for (final color in tube) {
            counts.update(color, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        expect(counts, hasLength(level.colorCount), reason: level.id);
        expect(counts.values, everyElement(level.capacity), reason: level.id);
        expect(
          level.branching.initialLegalMoves,
          level.createModel().legalMoves.length,
          reason: level.id,
        );
        expect(
          level.branching.mixedColorBoundaries,
          greaterThan(0),
          reason: level.id,
        );
      }
      expect(
        () => WaterSortLevelCatalog.levels.first.tubes.first.add(99),
        throwsUnsupportedError,
      );
    });

    test(
      'solver proves and production model replays every shortest path',
      () {
        const solver = WaterSortSolver();
        for (final level in WaterSortLevelCatalog.levels) {
          final solution = solver.solve(level.createModel());
          expect(solution, isNotNull, reason: '${level.id} has no solution');
          expect(
            solution!.moveCount,
            level.minimumSolutionMoves,
            reason: '${level.id} minimum solution length drifted',
          );
          var replay = level.createModel();
          for (var step = 0; step < solution.moves.length; step++) {
            final move = solution.moves[step];
            final result = replay.pour(move.source, move.destination);
            expect(
              result.status,
              WaterSortPourStatus.accepted,
              reason: '${level.id} failed replay at step ${step + 1}',
            );
            replay = result.model;
          }
          expect(replay.isComplete, isTrue, reason: level.id);
          expect(
            replay.moveCount,
            level.minimumSolutionMoves,
            reason: level.id,
          );
        }
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  test('solver respects its explicit search bound', () {
    final level = WaterSortLevelCatalog.level(WaterSortDifficulty.hard, 60);
    expect(
      const WaterSortSolver(maxStates: 2).solve(level.createModel()),
      isNull,
    );
  });
}

Matcher _hasHelpers(int count) => isA<WaterSortLevel>()
    .having((level) => level.helperTubeCount, 'helperTubeCount', count)
    .having(
      (level) => level.tubes.where((tube) => tube.isEmpty).length,
      'empty tubes',
      count,
    );
