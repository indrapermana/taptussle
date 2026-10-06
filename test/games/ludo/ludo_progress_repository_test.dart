import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';
import 'package:tap_tussle/games/ludo/ludo_progress_repository.dart';

void main() {
  late SharedPreferences preferences;
  late LudoProgressRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
    repository = LudoProgressRepository(preferences);
  });

  test('round-trips positions, turn, standings, and a pending roll', () async {
    final options = _threePlayerOptions();
    final model = LudoModel.fromState(
      playerCount: 3,
      diceRoller: () => 4,
      tokenProgress: const [
        [10, 56, -1, -1],
        [20, 30, -1, -1],
        [56, 56, 56, 56],
      ],
      currentPlayer: 1,
      standings: const [2],
      pendingRoll: 4,
    );

    await repository.save(options, model);
    final snapshot = repository.load(options)!;
    final restored = snapshot.restoreModel(() => 1);

    expect(restored.tokenProgress, model.tokenProgress);
    expect(restored.currentPlayer, 1);
    expect(restored.standings, [2]);
    expect(restored.pendingRoll, 4);
    expect(restored.phase, LudoTurnPhase.awaitingMove);
  });

  test('keeps different participant configurations independent', () async {
    final friend = MatchOptions.friend();
    final bot = MatchOptions.bot(difficulty: BotDifficulty.hard);
    final model = LudoModel(playerCount: 2, diceRoller: () => 6)..rollDice();

    await repository.save(friend, model);

    expect(repository.load(friend), isNotNull);
    expect(repository.load(bot), isNull);
  });

  test('ignores malformed and internally invalid saved data', () async {
    await preferences.setString('ludo.active.v2.h_h', '{bad json');
    expect(repository.load(MatchOptions.friend()), isNull);

    await preferences.setString(
      'ludo.active.v2.h_h',
      jsonEncode({
        'version': 2,
        'signature': 'h_h',
        'tokenProgress': [
          [99, -1, -1, -1],
          [-1, -1, -1, -1],
        ],
        'currentPlayer': 0,
        'standings': [],
        'pendingRoll': null,
      }),
    );
    expect(repository.load(MatchOptions.friend()), isNull);
  });

  test('clear removes only the selected configuration', () async {
    final options = MatchOptions.friend();
    final model = LudoModel(playerCount: 2, diceRoller: () => 6)..rollDice();
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
