import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_model.dart';

class _DiceSequence {
  _DiceSequence(this.values);

  final List<int> values;
  var _index = 0;

  int roll() => values[_index++];
}

void main() {
  group('SnakesAndLaddersModel', () {
    test('freezes the 8x8 path and standard transitions', () {
      expect(SnakesAndLaddersModel.serpentineRows, hasLength(8));
      final path = SnakesAndLaddersModel.serpentineRows
          .expand((row) => row)
          .toList();
      expect(path, hasLength(64));
      expect(path.toSet(), {
        for (var square = 1; square <= 64; square++) square,
      });
      expect(SnakesAndLaddersModel.serpentineRows.first, [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
      ]);
      expect(SnakesAndLaddersModel.serpentineRows[1], [
        16,
        15,
        14,
        13,
        12,
        11,
        10,
        9,
      ]);
      expect(SnakesAndLaddersModel.serpentineRows.last, [
        64,
        63,
        62,
        61,
        60,
        59,
        58,
        57,
      ]);
      expect(SnakesAndLaddersModel.standardTransitions, {
        3: 16,
        8: 30,
        20: 39,
        27: 48,
        41: 60,
        18: 6,
        26: 10,
        37: 24,
        50: 34,
        62: 45,
      });
    });

    test(
      'uses injected dice deterministically and rotates through four players',
      () {
        final dice = _DiceSequence([1, 2, 4, 5]);
        final model = SnakesAndLaddersModel(
          playerCount: 4,
          diceRoller: dice.roll,
        );

        const rolls = [1, 2, 4, 5];
        for (var player = 0; player < 4; player++) {
          final turn = model.rollTurn();
          expect(turn.playerIndex, player);
          expect(turn.roll, rolls[player]);
        }

        expect(model.positions, [1, 2, 4, 5]);
        expect(model.currentPlayer, 0);
      },
    );

    test('climbs ladders and descends snakes once', () {
      final ladderDice = _DiceSequence([3]);
      final ladder = SnakesAndLaddersModel(
        playerCount: 2,
        diceRoller: ladderDice.roll,
      );
      final climbed = ladder.rollTurn();
      expect(climbed.startSquare, 0);
      expect(climbed.attemptedSquare, 3);
      expect(climbed.endSquare, 16);
      expect(climbed.transitionType, BoardTransitionType.ladder);

      final snakeDice = _DiceSequence([6, 6, 6, 6, 6]);
      final snake = SnakesAndLaddersModel(
        playerCount: 2,
        diceRoller: snakeDice.roll,
      );
      snake.rollTurn(); // P1: 0 -> 6
      snake.rollTurn(); // P2: 0 -> 6
      snake.rollTurn(); // P1: 6 -> 12
      snake.rollTurn(); // P2: 6 -> 12
      final descended = snake.rollTurn(); // P1: 12 -> 18 -> 6
      expect(descended.attemptedSquare, 18);
      expect(descended.endSquare, 6);
      expect(descended.transitionType, BoardTransitionType.snake);
    });

    test('rolling six does not grant an extra turn', () {
      final dice = _DiceSequence([6]);
      final model = SnakesAndLaddersModel(
        playerCount: 3,
        diceRoller: dice.roll,
      );

      final turn = model.rollTurn();

      expect(turn.nextPlayerIndex, 1);
      expect(model.currentPlayer, 1);
    });

    test('players may share a square without collision or capture', () {
      final dice = _DiceSequence([4, 4]);
      final model = SnakesAndLaddersModel(
        playerCount: 2,
        diceRoller: dice.roll,
      );

      model.rollTurn();
      model.rollTurn();

      expect(model.positions, [4, 4]);
    });

    test(
      'an oversized roll keeps the token in place and advances the turn',
      () {
        final exactDice = _DiceSequence([...List.filled(20, 6), 3, 1, 2]);
        final exactModel = SnakesAndLaddersModel(
          playerCount: 2,
          diceRoller: exactDice.roll,
          transitions: const {},
        );
        for (var turn = 0; turn < 22; turn++) {
          exactModel.rollTurn();
        }
        final tooHigh = exactModel.rollTurn();
        expect(tooHigh.startSquare, 63);
        expect(tooHigh.attemptedSquare, 65);
        expect(tooHigh.endSquare, 63);
        expect(tooHigh.wasOversized, isTrue);
        expect(tooHigh.moved, isFalse);
        expect(tooHigh.nextPlayerIndex, 1);
      },
    );

    test('exact roll reaches 64, ends the match, and rejects later rolls', () {
      final dice = _DiceSequence([...List.filled(20, 6), 4]);
      final model = SnakesAndLaddersModel(
        playerCount: 2,
        diceRoller: dice.roll,
        transitions: const {},
      );
      for (var turn = 0; turn < 20; turn++) {
        model.rollTurn();
      }

      final winningTurn = model.rollTurn();
      expect(winningTurn.startSquare, 60);
      expect(winningTurn.endSquare, 64);
      expect(winningTurn.won, isTrue);
      expect(winningTurn.nextPlayerIndex, isNull);
      expect(model.winner, 0);
      expect(model.isFinished, isTrue);
      expect(() => model.rollTurn(), throwsStateError);
    });

    test('supports a chosen starting player and reset', () {
      final dice = _DiceSequence([2, 3]);
      final model = SnakesAndLaddersModel(
        playerCount: 3,
        startingPlayer: 2,
        diceRoller: dice.roll,
      );
      model.rollTurn();
      expect(model.positions, [0, 0, 2]);

      model.reset();
      expect(model.positions, [0, 0, 0]);
      expect(model.currentPlayer, 2);
      expect(model.winner, isNull);
      expect(model.lastTurn, isNull);
    });

    test('exposes immutable positions and transitions', () {
      final model = SnakesAndLaddersModel(playerCount: 2, diceRoller: () => 1);
      expect(() => model.positions[0] = 5, throwsUnsupportedError);
      expect(() => model.transitions[3] = 4, throwsUnsupportedError);
    });

    test(
      'validates participant count, starting player, dice, and transitions',
      () {
        expect(
          () => SnakesAndLaddersModel(playerCount: 1, diceRoller: () => 1),
          throwsArgumentError,
        );
        expect(
          () => SnakesAndLaddersModel(playerCount: 5, diceRoller: () => 1),
          throwsArgumentError,
        );
        expect(
          () => SnakesAndLaddersModel(
            playerCount: 2,
            startingPlayer: 2,
            diceRoller: () => 1,
          ),
          throwsArgumentError,
        );
        expect(
          () => SnakesAndLaddersModel(
            playerCount: 2,
            diceRoller: () => 7,
          ).rollTurn(),
          throwsStateError,
        );
        expect(
          () => SnakesAndLaddersModel(
            playerCount: 2,
            diceRoller: () => 1,
            transitions: const {3: 3},
          ),
          throwsArgumentError,
        );
        expect(
          () => SnakesAndLaddersModel(
            playerCount: 2,
            diceRoller: () => 1,
            transitions: const {3: 16, 16: 30},
          ),
          throwsArgumentError,
        );
      },
    );
  });
}
