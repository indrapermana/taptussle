import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_controller.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('NutsAndBoltsController', () {
    test(
      'selects sources, exposes legal targets, and locks during movement',
      () {
        final controller = NutsAndBoltsController(
          level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
          animationDuration: const Duration(days: 1),
        );
        addTearDown(controller.dispose);
        final hint = controller.model.hint!;

        expect(controller.tapBolt(hint.source), NutsAndBoltsTapResult.selected);
        expect(controller.selectedBolt, hint.source);
        expect(controller.isLegalDestination(hint.destination), isTrue);

        expect(
          controller.tapBolt(hint.destination),
          NutsAndBoltsTapResult.moved,
        );
        expect(controller.model.moveCount, 1);
        expect(controller.isAnimating, isTrue);
        expect(
          controller.tapBolt(hint.source),
          NutsAndBoltsTapResult.inputLocked,
        );
        expect(controller.undo(), isFalse);
      },
    );

    test('invalid target selects another non-empty source', () {
      final controller = NutsAndBoltsController(
        level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
      );
      addTearDown(controller.dispose);
      final source = controller.model.bolts.indexWhere(
        (bolt) => bolt.isNotEmpty,
      );
      final target = List.generate(controller.model.boltCount, (index) => index)
          .firstWhere(
            (index) =>
                index != source &&
                controller.model.bolts[index].isNotEmpty &&
                !controller.model.canMove(source, index),
          );

      controller.tapBolt(source);
      expect(
        controller.tapBolt(target),
        NutsAndBoltsTapResult.selectionChanged,
      );
      expect(controller.selectedBolt, target);
    });

    test('hint, undo, and restart keep state coherent', () {
      final controller = NutsAndBoltsController(
        level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
        animationDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      final hint = controller.requestHint()!;
      expect(controller.hintMove, hint);
      controller.tapBolt(hint.source);
      controller.tapBolt(hint.destination);
      expect(controller.model.moveCount, 1);
      expect(controller.hintMove, isNull);
      expect(controller.undo(), isTrue);
      expect(controller.model.moveCount, 0);

      final secondHint = controller.requestHint()!;
      controller.tapBolt(secondHint.source);
      controller.tapBolt(secondHint.destination);
      expect(controller.restart(), isTrue);
      expect(controller.model.moveCount, 0);
      expect(controller.model.bolts, controller.level.bolts);
    });

    testWidgets('pause freezes time and saves resumable progress', (
      tester,
    ) async {
      var now = DateTime(2026);
      final repository = NutsAndBoltsProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final session = MatchSession(options: MatchOptions.solo())..start();
      final level = NutsAndBoltsLevelCatalog.level(
        NutsAndBoltsDifficulty.easy,
        1,
      );
      final controller = NutsAndBoltsController(
        level: level,
        session: session,
        repository: repository,
        now: () => now,
        animationDuration: Duration.zero,
      );
      final move = controller.model.legalMoves.first;
      controller.tapBolt(move.source);
      controller.tapBolt(move.destination);
      now = now.add(const Duration(seconds: 12));
      session.pause();
      await repository.completed;
      now = now.add(const Duration(seconds: 30));

      expect(controller.elapsed, const Duration(seconds: 12));
      final saved = repository.loadActive(NutsAndBoltsDifficulty.easy)!;
      expect(saved.elapsedMilliseconds, 12000);
      expect(saved.restoreModel().bolts, controller.model.bolts);
      expect(controller.tapBolt(0), NutsAndBoltsTapResult.inputLocked);
      controller.dispose();
      session.dispose();
    });

    testWidgets('completion unlocks next level and reports record metrics', (
      tester,
    ) async {
      var now = DateTime(2026);
      final repository = NutsAndBoltsProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final session = MatchSession(options: MatchOptions.solo())..start();
      final level = NutsAndBoltsLevel(
        id: 'easy-01',
        difficulty: NutsAndBoltsDifficulty.easy,
        number: 1,
        capacity: 2,
        helperBoltCount: 1,
        bolts: const [
          [0, 0],
          [1],
          [1],
        ],
        minimumSolutionMoves: 1,
        branching: const NutsAndBoltsBranchingMetadata(
          initialLegalMoves: 2,
          mixedColorBoundaries: 0,
          exploredStates: 2,
        ),
      );
      final controller = NutsAndBoltsController(
        level: level,
        session: session,
        repository: repository,
        now: () => now,
        animationDuration: Duration.zero,
      );
      now = now.add(const Duration(seconds: 20));
      controller.tapBolt(1);
      controller.tapBolt(2);
      await repository.completed;

      expect(controller.model.isComplete, isTrue);
      expect(repository.loadActive(NutsAndBoltsDifficulty.easy), isNull);
      expect(repository.unlockedLevel(NutsAndBoltsDifficulty.easy), 2);
      expect(repository.completedLevels(NutsAndBoltsDifficulty.easy), {1});
      expect(repository.personalBest(NutsAndBoltsDifficulty.easy, 1)?.moves, 1);
      expect(session.phase, MatchPhase.finished);
      expect(session.recordMetrics, {'level': 1, 'moves': 1, 'time': 20000});
      controller.dispose();
      session.dispose();
    });
  });
}
