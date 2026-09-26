import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_controller.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_model.dart';

void main() {
  test(
    'bot waits before moving and human input is blocked during its turn',
    () async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.easy),
      );
      final controller = TicTacToeController(
        session: session,
        random: Random(1),
        botThinkDelay: const Duration(milliseconds: 60),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      session.start();

      expect(controller.humanMove(0), TicTacToeMoveResult.accepted);
      expect(controller.isBotThinking, isTrue);
      expect(controller.model.moveCount, 1);
      expect(controller.humanMove(1), TicTacToeMoveResult.wrongTurn);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.model.moveCount, 1);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      expect(controller.model.moveCount, 2);
      expect(controller.model.currentPlayer, 0);
    },
  );

  test(
    'pause cancels a bot turn and resume schedules one fresh delay',
    () async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.normal),
      );
      final controller = TicTacToeController(
        session: session,
        random: Random(2),
        botThinkDelay: const Duration(milliseconds: 60),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      session.start();
      controller.humanMove(0);

      session.pause();
      expect(controller.isBotThinking, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 80));
      expect(controller.model.moveCount, 1);

      session.resume();
      expect(controller.isBotThinking, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(controller.model.moveCount, 1);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.model.moveCount, 2);
    },
  );

  test('dispose cancels a pending bot move', () async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.hard),
    );
    final controller = TicTacToeController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 40),
    );
    addTearDown(session.dispose);
    session.start();
    controller.humanMove(0);

    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 70));

    expect(controller.model.moveCount, 1);
  });

  test('friend moves publish a shared winner result', () {
    final session = MatchSession(options: MatchOptions.friend());
    final controller = TicTacToeController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();

    for (final cell in const [0, 3, 1, 4, 2]) {
      expect(controller.humanMove(cell), TicTacToeMoveResult.accepted);
    }

    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 0);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.scores, [1, 0]);
  });

  test(
    'rematch alternates starter and schedules the bot when it starts',
    () async {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: BotDifficulty.easy),
      );
      final controller = TicTacToeController(
        session: session,
        random: Random(3),
        botThinkDelay: const Duration(milliseconds: 40),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      session.start();

      for (final move in const [(0, 0), (1, 3), (0, 1), (1, 4), (0, 2)]) {
        expect(
          controller.model.play(move.$1, move.$2),
          TicTacToeMoveResult.accepted,
        );
      }
      session.reportNonPointResult(winner: 0, details: 'Finished');

      session.start();
      expect(controller.model.startingPlayer, 1);
      expect(controller.model.currentPlayer, 1);
      expect(controller.isBotThinking, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(controller.model.moveCount, 1);
      expect(controller.model.currentPlayer, 0);
    },
  );
}
