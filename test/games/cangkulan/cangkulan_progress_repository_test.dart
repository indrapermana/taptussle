import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_progress_repository.dart';

void main() {
  late SharedPreferences preferences;
  late CangkulanProgressRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = CangkulanProgressRepository(preferences);
  });

  test(
    'round-trips hands, pile, current trick, and completed tricks',
    () async {
      final options = _threePlayerOptions();
      final completed = CangkulanCompletedTrick(
        leader: 0,
        requiredSuit: CangkulanSuit.hearts,
        turns: [
          CangkulanTrickTurn(player: 0, playedCard: _heart(7)),
          CangkulanTrickTurn(player: 1, playedCard: _heart(10)),
          CangkulanTrickTurn(player: 2, playedCard: _heart(8)),
        ],
        winner: 1,
      );
      final model = CangkulanModel.fromState(
        hands: [
          [_club(2), _spade(4)],
          [_club(3), _spade(5)],
          [_club(4), _spade(6)],
        ],
        drawPile: [_diamond(2), _diamond(3)],
        currentPlayer: 2,
        trickLeader: 1,
        currentTrickTurns: [
          CangkulanTrickTurn(player: 1, playedCard: _club(8)),
        ],
        completedTricks: [completed],
      );

      await repository.save(options, model);
      final restored = repository.load(options)!;

      expect(restored.hands, model.hands);
      expect(restored.drawPile, model.drawPile);
      expect(restored.currentPlayer, 2);
      expect(restored.trickLeader, 1);
      expect(restored.currentTrickTurns.single.playedCard, _club(8));
      expect(restored.completedTricks.single.winner, 1);
    },
  );

  test('keeps participant configurations independent', () async {
    final friend = MatchOptions.friend();
    final bot = MatchOptions.bot(difficulty: BotDifficulty.hard);
    final model = CangkulanModel.fromState(
      hands: [
        [_heart(2)],
        [_heart(3)],
      ],
    );

    await repository.save(friend, model);

    expect(repository.load(friend), isNotNull);
    expect(repository.load(bot), isNull);
  });

  test('rejects malformed, mismatched, and invalid saved state', () async {
    await preferences.setString('cangkulan.active.v1.h_h', '{bad json');
    expect(repository.load(MatchOptions.friend()), isNull);

    await preferences.setString(
      'cangkulan.active.v1.h_h',
      jsonEncode({
        'version': 1,
        'signature': 'h_h',
        'hands': [
          ['2:0'],
          ['2:0'],
        ],
        'drawPile': [],
        'currentPlayer': 0,
        'trickLeader': 0,
        'currentTrickTurns': [],
        'completedTricks': [],
        'winner': null,
      }),
    );
    expect(repository.load(MatchOptions.friend()), isNull);
  });

  test('clear removes the selected active match', () async {
    final options = MatchOptions.friend();
    final model = CangkulanModel.fromState(
      hands: [
        [_heart(2)],
        [_heart(3)],
      ],
    );
    await repository.save(options, model);
    expect(repository.load(options), isNotNull);

    await repository.clear(options);

    expect(repository.load(options), isNull);
  });
}

MatchOptions _threePlayerOptions() => MatchOptions.custom(
  mode: PlayMode.bot,
  participants: const [
    MatchParticipant.human(
      displayName: 'One',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    MatchParticipant.bot(
      displayName: 'Bot',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
      difficulty: BotDifficulty.normal,
    ),
    MatchParticipant.human(
      displayName: 'Three',
      color: ParticipantColor.gold,
      token: ParticipantToken.triangle,
    ),
  ],
);

CangkulanCard _heart(int strength) =>
    CangkulanCard(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    CangkulanCard(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    CangkulanCard(CangkulanSuit.spades, _rank(strength));
CangkulanCard _diamond(int strength) =>
    CangkulanCard(CangkulanSuit.diamonds, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
