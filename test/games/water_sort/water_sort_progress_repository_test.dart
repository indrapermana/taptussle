import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'round-trips the active puzzle, undo history, and elapsed time',
    () async {
      final repository = WaterSortProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final level = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 1);
      final first = level.createModel().legalMoves.first;
      final moved = level
          .createModel()
          .pour(first.source, first.destination)
          .model;

      await repository.saveActive(
        level: level,
        model: moved,
        elapsed: const Duration(seconds: 43),
      );
      final saved = repository.loadActive(WaterSortDifficulty.easy)!;
      final restored = saved.restoreModel();

      expect(saved.level, 1);
      expect(saved.elapsedMilliseconds, 43000);
      expect(restored.tubes, moved.tubes);
      expect(restored.moveCount, 1);
      expect(restored.undo().tubes, level.tubes);
    },
  );

  test(
    'tracks progress and personal bests independently by difficulty',
    () async {
      final repository = WaterSortProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final easy = WaterSortLevelCatalog.level(WaterSortDifficulty.easy, 4);
      final hard = WaterSortLevelCatalog.level(WaterSortDifficulty.hard, 2);

      await repository.recordCompletion(
        level: easy,
        moves: 20,
        elapsed: const Duration(seconds: 50),
      );
      await repository.recordCompletion(
        level: easy,
        moves: 22,
        elapsed: const Duration(seconds: 30),
      );
      await repository.recordCompletion(
        level: easy,
        moves: 20,
        elapsed: const Duration(seconds: 45),
      );
      await repository.recordCompletion(
        level: hard,
        moves: 60,
        elapsed: const Duration(minutes: 3),
      );

      expect(repository.unlockedLevel(WaterSortDifficulty.easy), 5);
      expect(repository.completedLevels(WaterSortDifficulty.easy), {4});
      expect(repository.unlockedLevel(WaterSortDifficulty.normal), 1);
      expect(repository.unlockedLevel(WaterSortDifficulty.hard), 3);
      expect(repository.personalBest(WaterSortDifficulty.easy, 4)?.moves, 20);
      expect(
        repository
            .personalBest(WaterSortDifficulty.easy, 4)
            ?.elapsedMilliseconds,
        45000,
      );
    },
  );

  test('ignores malformed active and profile data', () async {
    SharedPreferences.setMockInitialValues({
      'waterSort.active.easy.v1':
          '{"version":1,"difficulty":"easy","level":1,"moves":[{"source":99,"destination":0,"color":0,"amount":1}],"elapsedMilliseconds":4}',
      'waterSort.profile.easy.v1':
          '{"version":1,"difficulty":"easy","unlockedLevel":99,"completedLevels":[],"bests":{}}',
    });
    final repository = WaterSortProgressRepository(
      await SharedPreferences.getInstance(),
    );

    expect(repository.loadActive(WaterSortDifficulty.easy), isNull);
    expect(repository.unlockedLevel(WaterSortDifficulty.easy), 1);
    expect(repository.completedLevels(WaterSortDifficulty.easy), isEmpty);
  });
}
