import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';
import 'package:tap_tussle/games/solitaire/solitaire_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'round-trips active deal, undo history, score, and elapsed time',
    () async {
      final repository = SolitaireProgressRepository(
        await SharedPreferences.getInstance(),
      );
      var model = SolitaireModel.fromDeck(
        deck: SolitaireModel.standardDeck(),
        drawMode: SolitaireDrawMode.drawOne,
      );
      model = model.drawOrRecycle().model;
      model = model.drawOrRecycle().model;

      await repository.saveActive(
        difficulty: SolitaireDifficulty.easy,
        model: model,
        elapsed: const Duration(seconds: 43),
      );
      final saved = repository.loadActive(SolitaireDifficulty.easy)!;
      final restored = saved.restoreModel();

      expect(saved.elapsedMilliseconds, 43000);
      expect(restored.stock, model.stock);
      expect(restored.waste, model.waste);
      expect(restored.tableau, model.tableau);
      expect(restored.moveCount, 2);
      expect(restored.canUndo, isTrue);
      expect(restored.undo().moveCount, 1);
      expect(restored.undo().undo().moveCount, 0);
    },
  );

  test('keeps active deals and stats independent by difficulty', () async {
    final repository = SolitaireProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final easy = SolitaireModel.fromDeck(
      deck: SolitaireModel.standardDeck(),
      drawMode: SolitaireDrawMode.drawOne,
    ).drawOrRecycle().model;
    final normal = SolitaireModel.fromDeck(
      deck: SolitaireModel.standardDeck().reversed.toList(),
      drawMode: SolitaireDrawMode.drawOne,
    ).drawOrRecycle().model;

    await repository.saveActive(
      difficulty: SolitaireDifficulty.easy,
      model: easy,
      elapsed: const Duration(seconds: 10),
    );
    await repository.saveActive(
      difficulty: SolitaireDifficulty.normal,
      model: normal,
      elapsed: const Duration(seconds: 20),
    );
    await repository.recordWin(
      difficulty: SolitaireDifficulty.easy,
      moves: 120,
      elapsed: const Duration(minutes: 5),
    );
    await repository.recordWin(
      difficulty: SolitaireDifficulty.easy,
      moves: 130,
      elapsed: const Duration(minutes: 4),
    );
    await repository.recordWin(
      difficulty: SolitaireDifficulty.easy,
      moves: 110,
      elapsed: const Duration(minutes: 6),
    );

    expect(repository.loadActive(SolitaireDifficulty.easy), isNull);
    expect(
      repository.loadActive(SolitaireDifficulty.normal)?.elapsedMilliseconds,
      20000,
    );
    final easyStats = repository.stats(SolitaireDifficulty.easy);
    expect(easyStats.wins, 3);
    expect(easyStats.fastestMilliseconds, 240000);
    expect(easyStats.fewestMoves, 110);
    expect(repository.stats(SolitaireDifficulty.normal).wins, 0);
    expect(repository.stats(SolitaireDifficulty.hard).wins, 0);
  });

  test('ignores malformed, mismatched, and completed snapshots', () async {
    final preferences = await SharedPreferences.getInstance();
    final repository = SolitaireProgressRepository(preferences);
    await preferences.setString(
      'solitaire.active.easy.v1',
      jsonEncode({
        'version': 1,
        'difficulty': 'easy',
        'elapsedMilliseconds': 2,
        'states': [
          {
            's': [53],
            'w': [],
            't': [[], [], [], [], [], [], []],
            'f': [0, 0, 0, 0],
            'm': 0,
            'p': 0,
          },
        ],
      }),
    );
    await preferences.setString(
      'solitaire.stats.easy.v1',
      '{"version":1,"difficulty":"easy","wins":-1}',
    );

    expect(repository.loadActive(SolitaireDifficulty.easy), isNull);
    expect(repository.stats(SolitaireDifficulty.easy).wins, 0);

    final foundations = {
      for (final suit in SolitaireSuit.values)
        suit: [
          for (final rank in SolitaireRank.values) SolitaireCard(suit, rank),
        ],
    };
    final complete = SolitaireModel.fromState(
      drawMode: SolitaireDrawMode.drawOne,
      tableau: List.generate(7, (_) => <SolitaireTableauCard>[]),
      foundations: foundations,
    );
    expect(
      () => repository.saveActive(
        difficulty: SolitaireDifficulty.easy,
        model: complete,
        elapsed: Duration.zero,
      ),
      throwsArgumentError,
    );
  });
}
