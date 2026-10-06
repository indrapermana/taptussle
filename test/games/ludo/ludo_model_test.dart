import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';

class _DiceSequence {
  _DiceSequence(this.values);

  final List<int> values;
  var _index = 0;

  int roll() => values[_index++];
}

LudoModel _state({
  required List<List<int>> tokens,
  required List<int> dice,
  int currentPlayer = 0,
  List<int> standings = const [],
}) => LudoModel.fromState(
  playerCount: tokens.length,
  diceRoller: _DiceSequence(dice).roll,
  tokenProgress: tokens,
  currentPlayer: currentPlayer,
  standings: standings,
);

void main() {
  group('LudoModel', () {
    test('creates four boxed tokens for two to four participants', () {
      for (var players = 2; players <= 4; players++) {
        final model = LudoModel(playerCount: players, diceRoller: () => 1);

        expect(model.tokenProgress, hasLength(players));
        expect(
          model.tokenProgress,
          everyElement(List.filled(4, LudoModel.boxProgress)),
        );
        expect(model.currentPlayer, 0);
        expect(model.phase, LudoTurnPhase.awaitingRoll);
      }
    });

    test('requires a six to leave the box and waits for token selection', () {
      final dice = _DiceSequence([3, 6]);
      final model = LudoModel(playerCount: 2, diceRoller: dice.roll);

      final missed = model.rollDice();
      expect(missed.legalTokenIndexes, isEmpty);
      expect(missed.nextPlayerIndex, 1);
      expect(model.currentPlayer, 1);

      final six = model.rollDice();
      expect(six.legalTokenIndexes, [0, 1, 2, 3]);
      expect(six.requiresTokenChoice, isTrue);
      expect(model.phase, LudoTurnPhase.awaitingMove);
      expect(model.moveToken(1, 2), LudoMoveResult.accepted);
      expect(model.progressFor(1, 2), 0);
      expect(model.lastMove?.enteredBoard, isTrue);
      expect(model.lastMove?.bonusRoll, isTrue);
      expect(model.currentPlayer, 1);
    });

    test('allows unrestricted consecutive sixes', () {
      final dice = _DiceSequence([6, 6, 6, 2]);
      final model = LudoModel(playerCount: 2, diceRoller: dice.roll);

      for (var token = 0; token < 3; token++) {
        expect(model.rollDice().value, 6);
        expect(model.moveToken(0, token), LudoMoveResult.accepted);
        expect(model.currentPlayer, 0);
      }
      model.rollDice();
      model.moveToken(0, 0);
      expect(model.currentPlayer, 1);
    });

    test('a six with no legal token still grants a bonus roll', () {
      final model = _state(
        tokens: const [
          [56, 56, 56, 55],
          [-1, -1, -1, -1],
        ],
        dice: [6, 1],
      );

      final blocked = model.rollDice();
      expect(blocked.legalTokenIndexes, isEmpty);
      expect(blocked.bonusRoll, isTrue);
      expect(blocked.nextPlayerIndex, 0);
      expect(model.phase, LudoTurnPhase.awaitingRoll);
      expect(model.rollDice().value, 1);
    });

    test('maps relative player progress onto the shared track', () {
      final model = _state(
        tokens: const [
          [0, 8, 50, 51],
          [0, 8, 50, 56],
          [0, 8, 50, -1],
          [0, 8, 50, 51],
        ],
        dice: [1],
      );

      expect(
        [for (var p = 0; p < 4; p++) model.trackIndexFor(p, 0)],
        [0, 13, 26, 39],
      );
      expect(
        [for (var p = 0; p < 4; p++) model.trackIndexFor(p, 1)],
        [8, 21, 34, 47],
      );
      expect(model.trackIndexFor(0, 3), isNull);
      expect(model.trackIndexFor(1, 3), isNull);
      expect(model.trackIndexFor(2, 3), isNull);
    });

    test('captures every opposing token sharing a non-safe landing square', () {
      final model = _state(
        tokens: const [
          [4, -1, -1, -1],
          [44, 44, -1, -1], // Player 2 progress 44 maps to track index 5.
          [-1, -1, -1, -1],
        ],
        dice: [1],
      );

      model.rollDice();
      expect(model.moveToken(0, 0), LudoMoveResult.accepted);

      expect(model.progressFor(0, 0), 5);
      expect(model.progressFor(1, 0), -1);
      expect(model.progressFor(1, 1), -1);
      expect(model.lastMove?.capturedTokens, [
        const LudoTokenRef(1, 0),
        const LudoTokenRef(1, 1),
      ]);
      expect(model.lastMove?.bonusRoll, isTrue);
      expect(model.currentPlayer, 0);
    });

    test('safe squares allow opponents to coexist without capture', () {
      final model = _state(
        tokens: const [
          [7, -1, -1, -1],
          [47, -1, -1, -1], // Player 2 progress 47 maps to safe index 8.
        ],
        dice: [1],
      );

      model.rollDice();
      model.moveToken(0, 0);

      expect(model.trackIndexFor(0, 0), 8);
      expect(model.progressFor(1, 0), 47);
      expect(model.lastMove?.capturedTokens, isEmpty);
      expect(model.currentPlayer, 1);
    });

    test('same-color stacks create no blockade and may be passed', () {
      final model = _state(
        tokens: const [
          [3, -1, -1, -1],
          [43, 43, -1, -1], // Both occupy absolute track index 4.
        ],
        dice: [3],
      );

      expect(model.rollDice().legalTokenIndexes, [0]);
      expect(model.moveToken(0, 0), LudoMoveResult.accepted);
      expect(model.progressFor(0, 0), 6);
      expect(model.progressFor(1, 0), 43);
      expect(model.progressFor(1, 1), 43);
      expect(model.lastMove?.capturedTokens, isEmpty);
    });

    test('moves from the shared track into the private home path', () {
      final model = _state(
        tokens: const [
          [50, -1, -1, -1],
          [-1, -1, -1, -1],
        ],
        dice: [4],
      );

      model.rollDice();
      model.moveToken(0, 0);

      expect(model.progressFor(0, 0), 54);
      expect(model.trackIndexFor(0, 0), isNull);
      expect(model.lastMove?.reachedFinalHome, isFalse);
    });

    test('reaching the final goal grants another roll', () {
      final model = _state(
        tokens: const [
          [55, 10, -1, -1],
          [-1, -1, -1, -1],
        ],
        dice: [1],
      );

      model.rollDice();
      model.moveToken(0, 0);

      expect(model.progressFor(0, 0), LudoModel.finishProgress);
      expect(model.lastMove?.reachedFinalHome, isTrue);
      expect(model.lastMove?.bonusRoll, isTrue);
      expect(model.currentPlayer, 0);
      expect(model.phase, LudoTurnPhase.awaitingRoll);
    });

    test('requires an exact roll to reach final home', () {
      final model = _state(
        tokens: const [
          [55, 54, -1, 56],
          [-1, -1, -1, -1],
        ],
        dice: [2, 1],
      );

      expect(model.rollDice().legalTokenIndexes, [1]);
      expect(model.moveToken(0, 0), LudoMoveResult.illegalMove);
      expect(model.moveToken(0, 1), LudoMoveResult.accepted);
      expect(model.progressFor(0, 1), 56);
      expect(model.lastMove?.bonusRoll, isTrue);

      // Reaching the goal keeps the turn, and the next token also needs exact 1.
      expect(model.currentPlayer, 0);
      expect(model.rollDice().legalTokenIndexes, [0]);
      expect(model.moveToken(0, 0), LudoMoveResult.accepted);
      expect(model.lastMove?.reachedFinalHome, isTrue);
    });

    test(
      'produces ordered standings and skips players who already finished',
      () {
        final dice = _DiceSequence([1, 2, 1]);
        final model = LudoModel.fromState(
          playerCount: 3,
          diceRoller: dice.roll,
          tokenProgress: const [
            [56, 56, 56, 55],
            [56, 56, 56, 54],
            [56, 56, 56, 55],
          ],
        );

        model.rollDice();
        model.moveToken(0, 3);
        expect(model.standings, [0]);
        expect(model.currentPlayer, 1);

        model.rollDice();
        model.moveToken(1, 3);
        expect(model.isFinished, isTrue);
        expect(model.phase, LudoTurnPhase.finished);
        expect(model.standings, [0, 1, 2]);
        expect(model.winner, 0);
        expect(model.lastMove?.nextPlayerIndex, isNull);
        expect(() => model.rollDice(), throwsStateError);
        expect(model.moveToken(2, 3), LudoMoveResult.matchFinished);
      },
    );

    test('rejects invalid actions without changing a pending choice', () {
      final model = LudoModel(playerCount: 2, diceRoller: () => 6);

      expect(model.moveToken(0, 0), LudoMoveResult.rollRequired);
      model.rollDice();
      expect(model.moveToken(-1, 0), LudoMoveResult.invalidPlayer);
      expect(model.moveToken(0, 4), LudoMoveResult.invalidToken);
      expect(model.moveToken(1, 0), LudoMoveResult.wrongTurn);
      expect(model.pendingRoll, 6);
      expect(() => model.rollDice(), throwsStateError);
    });

    test('validates dice and restored state', () {
      expect(
        () => LudoModel(playerCount: 1, diceRoller: () => 1),
        throwsArgumentError,
      );
      expect(
        () => LudoModel(playerCount: 5, diceRoller: () => 1),
        throwsArgumentError,
      );
      expect(
        () => LudoModel(playerCount: 2, startingPlayer: 2, diceRoller: () => 1),
        throwsArgumentError,
      );
      expect(
        () => LudoModel(playerCount: 2, diceRoller: () => 0).rollDice(),
        throwsStateError,
      );
      expect(
        () => _state(
          tokens: const [
            [-1],
            [-1],
          ],
          dice: const [1],
        ),
        throwsArgumentError,
      );
      expect(
        () => _state(
          tokens: const [
            [57, -1, -1, -1],
            [-1, -1, -1, -1],
          ],
          dice: const [1],
        ),
        throwsArgumentError,
      );
    });

    test('exposes immutable state and resets to the chosen starter', () {
      final model = LudoModel(
        playerCount: 3,
        startingPlayer: 2,
        diceRoller: () => 6,
      );
      model.rollDice();
      model.moveToken(2, 0);

      expect(() => model.tokenProgress[0][0] = 5, throwsUnsupportedError);
      expect(() => model.standings.add(0), throwsUnsupportedError);

      model.reset();
      expect(model.currentPlayer, 2);
      expect(model.phase, LudoTurnPhase.awaitingRoll);
      expect(model.pendingRoll, isNull);
      expect(model.lastRoll, isNull);
      expect(model.lastMove, isNull);
      expect(model.standings, isEmpty);
      expect(model.tokenProgress.expand((tokens) => tokens), everyElement(-1));
    });

    test('restores a pending rolled value and its exact legal choices', () {
      final model = LudoModel.fromState(
        playerCount: 2,
        diceRoller: () => 2,
        tokenProgress: const [
          [-1, 54, 55, 56],
          [-1, -1, -1, -1],
        ],
        pendingRoll: 2,
      );

      expect(model.phase, LudoTurnPhase.awaitingMove);
      expect(model.pendingRoll, 2);
      expect(model.legalTokenIndexes, [1]);
      expect(model.lastRoll?.value, 2);
      expect(model.moveToken(0, 1), LudoMoveResult.accepted);
      expect(model.progressFor(0, 1), 56);
    });

    test('rejects a restored roll without any legal token', () {
      expect(
        () => LudoModel.fromState(
          playerCount: 2,
          diceRoller: () => 1,
          tokenProgress: const [
            [-1, -1, -1, -1],
            [-1, -1, -1, -1],
          ],
          pendingRoll: 3,
        ),
        throwsArgumentError,
      );
    });
  });
}
