import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/mancala/mancala_bot.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';

void main() {
  group('MancalaBot', () {
    test('every difficulty returns legal pits without mutating the model', () {
      final model = MancalaModel(startingPlayer: 1);
      final before = model.board;

      for (final difficulty in BotDifficulty.values) {
        for (var seed = 0; seed < 5; seed++) {
          final bot = MancalaBot(difficulty: difficulty, random: Random(seed));
          expect(model.legalPitsFor(1), contains(bot.choosePit(model)));
          expect(model.board, before);
          expect(model.currentPlayer, 1);
        }
      }
    });

    test('Easy varies its legal choice across deterministic seeds', () {
      final model = MancalaModel(startingPlayer: 1);
      final choices = {
        for (var seed = 0; seed < 20; seed++)
          MancalaBot(
            difficulty: BotDifficulty.easy,
            random: Random(seed),
          ).choosePit(model),
      };

      expect(choices.length, greaterThan(1));
      expect(choices, everyElement(isIn(model.legalPitsFor(1))));
    });

    test('profiles increase search depth under strict node budgets', () {
      final model = MancalaModel(startingPlayer: 1);
      final easy = MancalaBot(
        difficulty: BotDifficulty.easy,
        random: Random(1),
      );
      final normal = MancalaBot(
        difficulty: BotDifficulty.normal,
        random: Random(1),
        mistakeChance: 0,
      );
      final hard = MancalaBot(
        difficulty: BotDifficulty.hard,
        random: Random(1),
      );

      easy.choosePit(model);
      normal.choosePit(model);
      hard.choosePit(model);

      expect(
        (easy.searchDepth, normal.searchDepth, hard.searchDepth),
        (0, 3, 7),
      );
      expect(easy.searchedNodes, 0);
      expect(normal.searchedNodes, inInclusiveRange(1, normal.nodeBudget));
      expect(hard.searchedNodes, inInclusiveRange(1, hard.nodeBudget));
      expect(normal.nodeBudget, lessThan(hard.nodeBudget));
    });

    test('Normal and Hard prefer a large available capture', () {
      final model = MancalaModel.fromBoard(
        board: const [1, 8, 1, 1, 1, 1, 10, 1, 0, 0, 1, 0, 0, 10],
        currentPlayer: 1,
      );

      for (final difficulty in const [
        BotDifficulty.normal,
        BotDifficulty.hard,
      ]) {
        final bot = MancalaBot(
          difficulty: difficulty,
          random: Random(2),
          mistakeChance: 0,
        );
        expect(bot.choosePit(model), 3);
      }
    });

    test('returns null outside its turn and after the match finishes', () {
      final bot = MancalaBot(difficulty: BotDifficulty.hard);
      expect(bot.choosePit(MancalaModel()), isNull);

      final finished = MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 0, 24, 0, 0, 0, 0, 0, 0, 24],
        currentPlayer: 1,
      );
      expect(finished.isFinished, isTrue);
      expect(bot.choosePit(finished), isNull);
    });
  });
}
