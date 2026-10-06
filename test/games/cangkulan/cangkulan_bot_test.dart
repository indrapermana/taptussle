import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_bot.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';

void main() {
  test('every difficulty returns a legal action', () {
    final observation = _observation(
      hand: [_heart(2), _heart(10), _heart(14)],
      trick: [_play(0, _heart(9))],
    );

    for (final difficulty in BotDifficulty.values) {
      final action = CangkulanBot(
        difficulty: difficulty,
        random: Random(4),
      ).chooseAction(observation);
      expect(observation.legalActions, contains(action));
    }
  });

  test('normal spends its strongest winner while hard wins efficiently', () {
    final observation = _observation(
      hand: [_heart(2), _heart(10), _heart(14)],
      trick: [_play(0, _heart(9))],
    );

    final normal = CangkulanBot(
      difficulty: BotDifficulty.normal,
    ).chooseAction(observation);
    final hard = CangkulanBot(
      difficulty: BotDifficulty.hard,
    ).chooseAction(observation);

    expect(normal!.card, _heart(14));
    expect(hard!.card, _heart(10));
  });

  test('hard lead sheds the lowest card from its longest suit', () {
    final observation = _observation(
      hand: [_club(11), _club(3), _club(8), _heart(2), _spade(4)],
    );

    final action = CangkulanBot(
      difficulty: BotDifficulty.hard,
    ).chooseAction(observation);

    expect(action!.card, _club(3));
  });

  test('cangkul remains the forced action at every difficulty', () {
    final action = const CangkulanLegalAction.cangkul();
    final observation = CangkulanBotObservation(
      player: 1,
      hand: [_club(2)],
      legalActions: [action],
      trickPlays: [_play(0, _heart(9))],
      handCounts: const [2, 1, 4],
      drawPileCount: 12,
    );

    for (final difficulty in BotDifficulty.values) {
      expect(
        CangkulanBot(difficulty: difficulty).chooseAction(observation),
        action,
      );
    }
  });
}

CangkulanBotObservation _observation({
  required List<CangkulanCard> hand,
  List<CangkulanTrickPlay> trick = const [],
}) => CangkulanBotObservation(
  player: 1,
  hand: hand,
  legalActions: hand.map(CangkulanLegalAction.play).toList(),
  trickPlays: trick,
  handCounts: [5, hand.length, 4],
  drawPileCount: 10,
);

CangkulanTrickPlay _play(int player, CangkulanCard card) =>
    CangkulanTrickPlay(player: player, card: card);
CangkulanCard _heart(int strength) =>
    CangkulanCard(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    CangkulanCard(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    CangkulanCard(CangkulanSuit.spades, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
