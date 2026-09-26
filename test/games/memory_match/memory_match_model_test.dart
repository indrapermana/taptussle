import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';

Map<int, List<int>> pairIndexes(MemoryMatchModel model) {
  final pairs = <int, List<int>>{};
  for (var index = 0; index < model.cardCount; index++) {
    pairs.putIfAbsent(model.deck[index], () => []).add(index);
  }
  return pairs;
}

void matchPair(MemoryMatchModel model, int player, List<int> cards) {
  expect(model.selectCard(player, cards[0]), MemorySelectionResult.firstCard);
  expect(
    model.selectCard(player, cards[1]),
    anyOf(MemorySelectionResult.matched, MemorySelectionResult.completed),
  );
}

void main() {
  group('MemoryMatchModel', () {
    test('difficulty defines board size, pairs and solo preview', () {
      final easy = MemoryMatchModel(
        difficulty: MemoryMatchDifficulty.easy,
        random: Random(1),
      );
      final normal = MemoryMatchModel(
        difficulty: MemoryMatchDifficulty.normal,
        random: Random(1),
      );
      final hard = MemoryMatchModel(
        difficulty: MemoryMatchDifficulty.hard,
        random: Random(1),
      );

      expect((easy.cardCount, easy.pairCount), (12, 6));
      expect(easy.openingPreviewDuration, const Duration(seconds: 3));
      expect((normal.cardCount, normal.pairCount), (16, 8));
      expect(normal.openingPreviewDuration, const Duration(milliseconds: 1500));
      expect((hard.cardCount, hard.pairCount), (24, 12));
      expect(hard.openingPreviewDuration, Duration.zero);
      expect(
        MemoryMatchModel(
          difficulty: MemoryMatchDifficulty.easy,
          playerCount: 2,
          random: Random(1),
        ).openingPreviewDuration,
        Duration.zero,
      );
    });

    test(
      'seeded decks are deterministic and contain exactly two of each pair',
      () {
        final first = MemoryMatchModel(random: Random(42));
        final second = MemoryMatchModel(random: Random(42));

        expect(first.deck, second.deck);
        expect(first.deck, hasLength(16));
        expect(pairIndexes(first), hasLength(8));
        expect(pairIndexes(first).values, everyElement(hasLength(2)));
        expect(() => first.deck.add(99), throwsUnsupportedError);
      },
    );

    test('rejects invalid, wrong-turn and unavailable selections', () {
      final model = MemoryMatchModel(playerCount: 2, random: Random(2));

      expect(model.selectCard(-1, 0), MemorySelectionResult.invalidPlayer);
      expect(
        model.selectCard(0, model.cardCount),
        MemorySelectionResult.outOfBounds,
      );
      expect(model.selectCard(1, 0), MemorySelectionResult.wrongTurn);
      expect(model.selectCard(0, 0), MemorySelectionResult.firstCard);
      expect(model.selectCard(0, 0), MemorySelectionResult.unavailable);
      expect(model.moveCount, 0);
    });

    test('a match counts one move, scores, and keeps the turn', () {
      final model = MemoryMatchModel(playerCount: 2, random: Random(3));
      final cards = pairIndexes(model).values.first;

      matchPair(model, 0, cards);

      expect(model.moveCount, 1);
      expect(model.matchedPairs, 1);
      expect(model.scores, [1, 0]);
      expect(model.currentPlayer, 0);
      expect(model.cardAt(cards[0]).state, MemoryCardState.matched);
      expect(model.cardAt(cards[1]).state, MemoryCardState.matched);
    });

    test(
      'a mismatch locks selection until resolution then passes the turn',
      () {
        final model = MemoryMatchModel(playerCount: 2, random: Random(4));
        final pairs = pairIndexes(model).values.toList();
        final first = pairs[0][0];
        final second = pairs[1][0];

        expect(model.selectCard(0, first), MemorySelectionResult.firstCard);
        expect(model.selectCard(0, second), MemorySelectionResult.mismatch);
        expect(model.moveCount, 1);
        expect(model.hasPendingMismatch, isTrue);
        expect(model.cardAt(first).state, MemoryCardState.revealed);
        expect(
          model.selectCard(0, pairs[2][0]),
          MemorySelectionResult.awaitingMismatchResolution,
        );
        expect(model.resolveMismatch(), isTrue);
        expect(model.currentPlayer, 1);
        expect(model.revealedCards, isEmpty);
        expect(model.cardAt(first).state, MemoryCardState.hidden);
        expect(model.resolveMismatch(), isFalse);
      },
    );

    test('solo mismatch resolution keeps the only player turn', () {
      final model = MemoryMatchModel(random: Random(5));
      final pairs = pairIndexes(model).values.toList();

      model.selectCard(0, pairs[0][0]);
      expect(model.selectCard(0, pairs[1][0]), MemorySelectionResult.mismatch);
      expect(model.resolveMismatch(), isTrue);
      expect(model.currentPlayer, 0);
    });

    test('matching every pair completes and freezes the match', () {
      final model = MemoryMatchModel(
        difficulty: MemoryMatchDifficulty.easy,
        playerCount: 2,
        random: Random(6),
      );
      final pairs = pairIndexes(model).values.toList();

      for (final cards in pairs) {
        matchPair(model, 0, cards);
      }

      expect(model.isFinished, isTrue);
      expect(model.winner, 0);
      expect(model.isDraw, isFalse);
      expect(model.scores, [6, 0]);
      expect(model.moveCount, 6);
      expect(model.selectCard(0, 0), MemorySelectionResult.matchFinished);
    });

    test('equal pair scores produce a two-player draw', () {
      final model = MemoryMatchModel(
        difficulty: MemoryMatchDifficulty.easy,
        playerCount: 2,
        random: Random(7),
      );
      final pairs = pairIndexes(model).values.toList();
      for (final cards in pairs.take(3)) {
        matchPair(model, 0, cards);
      }
      model.selectCard(0, pairs[3][0]);
      expect(model.selectCard(0, pairs[4][0]), MemorySelectionResult.mismatch);
      model.resolveMismatch();
      for (final cards in pairs.skip(3)) {
        matchPair(model, 1, cards);
      }

      expect(model.isFinished, isTrue);
      expect(model.scores, [3, 3]);
      expect(model.isDraw, isTrue);
      expect(model.winner, isNull);
    });

    test('rematch reshuffles, clears progress, and alternates the starter', () {
      final model = MemoryMatchModel(playerCount: 2, random: Random(8));
      final originalDeck = model.deck;
      matchPair(model, 0, pairIndexes(model).values.first);

      model.startRematch();

      expect(model.deck, isNot(originalDeck));
      expect(model.startingPlayer, 1);
      expect(model.currentPlayer, 1);
      expect(model.scores, [0, 0]);
      expect(model.moveCount, 0);
      expect(model.matchedPairs, 0);
      expect(model.revealedCards, isEmpty);

      model.startRematch();
      expect(model.startingPlayer, 0);
      expect(model.currentPlayer, 0);
    });

    test('invalid player configurations are rejected', () {
      expect(() => MemoryMatchModel(playerCount: 0), throwsArgumentError);
      expect(() => MemoryMatchModel(playerCount: 3), throwsArgumentError);
      expect(
        () => MemoryMatchModel(playerCount: 1, startingPlayer: 1),
        throwsArgumentError,
      );
    });
  });
}
