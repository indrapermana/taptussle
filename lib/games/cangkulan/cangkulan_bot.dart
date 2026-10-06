import 'dart:math';

import '../../core/match_options.dart';
import 'cangkulan_model.dart';

/// The information a local Cangkulan player is allowed to use.
///
/// Opponent cards and the order of the draw pile are deliberately absent so a
/// bot follows the same information boundary as a human looking at the table.
class CangkulanBotObservation {
  CangkulanBotObservation({
    required this.player,
    required List<CangkulanCard> hand,
    required List<CangkulanLegalAction> legalActions,
    required List<CangkulanTrickPlay> trickPlays,
    required List<int> handCounts,
    required this.drawPileCount,
  }) : hand = List.unmodifiable(hand),
       legalActions = List.unmodifiable(legalActions),
       trickPlays = List.unmodifiable(trickPlays),
       handCounts = List.unmodifiable(handCounts);

  factory CangkulanBotObservation.fromModel(CangkulanModel model, int player) {
    if (player != model.currentPlayer) {
      throw ArgumentError.value(player, 'player', 'Must be the current player');
    }
    return CangkulanBotObservation(
      player: player,
      hand: model.hands[player],
      legalActions: model.legalActions,
      trickPlays: model.trickPlays,
      handCounts: model.hands.map((hand) => hand.length).toList(),
      drawPileCount: model.drawPile.length,
    );
  }

  final int player;
  final List<CangkulanCard> hand;
  final List<CangkulanLegalAction> legalActions;
  final List<CangkulanTrickPlay> trickPlays;
  final List<int> handCounts;
  final int drawPileCount;

  CangkulanSuit? get requiredSuit =>
      trickPlays.isEmpty ? null : trickPlays.first.card.suit;
}

class CangkulanBot {
  CangkulanBot({required this.difficulty, Random? random})
    : _random = random ?? Random();

  final BotDifficulty difficulty;
  final Random _random;

  CangkulanLegalAction? chooseAction(CangkulanBotObservation observation) {
    final legal = observation.legalActions;
    if (legal.isEmpty) return null;
    if (legal.length == 1 ||
        legal.singleOrNull?.type == CangkulanLegalActionType.cangkul) {
      return legal.first;
    }

    final cards = [for (final action in legal) action.card!];
    final chosen = switch (difficulty) {
      BotDifficulty.easy => cards[_random.nextInt(cards.length)],
      BotDifficulty.normal => _chooseNormal(cards, observation),
      BotDifficulty.hard => _chooseHard(cards, observation),
    };
    return CangkulanLegalAction.play(chosen);
  }

  CangkulanCard _chooseNormal(
    List<CangkulanCard> cards,
    CangkulanBotObservation observation,
  ) {
    if (observation.trickPlays.isEmpty) {
      return _lowest(cards);
    }
    final currentBest = _currentWinningStrength(observation.trickPlays);
    final winners = cards
        .where((card) => card.rank.strength > currentBest)
        .toList();
    return winners.isNotEmpty ? _highest(winners) : _lowest(cards);
  }

  CangkulanCard _chooseHard(
    List<CangkulanCard> cards,
    CangkulanBotObservation observation,
  ) {
    if (observation.trickPlays.isNotEmpty) {
      final currentBest = _currentWinningStrength(observation.trickPlays);
      final winners = cards
          .where((card) => card.rank.strength > currentBest)
          .toList();
      // Win with the cheapest sufficient card and preserve stronger cards.
      return winners.isNotEmpty ? _lowest(winners) : _lowest(cards);
    }

    // Lead a low card from the suit held most often. This sheds a long suit
    // while keeping high cards available to regain the lead later.
    final suitCounts = <CangkulanSuit, int>{};
    for (final card in observation.hand) {
      suitCounts.update(card.suit, (count) => count + 1, ifAbsent: () => 1);
    }
    final mostCommon = suitCounts.entries.reduce((left, right) {
      if (left.value != right.value) {
        return left.value > right.value ? left : right;
      }
      return left.key.index < right.key.index ? left : right;
    }).key;
    return _lowest(cards.where((card) => card.suit == mostCommon).toList());
  }

  int _currentWinningStrength(List<CangkulanTrickPlay> plays) =>
      plays.map((play) => play.card.rank.strength).reduce(max);

  CangkulanCard _lowest(List<CangkulanCard> cards) =>
      cards.reduce((left, right) => _compare(left, right) <= 0 ? left : right);

  CangkulanCard _highest(List<CangkulanCard> cards) =>
      cards.reduce((left, right) => _compare(left, right) >= 0 ? left : right);

  int _compare(CangkulanCard left, CangkulanCard right) {
    final rank = left.rank.strength.compareTo(right.rank.strength);
    return rank != 0 ? rank : left.suit.index.compareTo(right.suit.index);
  }
}
