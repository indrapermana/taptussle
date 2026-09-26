import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/reaction_duel/reaction_duel_controller.dart';

void main() {
  test('false start awards the other player', () {
    final session = MatchSession(options: MatchOptions.friend(winningScore: 5))
      ..start();
    final controller = ReactionDuelController(
      session: session,
      random: Random(1),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.startRound();
    controller.tap(0);

    expect(controller.scores, [0, 1]);
    expect(session.scores, [0, 1]);
  });

  test('near-simultaneous legal taps replay without a score', () async {
    final session = MatchSession(options: MatchOptions.friend(winningScore: 5))
      ..start();
    final controller = ReactionDuelController(
      session: session,
      waitDelay: Duration.zero,
      random: Random(1),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.startRound();
    await Future<void>.delayed(Duration.zero);
    expect(controller.phase, ReactionPhase.signal);
    controller.tap(0);
    controller.tap(1);
    await Future<void>.delayed(const Duration(milliseconds: 750));

    expect(controller.scores, [0, 0]);
  });

  test('bot only reacts after the signal', () async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.hard),
    )..start();
    final controller = ReactionDuelController(
      session: session,
      waitDelay: const Duration(milliseconds: 20),
      botDelay: const Duration(milliseconds: 20),
      random: Random(1),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.startRound();
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(controller.phase, ReactionPhase.signal);
    expect(controller.scores, [0, 0]);
    await Future<void>.delayed(const Duration(milliseconds: 150));
    expect(controller.scores, [0, 1]);
  });
}
