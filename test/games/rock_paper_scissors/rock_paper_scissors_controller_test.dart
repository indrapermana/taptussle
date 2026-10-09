import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_controller.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';

class _FixedRandom implements Random {
  _FixedRandom(this.value);

  final int value;

  @override
  bool nextBool() => nextInt(2) == 0;

  @override
  double nextDouble() => 0;

  @override
  int nextInt(int max) => value % max;
}

void main() {
  test('friend choices are separated by an explicit concealed handoff', () {
    final session = MatchSession(options: MatchOptions.friend(winningScore: 3));
    final controller = RockPaperScissorsController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();

    expect(controller.activePlayer, 0);
    expect(
      controller.selectChoice(RockPaperScissorsChoice.rock),
      RockPaperScissorsSelectionResult.accepted,
    );
    expect(controller.phase, RockPaperScissorsRoundPhase.handoff);
    expect(controller.hasLockedChoice(0), isTrue);
    expect(controller.hasLockedChoice(1), isFalse);
    expect(
      controller.selectChoice(RockPaperScissorsChoice.paper),
      RockPaperScissorsSelectionResult.unavailable,
    );

    expect(controller.confirmHandoff(), isTrue);
    expect(controller.activePlayer, 1);
    expect(
      controller.selectChoice(RockPaperScissorsChoice.scissors),
      RockPaperScissorsSelectionResult.accepted,
    );

    expect(controller.phase, RockPaperScissorsRoundPhase.reveal);
    expect(
      controller.model.lastRound!.playerOneChoice,
      RockPaperScissorsChoice.rock,
    );
    expect(
      controller.model.lastRound!.playerTwoChoice,
      RockPaperScissorsChoice.scissors,
    );
    expect(controller.model.scores, [1, 0]);
    expect(session.scores, [1, 0]);
  });

  test('friend rounds alternate the first chooser', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = RockPaperScissorsController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.selectChoice(RockPaperScissorsChoice.rock);
    controller.confirmHandoff();
    controller.selectChoice(RockPaperScissorsChoice.rock);
    expect(controller.startNextRound(), isTrue);

    expect(controller.activePlayer, 1);
    expect(controller.phase, RockPaperScissorsRoundPhase.choosing);
  });

  testWidgets('bot waits and human input stays locked until reveal', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(
        difficulty: BotDifficulty.easy,
        winningScore: 3,
      ),
    );
    final controller = RockPaperScissorsController(
      session: session,
      random: _FixedRandom(2),
      botThinkDelay: const Duration(milliseconds: 20),
    );
    addTearDown(session.dispose);
    session.start();

    controller.selectChoice(RockPaperScissorsChoice.rock);
    expect(controller.phase, RockPaperScissorsRoundPhase.botThinking);
    expect(controller.isBotThinking, isTrue);
    expect(controller.acceptsChoice, isFalse);
    expect(
      controller.selectChoice(RockPaperScissorsChoice.paper),
      RockPaperScissorsSelectionResult.unavailable,
    );

    await tester.pump(const Duration(milliseconds: 19));
    expect(controller.model.lastRound, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.phase, RockPaperScissorsRoundPhase.reveal);
    expect(
      controller.model.lastRound!.playerTwoChoice,
      RockPaperScissorsChoice.scissors,
    );
    controller.dispose();
  });

  testWidgets('pause cancels bot choice and resume starts a fresh delay', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.normal),
    );
    final controller = RockPaperScissorsController(
      session: session,
      random: _FixedRandom(1),
      botThinkDelay: const Duration(milliseconds: 20),
    );
    addTearDown(session.dispose);
    session.start();
    controller.selectChoice(RockPaperScissorsChoice.paper);

    session.pause();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.model.lastRound, isNull);
    expect(controller.isBotThinking, isFalse);

    session.resume();
    expect(controller.isBotThinking, isTrue);
    await tester.pump(const Duration(milliseconds: 19));
    expect(controller.model.lastRound, isNull);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.model.lastRound, isNotNull);
    controller.dispose();
  });

  testWidgets('winning round publishes configured scores and rematch resets', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(
        difficulty: BotDifficulty.easy,
        winningScore: 1,
      ),
    );
    final controller = RockPaperScissorsController(
      session: session,
      random: _FixedRandom(2),
      botThinkDelay: const Duration(milliseconds: 1),
    );
    addTearDown(session.dispose);
    session.start();
    controller.selectChoice(RockPaperScissorsChoice.rock);
    await tester.pump(const Duration(milliseconds: 1));

    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.winner, 0);
    expect(session.scores, [1, 0]);

    session.start();
    expect(controller.model.scores, [0, 0]);
    expect(controller.model.lastRound, isNull);
    expect(controller.phase, RockPaperScissorsRoundPhase.choosing);
    controller.dispose();
  });

  testWidgets(
    'final choices remain visible and result delay is lifecycle safe',
    (tester) async {
      final session = MatchSession(
        options: MatchOptions.bot(
          difficulty: BotDifficulty.easy,
          winningScore: 1,
        ),
      );
      final controller = RockPaperScissorsController(
        session: session,
        random: _FixedRandom(2),
        botThinkDelay: const Duration(milliseconds: 1),
        finalRevealDelay: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);
      session.start();
      controller.selectChoice(RockPaperScissorsChoice.rock);
      await tester.pump(const Duration(milliseconds: 1));

      expect(controller.phase, RockPaperScissorsRoundPhase.reveal);
      expect(controller.model.lastRound, isNotNull);
      expect(session.phase, MatchPhase.playing);

      await tester.pump(const Duration(milliseconds: 40));
      session.pause();
      await tester.pump(const Duration(milliseconds: 200));
      expect(session.phase, MatchPhase.paused);

      session.resume();
      await tester.pump(const Duration(milliseconds: 99));
      expect(session.phase, MatchPhase.playing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(session.phase, MatchPhase.finished);
    },
  );

  testWidgets('disposal cancels a pending bot choice', (tester) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.hard),
    );
    final controller = RockPaperScissorsController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 10),
    );
    addTearDown(session.dispose);
    session.start();
    controller.selectChoice(RockPaperScissorsChoice.rock);

    controller.dispose();
    await tester.pump(const Duration(milliseconds: 20));

    expect(tester.takeException(), isNull);
  });
}
