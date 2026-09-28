import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/memory_match/memory_match_controller.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';

List<int> _mismatch(MemoryMatchModel model) {
  final first = 0;
  return [first, model.deck.indexWhere((pair) => pair != model.deck[first])];
}

void main() {
  testWidgets('bot waits, then makes two legal selections', (tester) async {
    final selections = <MemorySelectionResult>[];
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.normal),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.normal,
      random: Random(20),
      mismatchRevealDuration: const Duration(milliseconds: 10),
      botThinkDuration: const Duration(milliseconds: 10),
      onSelection: selections.add,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();

    final mismatch = _mismatch(controller.model);
    controller.selectCard(mismatch[0]);
    controller.selectCard(mismatch[1]);
    await tester.pump(const Duration(milliseconds: 10));

    expect(controller.isBotThinking, isTrue);
    expect(controller.acceptsInput, isFalse);
    final beforeBot = selections.length;
    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.model.revealedCards, hasLength(1));
    await tester.pump(const Duration(milliseconds: 10));

    expect(selections.length, beforeBot + 2);
    expect(
      selections.skip(beforeBot),
      everyElement(
        isIn(const [
          MemorySelectionResult.firstCard,
          MemorySelectionResult.matched,
          MemorySelectionResult.mismatch,
          MemorySelectionResult.completed,
        ]),
      ),
    );
    controller.dispose();
  });

  testWidgets('pause cancels a pending choice and resume restarts its delay', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.easy),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(21),
      mismatchRevealDuration: const Duration(milliseconds: 10),
      botThinkDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();

    final mismatch = _mismatch(controller.model);
    controller.selectCard(mismatch[0]);
    controller.selectCard(mismatch[1]);
    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.isBotThinking, isTrue);

    session.pause();
    await tester.pump(const Duration(seconds: 1));
    expect(controller.model.revealedCards, isEmpty);
    expect(controller.model.moveCount, 1);

    session.resume();
    await tester.pump(const Duration(milliseconds: 19));
    expect(controller.model.revealedCards, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.model.revealedCards, hasLength(1));
    controller.dispose();
  });

  testWidgets('alternating rematch lets the bot start after a fresh delay', (
    tester,
  ) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.hard),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.hard,
      random: Random(22),
      botThinkDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();
    session.reportResult(
      outcome: MatchOutcome.winner,
      scores: const [1, 0],
      winner: 0,
    );

    session.start();

    expect(controller.model.startingPlayer, 1);
    expect(controller.isBotThinking, isTrue);
    expect(controller.model.revealedCards, isEmpty);
    await tester.pump(const Duration(milliseconds: 10));
    expect(controller.model.revealedCards, hasLength(1));
    controller.dispose();
  });

  testWidgets('disposal cancels pending bot work', (tester) async {
    final session = MatchSession(
      options: MatchOptions.bot(difficulty: BotDifficulty.normal),
    );
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.normal,
      random: Random(23),
      mismatchRevealDuration: const Duration(milliseconds: 1),
      botThinkDuration: const Duration(milliseconds: 10),
    );
    addTearDown(session.dispose);
    session.start();
    final mismatch = _mismatch(controller.model);
    controller.selectCard(mismatch[0]);
    controller.selectCard(mismatch[1]);
    await tester.pump(const Duration(milliseconds: 1));

    controller.dispose();
    await tester.pump(const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
