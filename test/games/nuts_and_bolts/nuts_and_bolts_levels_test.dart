import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_model.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_solver.dart';

void main() {
  group('NutsAndBoltsLevelCatalog', () {
    test('contains 60 ordered levels per difficulty and 180 total', () {
      expect(NutsAndBoltsLevelCatalog.levels, hasLength(180));
      expect(
        NutsAndBoltsLevelCatalog.levels.map((level) => level.id).toSet(),
        hasLength(180),
      );
      for (final difficulty in NutsAndBoltsDifficulty.values) {
        final levels = NutsAndBoltsLevelCatalog.forDifficulty(difficulty);
        expect(levels, hasLength(60));
        expect(
          levels.map((level) => level.number),
          orderedEquals([for (var number = 1; number <= 60; number++) number]),
        );
        expect(NutsAndBoltsLevelCatalog.level(difficulty, 1), levels.first);
        expect(NutsAndBoltsLevelCatalog.level(difficulty, 60), levels.last);
      }
      expect(
        () => NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 0),
        throwsRangeError,
      );
    });

    test('difficulty bands use confirmed capacities, colors, and helpers', () {
      final easy = NutsAndBoltsLevelCatalog.forDifficulty(
        NutsAndBoltsDifficulty.easy,
      );
      final normal = NutsAndBoltsLevelCatalog.forDifficulty(
        NutsAndBoltsDifficulty.normal,
      );
      final hard = NutsAndBoltsLevelCatalog.forDifficulty(
        NutsAndBoltsDifficulty.hard,
      );

      expect(easy.map((level) => level.colorCount).toSet(), {3, 4, 5});
      expect(easy.map((level) => level.capacity).toSet(), {3, 4});
      expect(normal.map((level) => level.colorCount).toSet(), {5, 6, 7, 8});
      expect(normal.map((level) => level.capacity).toSet(), {4});
      expect(hard.map((level) => level.colorCount).toSet(), {8, 9, 10, 11, 12});
      expect(hard.map((level) => level.capacity).toSet(), {4, 5});
      expect(easy, everyElement(_hasHelpers(2)));
      expect(normal, everyElement(_hasHelpers(2)));
      expect(hard, everyElement(_hasHelpers(1)));
      expect(
        easy.last.minimumSolutionMoves,
        greaterThan(easy.first.minimumSolutionMoves),
      );
      expect(
        normal.last.minimumSolutionMoves,
        greaterThan(normal.first.minimumSolutionMoves),
      );
      expect(
        hard.last.minimumSolutionMoves,
        greaterThan(hard.first.minimumSolutionMoves),
      );
    });

    test('definitions are balanced, immutable, and canonically unique', () {
      final definitions = <String>{};
      for (final level in NutsAndBoltsLevelCatalog.levels) {
        final counts = <int, int>{};
        for (final bolt in level.bolts) {
          expect(
            bolt.length,
            lessThanOrEqualTo(level.capacity),
            reason: level.id,
          );
          for (final color in bolt) {
            counts.update(color, (count) => count + 1, ifAbsent: () => 1);
          }
        }
        expect(counts, hasLength(level.colorCount), reason: level.id);
        expect(counts.values, everyElement(level.capacity), reason: level.id);
        expect(
          definitions.add(NutsAndBoltsSolver.stateKey(level.bolts)),
          isTrue,
          reason: '${level.id} duplicates an earlier puzzle',
        );
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
        expect(
          level.branching.exploredStates,
          greaterThan(1),
          reason: level.id,
        );
      }
      expect(
        () => NutsAndBoltsLevelCatalog.levels.first.bolts.first.add(99),
        throwsUnsupportedError,
      );
    });

    test(
      'validator solves and production model replays every shortest path',
      () {
        final solutions = NutsAndBoltsLevelValidator.validateCatalog(
          NutsAndBoltsLevelCatalog.levels,
        );
        for (final level in NutsAndBoltsLevelCatalog.levels) {
          final solution = solutions[level.id]!;
          expect(
            solution.moveCount,
            level.minimumSolutionMoves,
            reason: level.id,
          );
          var replay = level.createModel();
          for (var step = 0; step < solution.moves.length; step++) {
            final move = solution.moves[step];
            final result = replay.move(move.source, move.destination);
            expect(
              result.status,
              NutsAndBoltsMoveStatus.accepted,
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

  test(
    'validator rejects impossible, solved, duplicate, and drifted levels',
    () {
      final reference = NutsAndBoltsLevelCatalog.level(
        NutsAndBoltsDifficulty.easy,
        1,
      );
      final solved = _copyLevel(
        reference,
        id: 'solved',
        bolts: [
          for (var color = 0; color < reference.colorCount; color++)
            List.filled(reference.capacity, color),
          for (var helper = 0; helper < reference.helperBoltCount; helper++)
            <int>[],
        ],
      );
      final impossible = NutsAndBoltsLevel(
        id: 'impossible',
        difficulty: NutsAndBoltsDifficulty.easy,
        number: 1,
        capacity: 2,
        helperBoltCount: 0,
        bolts: const [
          [0, 1],
          [1, 0],
        ],
        minimumSolutionMoves: 1,
        branching: const NutsAndBoltsBranchingMetadata(
          initialLegalMoves: 0,
          mixedColorBoundaries: 2,
          exploredStates: 1,
        ),
      );
      final drifted = _copyLevel(
        reference,
        id: 'drifted',
        minimumSolutionMoves: reference.minimumSolutionMoves + 1,
      );
      final misclassified = _copyLevel(
        reference,
        id: 'misclassified',
        number: 60,
      );
      final duplicateCatalog = NutsAndBoltsLevelCatalog.levels
          .map(
            (level) =>
                level.difficulty == NutsAndBoltsDifficulty.easy &&
                    level.number == 2
                ? _copyLevel(reference, id: 'easy-02-duplicate', number: 2)
                : level,
          )
          .toList(growable: false);

      expect(
        () => NutsAndBoltsLevelValidator.validateLevel(solved),
        throwsStateError,
      );
      expect(
        () => NutsAndBoltsLevelValidator.validateLevel(impossible),
        throwsStateError,
      );
      expect(
        () => NutsAndBoltsLevelValidator.validateLevel(drifted),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('metadata'),
          ),
        ),
      );
      expect(
        () => NutsAndBoltsLevelValidator.validateLevel(misclassified),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('classified'),
          ),
        ),
      );
      expect(
        () => NutsAndBoltsLevelValidator.validateCatalog(duplicateCatalog),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('Duplicate puzzle definition'),
          ),
        ),
      );
    },
  );

  test('solver returns an exact shortest path for a small puzzle', () {
    final model = NutsAndBoltsModel(
      capacity: 2,
      bolts: const [
        [0, 1],
        [1, 0],
        [],
      ],
    );

    final solution = const NutsAndBoltsSolver().solve(model)!;

    expect(solution.moveCount, 3);
    var replay = model;
    for (final move in solution.moves) {
      replay = replay.move(move.source, move.destination).model;
    }
    expect(replay.isComplete, isTrue);
  });

  test('solver respects its explicit state bound', () {
    final level = NutsAndBoltsLevelCatalog.level(
      NutsAndBoltsDifficulty.hard,
      60,
    );
    expect(
      const NutsAndBoltsSolver(maxStates: 2).solve(level.createModel()),
      isNull,
    );
  });
}

NutsAndBoltsLevel _copyLevel(
  NutsAndBoltsLevel source, {
  required String id,
  int? number,
  List<List<int>>? bolts,
  int? minimumSolutionMoves,
}) => NutsAndBoltsLevel(
  id: id,
  difficulty: source.difficulty,
  number: number ?? source.number,
  capacity: source.capacity,
  helperBoltCount: source.helperBoltCount,
  bolts: bolts ?? source.bolts,
  minimumSolutionMoves: minimumSolutionMoves ?? source.minimumSolutionMoves,
  branching: source.branching,
);

Matcher _hasHelpers(int count) => isA<NutsAndBoltsLevel>()
    .having((level) => level.helperBoltCount, 'helperBoltCount', count)
    .having(
      (level) => level.bolts.where((bolt) => bolt.isEmpty).length,
      'empty bolts',
      count,
    );
