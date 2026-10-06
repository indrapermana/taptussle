import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/ludo/ludo_bot.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';

void main() {
  group('LudoBot', () {
    test('requires an active rolled turn with at least one legal move', () {
      final model = LudoModel(playerCount: 2, diceRoller: () => 1);
      final bot = LudoBot(random: _FixedRandom(0));

      expect(
        () => bot.chooseToken(model, BotDifficulty.easy),
        throwsStateError,
      );
    });

    test('Easy makes an honest random choice from the legal tokens', () {
      final model = _rolledModel(
        tokens: const [
          [4, 10, 20, -1],
          [-1, -1, -1, -1],
        ],
        roll: 2,
      );
      final bot = LudoBot(random: _FixedRandom(2));

      final choice = bot.chooseToken(model, BotDifficulty.easy);

      expect(model.legalTokenIndexes, [0, 1, 2]);
      expect(choice, 2);
    });

    test('Normal prioritizes a capture over ordinary advancement', () {
      final model = _rolledModel(
        tokens: const [
          [4, 20, -1, -1],
          [44, -1, -1, -1], // Absolute track 5, one ahead of token 0.
        ],
        roll: 1,
      );
      final bot = LudoBot(random: _FixedRandom(0));

      expect(bot.chooseToken(model, BotDifficulty.normal), 0);
    });

    test('Normal prioritizes exact final home', () {
      final model = _rolledModel(
        tokens: const [
          [55, 40, -1, -1],
          [-1, -1, -1, -1],
        ],
        roll: 1,
      );
      final bot = LudoBot(random: _FixedRandom(0));

      expect(bot.chooseToken(model, BotDifficulty.normal), 0);
    });

    test('Hard avoids an exposed advance when a safe landing is available', () {
      final model = _rolledModel(
        tokens: const [
          [40, 7, -1, -1],
          [25, -1, -1, -1], // Absolute track 38 threatens landing 41.
        ],
        roll: 1,
      );
      final bot = LudoBot(random: _FixedRandom(0));

      expect(bot.chooseToken(model, BotDifficulty.normal), 0);
      expect(bot.chooseToken(model, BotDifficulty.hard), 1);
    });

    test('Hard still takes a capture when the tactical gain is decisive', () {
      final model = _rolledModel(
        tokens: const [
          [4, 7, -1, -1],
          [44, -1, -1, -1],
        ],
        roll: 1,
      );
      final bot = LudoBot(random: _FixedRandom(0));

      expect(bot.chooseToken(model, BotDifficulty.hard), 0);
    });

    test('every difficulty always returns a token from the legal list', () {
      for (final difficulty in BotDifficulty.values) {
        final model = _rolledModel(
          tokens: const [
            [55, 54, 53, -1],
            [-1, -1, -1, -1],
          ],
          roll: 2,
        );
        final choice = LudoBot(
          random: _FixedRandom(1),
        ).chooseToken(model, difficulty);

        expect(model.legalTokenIndexes, [1, 2]);
        expect(choice, isIn(model.legalTokenIndexes));
      }
    });
  });
}

LudoModel _rolledModel({required List<List<int>> tokens, required int roll}) {
  final model = LudoModel.fromState(
    playerCount: tokens.length,
    diceRoller: () => roll,
    tokenProgress: tokens,
  );
  model.rollDice();
  return model;
}

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => value.isEven;

  @override
  double nextDouble() => .5;

  @override
  int nextInt(int max) => value % max;
}
