import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/water_sort/water_sort_controller.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_model.dart';
import 'package:tap_tussle/games/water_sort/water_sort_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'selection, legal pour, animation lock, undo, and restart cooperate',
    () {
      final controller = WaterSortController(
        level: _testLevel(),
        initialModel: WaterSortModel(
          tubes: [
            [0, 1],
            [1, 0],
            <int>[],
          ],
        ),
        animationDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      expect(controller.tapTube(2), WaterSortTapResult.invalid);
      expect(controller.tapTube(0), WaterSortTapResult.selected);
      expect(controller.selectedTube, 0);
      expect(controller.tapTube(0), WaterSortTapResult.selectionCleared);
      expect(controller.tapTube(0), WaterSortTapResult.selected);
      expect(controller.tapTube(1), WaterSortTapResult.selectionChanged);
      expect(controller.selectedTube, 1);
      expect(controller.tapTube(2), WaterSortTapResult.poured);
      expect(controller.model.moveCount, 1);
      expect(controller.model.tubes[2], [0]);
      expect(controller.undo(), isTrue);
      expect(controller.model.moveCount, 0);
      controller.tapTube(0);
      controller.tapTube(2);
      expect(controller.restart(), isTrue);
      expect(controller.model.tubes, [
        [0, 1],
        [1, 0],
        <int>[],
      ]);
    },
  );

  test('hint returns a legal next move and clears when the player acts', () {
    final level = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 1);
    final controller = WaterSortController(
      level: level,
      animationDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    final hint = controller.requestHint();

    expect(hint, isNotNull);
    expect(controller.model.canPour(hint!.source, hint.destination), isTrue);
    expect(controller.hintMove, hint);
    expect(controller.tapTube(hint.source), WaterSortTapResult.selected);
    expect(controller.hintMove, isNull);
  });

  testWidgets('input stays locked for the configured pour animation', (
    tester,
  ) async {
    final controller = WaterSortController(
      level: _testLevel(),
      initialModel: WaterSortModel(
        tubes: [
          [0, 1],
          [0, 1],
          <int>[],
        ],
      ),
      animationDuration: const Duration(milliseconds: 300),
    );
    addTearDown(controller.dispose);

    controller.tapTube(0);
    expect(controller.tapTube(2), WaterSortTapResult.poured);
    expect(controller.isAnimating, isTrue);
    expect(controller.tapTube(1), WaterSortTapResult.inputLocked);
    expect(controller.undo(), isFalse);
    await tester.pump(const Duration(milliseconds: 299));
    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('pause freezes time and saves a resumable active puzzle', (
    tester,
  ) async {
    var now = DateTime(2026);
    final repository = WaterSortProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final session = MatchSession(options: MatchOptions.solo())..start();
    final level = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 1);
    final controller = WaterSortController(
      level: level,
      session: session,
      repository: repository,
      now: () => now,
      animationDuration: Duration.zero,
    );
    final move = controller.model.legalMoves.first;
    controller.tapTube(move.source);
    controller.tapTube(move.destination);
    now = now.add(const Duration(seconds: 12));
    session.pause();
    await repository.completed;
    now = now.add(const Duration(seconds: 30));

    expect(controller.elapsed, const Duration(seconds: 12));
    final saved = repository.loadActive(WaterSortDifficulty.easy)!;
    expect(saved.elapsedMilliseconds, 12000);
    expect(saved.restoreModel().tubes, controller.model.tubes);
    expect(controller.tapTube(0), WaterSortTapResult.inputLocked);
    controller.dispose();
    session.dispose();
  });

  testWidgets('completion unlocks the next level and reports record metrics', (
    tester,
  ) async {
    var now = DateTime(2026);
    final repository = WaterSortProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final session = MatchSession(options: MatchOptions.solo())..start();
    final level = WaterSortLevel(
      id: 'easy-01',
      difficulty: WaterSortDifficulty.easy,
      number: 1,
      capacity: 2,
      helperTubeCount: 1,
      tubes: const [
        [0, 0],
        [1],
        [1],
      ],
      minimumSolutionMoves: 1,
      branching: const WaterSortBranchingMetadata(
        initialLegalMoves: 2,
        mixedColorBoundaries: 0,
      ),
    );
    final controller = WaterSortController(
      level: level,
      session: session,
      repository: repository,
      now: () => now,
      animationDuration: Duration.zero,
    );
    now = now.add(const Duration(seconds: 20));
    controller.tapTube(1);
    controller.tapTube(2);
    await repository.completed;

    expect(controller.model.isComplete, isTrue);
    expect(repository.loadActive(WaterSortDifficulty.easy), isNull);
    expect(repository.unlockedLevel(WaterSortDifficulty.easy), 2);
    expect(repository.completedLevels(WaterSortDifficulty.easy), {1});
    expect(repository.personalBest(WaterSortDifficulty.easy, 1)?.moves, 1);
    expect(session.phase, MatchPhase.finished);
    expect(session.recordMetrics, {'level': 1, 'moves': 1, 'time': 20000});
    controller.dispose();
    session.dispose();
  });
}

WaterSortLevel _testLevel() => WaterSortLevel(
  id: 'test-01',
  difficulty: WaterSortDifficulty.easy,
  number: 1,
  capacity: 4,
  helperTubeCount: 1,
  tubes: [
    [0, 1],
    [0, 1],
    <int>[],
  ],
  minimumSolutionMoves: 3,
  branching: const WaterSortBranchingMetadata(
    initialLegalMoves: 2,
    mixedColorBoundaries: 2,
  ),
);
