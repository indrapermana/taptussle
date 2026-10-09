import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/memory_match/memory_match_controller.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';

List<int> differentPairIndexes(MemoryMatchModel model) {
  final first = 0;
  final second = model.deck.indexWhere((pair) => pair != model.deck[first]);
  return [first, second];
}

void completeEveryPair(MemoryMatchController controller) {
  for (var pair = 0; pair < controller.model.pairCount; pair++) {
    final indexes = <int>[];
    for (var index = 0; index < controller.model.cardCount; index++) {
      if (controller.model.deck[index] == pair) indexes.add(index);
    }
    controller
      ..selectCard(indexes[0])
      ..selectCard(indexes[1]);
  }
}

void main() {
  testWidgets('solo preview reveals every card and locks input', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo());
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(1),
      openingPreviewDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.acceptsInput, isFalse);
    session.start();
    expect(controller.isPreviewing, isTrue);
    expect(controller.acceptsInput, isFalse);
    expect(
      List.generate(controller.model.cardCount, controller.isCardFaceUp),
      everyElement(isTrue),
    );
    expect(controller.selectCard(0), MemorySelectionResult.unavailable);

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.isPreviewing, isFalse);
    expect(controller.acceptsInput, isTrue);
    expect(controller.isCardFaceUp(0), isFalse);
  });

  testWidgets('paused mismatch waits for a fresh delay after resume', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend());
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.normal,
      random: Random(2),
      mismatchRevealDuration: const Duration(milliseconds: 120),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();
    final cards = differentPairIndexes(controller.model);

    expect(controller.selectCard(cards[0]), MemorySelectionResult.firstCard);
    expect(controller.selectCard(cards[1]), MemorySelectionResult.mismatch);
    expect(controller.lastSelectedCards, cards);
    expect(controller.acceptsInput, isFalse);
    expect(controller.isResolvingMismatch, isTrue);

    await tester.pump(const Duration(milliseconds: 40));
    session.pause();
    await tester.pump(const Duration(milliseconds: 300));
    expect(controller.model.hasPendingMismatch, isTrue);
    expect(controller.model.currentPlayer, 0);

    session.resume();
    await tester.pump(const Duration(milliseconds: 119));
    expect(controller.model.hasPendingMismatch, isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.model.hasPendingMismatch, isFalse);
    expect(controller.model.currentPlayer, 1);
    expect(controller.acceptsInput, isTrue);
  });

  testWidgets('rematch cancels stale timers and alternates the starter', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend());
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(3),
      mismatchRevealDuration: const Duration(milliseconds: 50),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();
    final firstDeck = controller.model.deck;
    final cards = differentPairIndexes(controller.model);
    controller.selectCard(cards[0]);
    controller.selectCard(cards[1]);

    session.reportDrawScores(const [0, 0]);
    session.start();
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.model.startingPlayer, 1);
    expect(controller.model.currentPlayer, 1);
    expect(controller.model.deck, isNot(firstDeck));
    expect(controller.model.hasPendingMismatch, isFalse);
    expect(controller.model.moveCount, 0);
  });

  testWidgets('disposing cancels pending reveal callbacks', (tester) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(4),
      mismatchRevealDuration: const Duration(milliseconds: 30),
    );
    final cards = differentPairIndexes(controller.model);
    controller.selectCard(cards[0]);
    controller.selectCard(cards[1]);

    controller.dispose();
    await tester.pump(const Duration(milliseconds: 50));

    expect(controller.model.hasPendingMismatch, isTrue);
    session.dispose();
  });

  testWidgets(
    'finished cards remain visible and result delay restarts on resume',
    (tester) async {
      final session = MatchSession(options: MatchOptions.solo())..start();
      final controller = MemoryMatchController(
        session: session,
        difficulty: MemoryMatchDifficulty.easy,
        random: Random(10),
        openingPreviewDuration: Duration.zero,
        resultRevealDelay: const Duration(milliseconds: 100),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);

      completeEveryPair(controller);

      expect(controller.model.isFinished, isTrue);
      expect(controller.isPresentingResult, isTrue);
      expect(session.phase, MatchPhase.playing);
      expect(
        List.generate(controller.model.cardCount, controller.isCardFaceUp),
        everyElement(isTrue),
      );

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

  testWidgets('disposing cancels a pending result presentation', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(11),
      openingPreviewDuration: Duration.zero,
      resultRevealDelay: const Duration(milliseconds: 30),
    );

    completeEveryPair(controller);
    expect(controller.isPresentingResult, isTrue);
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 50));

    expect(session.phase, MatchPhase.playing);
    session.dispose();
  });
}
