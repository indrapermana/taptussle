import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips active puzzle, undo history, and elapsed time', () async {
    final repository = NutsAndBoltsProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final level = NutsAndBoltsLevelCatalog.level(
      NutsAndBoltsDifficulty.easy,
      1,
    );
    final first = level.createModel().legalMoves.first;
    final moved = level
        .createModel()
        .move(first.source, first.destination)
        .model;

    await repository.saveActive(
      level: level,
      model: moved,
      elapsed: const Duration(seconds: 43),
    );
    final saved = repository.loadActive(NutsAndBoltsDifficulty.easy)!;
    final restored = saved.restoreModel();

    expect(saved.level, 1);
    expect(saved.elapsedMilliseconds, 43000);
    expect(restored.bolts, moved.bolts);
    expect(restored.moveCount, 1);
    expect(restored.undo().bolts, level.bolts);
  });

  test(
    'tracks unlocks and personal bests independently by difficulty',
    () async {
      final repository = NutsAndBoltsProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final easy = NutsAndBoltsLevelCatalog.level(
        NutsAndBoltsDifficulty.easy,
        4,
      );
      final hard = NutsAndBoltsLevelCatalog.level(
        NutsAndBoltsDifficulty.hard,
        2,
      );

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

      expect(repository.unlockedLevel(NutsAndBoltsDifficulty.easy), 5);
      expect(repository.completedLevels(NutsAndBoltsDifficulty.easy), {4});
      expect(repository.unlockedLevel(NutsAndBoltsDifficulty.normal), 1);
      expect(repository.unlockedLevel(NutsAndBoltsDifficulty.hard), 3);
      expect(
        repository.personalBest(NutsAndBoltsDifficulty.easy, 4)?.moves,
        20,
      );
      expect(
        repository
            .personalBest(NutsAndBoltsDifficulty.easy, 4)
            ?.elapsedMilliseconds,
        45000,
      );
    },
  );

  test('ignores malformed active and profile data', () async {
    SharedPreferences.setMockInitialValues({
      'nutsAndBolts.active.easy.v1':
          '{"version":1,"difficulty":"easy","level":1,"moves":[{"source":99,"destination":0,"color":0}],"elapsedMilliseconds":4}',
      'nutsAndBolts.profile.easy.v1':
          '{"version":1,"difficulty":"easy","unlockedLevel":99,"completedLevels":[],"bests":{}}',
    });
    final repository = NutsAndBoltsProgressRepository(
      await SharedPreferences.getInstance(),
    );

    expect(repository.loadActive(NutsAndBoltsDifficulty.easy), isNull);
    expect(repository.unlockedLevel(NutsAndBoltsDifficulty.easy), 1);
    expect(repository.completedLevels(NutsAndBoltsDifficulty.easy), isEmpty);
  });
}
