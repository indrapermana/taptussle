import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/mancala/mancala_controller.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';

void main() {
  testWidgets('animates each sown stone and locks input until settled', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      sowingStepDuration: const Duration(milliseconds: 10),
      settleDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.tapPit(0, 2), MancalaTapResult.accepted);
    expect(controller.displayBoard.take(7), [4, 4, 0, 4, 4, 4, 0]);
    expect(controller.activePosition, 2);
    expect(controller.acceptsInput, isFalse);
    expect(controller.tapPit(0, 0), MancalaTapResult.ignored);

    for (final position in [3, 4, 5, 6]) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.activePosition, position);
    }
    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 10));

    expect(controller.isAnimating, isFalse);
    expect(controller.activePosition, isNull);
    expect(controller.displayBoard, controller.model.board);
    expect(controller.acceptsInput, isTrue);
  });

  testWidgets('stays animating throughout a long sowing path before capture', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      model: MancalaModel.fromBoard(
        board: const [13, 1, 1, 1, 1, 1, 0, 1, 1, 1, 1, 1, 5, 21],
      ),
      sowingStepDuration: const Duration(milliseconds: 10),
      settleDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.tapPit(0, 0), MancalaTapResult.accepted);
    expect(controller.model.lastTurn!.wasCapture, isTrue);

    for (var step = 0; step < 13; step++) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(
        controller.isAnimating,
        isTrue,
        reason: 'sowing must remain active after step ${step + 1}',
      );
    }

    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.isAnimating, isFalse);
  });

  test('ignores wrong-side and empty-pit input without mutation', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final model = MancalaModel.fromBoard(
      board: const [1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0],
    );
    final controller = MancalaController(session: session, model: model);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    final before = model.board;

    expect(controller.tapPit(1, 0), MancalaTapResult.ignored);
    expect(controller.tapPit(0, 1), MancalaTapResult.ignored);
    expect(model.board, before);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('publishes final store scores after the animation settles', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      model: MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
      ),
      sowingStepDuration: const Duration(milliseconds: 10),
      settleDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.tapPit(0, 5);
    expect(controller.model.isFinished, isTrue);
    expect(session.phase, MatchPhase.playing);
    await tester.pump(const Duration(milliseconds: 20));

    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 1);
    expect(session.scores, [21, 23]);
    expect(session.resultDetails, contains('Player 2'));
  });

  testWidgets('pause settles safely and rematch alternates the starter', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      sowingStepDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.tapPit(0, 2);
    session.pause();
    expect(controller.isAnimating, isFalse);
    expect(controller.displayBoard, controller.model.board);
    expect(controller.tapPit(0, 0), MancalaTapResult.ignored);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    session.resume();
    expect(controller.acceptsInput, isTrue);

    final finishingSession = MatchSession(options: MatchOptions.friend())
      ..start();
    final finishingController = MancalaController(
      session: finishingSession,
      model: MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
      ),
      sowingStepDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
    addTearDown(finishingController.dispose);
    addTearDown(finishingSession.dispose);
    finishingController.tapPit(0, 5);
    await tester.pumpAndSettle();
    expect(finishingSession.phase, MatchPhase.finished);

    finishingSession.start();
    expect(finishingController.model.startingPlayer, 1);
    expect(finishingController.model.currentPlayer, 1);
    expect(finishingController.model.board.fold(0, (a, b) => a + b), 48);
  });

  testWidgets('bot waits after human sowing and blocks human input', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.easy),
    )..start();
    final controller = MancalaController(
      session: session,
      random: Random(7),
      botThinkDelay: const Duration(milliseconds: 20),
      sowingStepDuration: const Duration(milliseconds: 1),
      settleDuration: const Duration(milliseconds: 1),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.tapPit(0, 0);
    expect(controller.isAnimating, isTrue);
    expect(controller.isBotThinking, isFalse);
    await tester.pump(const Duration(milliseconds: 5));

    expect(controller.model.currentPlayer, 1);
    expect(controller.isBotThinking, isTrue);
    expect(controller.acceptsInput, isFalse);
    expect(controller.tapPit(1, 0), MancalaTapResult.ignored);
    await tester.pump(const Duration(milliseconds: 19));
    expect(controller.model.lastTurn?.player, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.model.lastTurn?.player, 1);
    expect(controller.isAnimating, isTrue);
    controller.dispose();
  });

  testWidgets('pause cancels bot thinking and resume starts a fresh delay', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.normal),
    );
    final controller = MancalaController(
      session: session,
      model: MancalaModel(startingPlayer: 1),
      random: Random(8),
      botThinkDelay: const Duration(milliseconds: 20),
      sowingStepDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();

    expect(controller.isBotThinking, isTrue);
    session.pause();
    expect(controller.isBotThinking, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(controller.model.lastTurn, isNull);

    session.resume();
    expect(controller.isBotThinking, isTrue);
    await tester.pump(const Duration(milliseconds: 19));
    expect(controller.model.lastTurn, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.model.lastTurn?.player, 1);
    controller.dispose();
  });

  testWidgets('bot starts an alternating rematch and disposal cancels it', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.hard),
    )..start();
    final controller = MancalaController(
      session: session,
      model: MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 30, 1, 0, 0, 0, 0, 0, 16],
      ),
      random: Random(9),
      botThinkDelay: const Duration(milliseconds: 20),
      sowingStepDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
    addTearDown(session.dispose);

    controller.tapPit(0, 5);
    await tester.pumpAndSettle();
    expect(session.phase, MatchPhase.finished);
    session.start();
    expect(controller.model.currentPlayer, 1);
    expect(controller.isBotThinking, isTrue);

    controller.dispose();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.model.lastTurn, isNull);
    expect(tester.takeException(), isNull);
  });
}
