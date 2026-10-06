import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/ludo/ludo_bot.dart';
import 'package:tap_tussle/games/ludo/ludo_controller.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';

void main() {
  testWidgets('animates a chosen token one board space at a time', (
    tester,
  ) async {
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 3,
      tokenProgress: const [
        [0, -1, -1, -1],
        [-1, -1, -1, -1],
      ],
    );
    final controller = LudoController(
      playerCount: 2,
      model: model,
      movementStepDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);

    expect(controller.roll()?.legalTokenIndexes, [0]);
    expect(controller.chooseToken(0), LudoMoveResult.accepted);
    expect(controller.isAnimating, isTrue);
    expect(controller.displayProgress[0][0], 0);
    expect(model.progressFor(0, 0), 3);

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 3);
    expect(controller.isAnimating, isFalse);
    expect(controller.canRoll, isTrue);
  });

  test('locks rolling during token choice and rejects unavailable tokens', () {
    final controller = LudoController(
      playerCount: 2,
      diceRoller: () => 6,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.roll();

    expect(controller.canRoll, isFalse);
    expect(controller.canChooseToken, isTrue);
    expect(controller.legalTokenIndexes, [0, 1, 2, 3]);
    expect(controller.chooseToken(4), LudoMoveResult.invalidToken);
    expect(controller.chooseToken(2), LudoMoveResult.accepted);
    expect(controller.displayProgress[0][2], 0);
    expect(controller.canRoll, isTrue);
  });

  test('synchronizes captured tokens after movement completes', () {
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 1,
      tokenProgress: const [
        [4, -1, -1, -1],
        [44, -1, -1, -1],
      ],
    );
    final controller = LudoController(
      playerCount: 2,
      model: model,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.roll();
    controller.chooseToken(0);

    expect(controller.displayProgress[0][0], 5);
    expect(controller.displayProgress[1][0], LudoModel.boxProgress);
    expect(controller.model.lastMove?.wasCapture, isTrue);
  });

  test('validates a supplied model participant count', () {
    final model = LudoModel(playerCount: 2, diceRoller: () => 1);
    expect(
      () => LudoController(playerCount: 3, model: model),
      throwsArgumentError,
    );
  });

  testWidgets(
    'bot visibly waits to roll and then waits to choose a legal token',
    (tester) async {
      var diceCalls = 0;
      final model = LudoModel.fromState(
        playerCount: 3,
        diceRoller: () {
          diceCalls++;
          return 6;
        },
        tokenProgress: const [
          [-1, -1, -1, -1],
          [-1, -1, -1, -1],
          [-1, -1, -1, -1],
        ],
        currentPlayer: 1,
      );
      final participants = _mixedParticipants();
      final controller = LudoController(
        playerCount: 3,
        participants: participants,
        model: model,
        movementStepDuration: Duration.zero,
        botRollDelay: const Duration(milliseconds: 100),
        botMoveDelay: const Duration(milliseconds: 120),
      );
      addTearDown(controller.dispose);

      expect(controller.isBotTurn, isTrue);
      expect(controller.pendingBotAction, LudoBotAction.rolling);
      expect(controller.canRoll, isFalse);
      expect(controller.canChooseToken, isFalse);
      expect(diceCalls, 0);

      await tester.pump(const Duration(milliseconds: 99));
      expect(diceCalls, 0);
      await tester.pump(const Duration(milliseconds: 1));

      expect(diceCalls, 1);
      expect(model.pendingRoll, 6);
      expect(controller.pendingBotAction, LudoBotAction.choosingToken);
      expect(model.tokenProgress[1], everyElement(LudoModel.boxProgress));

      await tester.pump(const Duration(milliseconds: 119));
      expect(model.tokenProgress[1], everyElement(LudoModel.boxProgress));
      await tester.pump(const Duration(milliseconds: 1));

      expect(
        model.tokenProgress[1].where((progress) => progress == 0),
        hasLength(1),
      );
      expect(model.lastMove?.playerIndex, 1);
      expect(
        model.lastMove?.tokenIndex,
        isIn(model.lastRoll!.legalTokenIndexes),
      );
      expect(controller.pendingBotAction, LudoBotAction.rolling);
      controller.dispose();
    },
  );

  testWidgets(
    'consecutive bot seats use the same dice source then yield to human',
    (tester) async {
      final rolls = [3, 4];
      var rollIndex = 0;
      final participants = _mixedParticipants();
      final model = LudoModel.fromState(
        playerCount: 3,
        diceRoller: () => rolls[rollIndex++],
        tokenProgress: const [
          [-1, -1, -1, -1],
          [-1, -1, -1, -1],
          [-1, -1, -1, -1],
        ],
        currentPlayer: 1,
      );
      final controller = LudoController(
        playerCount: 3,
        participants: participants,
        model: model,
        botRollDelay: const Duration(milliseconds: 10),
        botMoveDelay: const Duration(milliseconds: 10),
        movementStepDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      await tester.pump(const Duration(milliseconds: 10));
      expect(rollIndex, 1);
      expect(model.currentPlayer, 2);
      expect(controller.pendingBotAction, LudoBotAction.rolling);

      await tester.pump(const Duration(milliseconds: 10));
      expect(rollIndex, 2);
      expect(model.currentPlayer, 0);
      expect(controller.isBotTurn, isFalse);
      expect(controller.isBotThinking, isFalse);
      expect(controller.canRoll, isTrue);
      controller.dispose();
    },
  );

  testWidgets('disposing cancels a pending bot action', (tester) async {
    var diceCalls = 0;
    final controller = LudoController(
      playerCount: 2,
      participants: [
        _bot('Bot', ParticipantColor.coral, ParticipantToken.diamond),
        _human('You', ParticipantColor.mint, ParticipantToken.circle),
      ],
      diceRoller: () {
        diceCalls++;
        return 6;
      },
      botRollDelay: const Duration(milliseconds: 20),
    );

    expect(controller.isBotThinking, isTrue);
    controller.dispose();
    await tester.pump(const Duration(milliseconds: 30));

    expect(diceCalls, 0);
  });

  test('rejects participant mismatch and all-bot local matches', () {
    expect(
      () => LudoController(
        playerCount: 2,
        participants: [
          _human('Only', ParticipantColor.mint, ParticipantToken.circle),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => LudoController(
        playerCount: 2,
        participants: [
          _bot('Bot 1', ParticipantColor.mint, ParticipantToken.circle),
          _bot('Bot 2', ParticipantColor.coral, ParticipantToken.diamond),
        ],
      ),
      throwsArgumentError,
    );
  });

  testWidgets('uses the difficulty configured on the active bot seat', (
    tester,
  ) async {
    final recordingBot = _RecordingBot();
    final participants = [
      _bot(
        'Hard Bot',
        ParticipantColor.coral,
        ParticipantToken.diamond,
        difficulty: BotDifficulty.hard,
      ),
      _human('You', ParticipantColor.mint, ParticipantToken.circle),
    ];
    final controller = LudoController(
      playerCount: 2,
      participants: participants,
      diceRoller: () => 6,
      bot: recordingBot,
      botRollDelay: const Duration(milliseconds: 10),
      botMoveDelay: const Duration(milliseconds: 10),
      movementStepDuration: Duration.zero,
    );

    await tester.pump(const Duration(milliseconds: 20));

    expect(recordingBot.observedDifficulty, BotDifficulty.hard);
    expect(recordingBot.observedLegalTokens, [0, 1, 2, 3]);
    controller.dispose();
  });

  testWidgets('pause freezes input and resume preserves a rolled choice', (
    tester,
  ) async {
    final options = MatchOptions.friend();
    final session = MatchSession(options: options)..start();
    final controller = LudoController(
      playerCount: 2,
      participants: options.participants,
      diceRoller: () => 6,
      movementStepDuration: const Duration(milliseconds: 100),
      session: session,
    );
    addTearDown(session.dispose);

    controller.roll();
    expect(controller.canChooseToken, isTrue);
    session.pause();
    expect(controller.canChooseToken, isFalse);
    expect(controller.model.pendingRoll, 6);

    session.resume();
    expect(controller.canChooseToken, isTrue);
    expect(controller.chooseToken(0), LudoMoveResult.accepted);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 0);
    controller.dispose();
  });

  test('publishes winner, home counts, and ordered standings', () {
    final options = MatchOptions.custom(
      mode: PlayMode.friend,
      participants: _mixedParticipants()
          .map(
            (participant) => MatchParticipant.human(
              displayName: participant.displayName,
              color: participant.color,
              token: participant.token,
            ),
          )
          .toList(),
    );
    final session = MatchSession(options: options)..start();
    final model = LudoModel.fromState(
      playerCount: 3,
      diceRoller: () => 1,
      tokenProgress: const [
        [56, 56, 56, 55],
        [56, 56, 56, 56],
        [40, 30, 20, 10],
      ],
      standings: const [1],
      currentPlayer: 0,
    );
    final controller = LudoController(
      playerCount: 3,
      participants: options.participants,
      model: model,
      movementStepDuration: Duration.zero,
      session: session,
    );
    addTearDown(session.dispose);

    controller.roll();
    controller.chooseToken(3);

    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 1);
    expect(session.scores, [4, 4, 0]);
    expect(session.standings, [1, 0, 2]);
    expect(session.resultDetails, contains('1. Bot 1'));
    controller.dispose();
  });

  test('rematch resets every token and clears prior turn state', () {
    final options = MatchOptions.friend();
    final session = MatchSession(options: options)..start();
    final controller = LudoController(
      playerCount: 2,
      participants: options.participants,
      diceRoller: () => 6,
      movementStepDuration: Duration.zero,
      session: session,
    );
    controller.roll();
    controller.chooseToken(0);
    expect(controller.model.progressFor(0, 0), 0);

    session.reportNonPointResult(
      winner: 0,
      scores: const [4, 0],
      standings: const [0, 1],
      details: 'Done',
    );
    session.start();

    expect(
      controller.model.tokenProgress.expand((tokens) => tokens),
      everyElement(LudoModel.boxProgress),
    );
    expect(controller.model.pendingRoll, isNull);
    expect(controller.model.standings, isEmpty);
    controller.dispose();
    session.dispose();
  });
}

List<MatchParticipant> _mixedParticipants() => [
  _human('You', ParticipantColor.mint, ParticipantToken.circle),
  _bot('Bot 1', ParticipantColor.coral, ParticipantToken.diamond),
  _bot('Bot 2', ParticipantColor.gold, ParticipantToken.triangle),
];

MatchParticipant _human(
  String name,
  ParticipantColor color,
  ParticipantToken token,
) => MatchParticipant.human(displayName: name, color: color, token: token);

MatchParticipant _bot(
  String name,
  ParticipantColor color,
  ParticipantToken token, {
  BotDifficulty difficulty = BotDifficulty.normal,
}) => MatchParticipant.bot(
  displayName: name,
  color: color,
  token: token,
  difficulty: difficulty,
);

class _RecordingBot extends LudoBot {
  BotDifficulty? observedDifficulty;
  List<int>? observedLegalTokens;

  @override
  int chooseToken(LudoModel model, BotDifficulty difficulty) {
    observedDifficulty = difficulty;
    observedLegalTokens = List.of(model.legalTokenIndexes);
    return model.legalTokenIndexes.first;
  }
}
