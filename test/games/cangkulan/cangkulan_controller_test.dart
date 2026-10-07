import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_controller.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';

void main() {
  test(
    'friend turns require a concealed handoff before every visible hand',
    () {
      final session = MatchSession(options: _friendOptions(3));
      final controller = CangkulanController(
        session: session,
        initialModel: _model([
          [_heart(7), _club(2)],
          [_heart(8), _club(3)],
          [_heart(9), _club(4)],
        ]),
      );
      addTearDown(controller.dispose);
      addTearDown(session.dispose);

      session.start();
      expect(controller.phase, CangkulanViewPhase.handoff);
      expect(controller.visibleHand, isEmpty);
      expect(controller.legalActions, isEmpty);
      expect(
        controller.playCard(_heart(7)),
        CangkulanInteractionResult.unavailable,
      );

      expect(controller.revealHand(), isTrue);
      expect(controller.visibleHand, [_heart(7), _club(2)]);
      expect(
        controller.playCard(_heart(7)),
        CangkulanInteractionResult.accepted,
      );
      expect(controller.phase, CangkulanViewPhase.handoff);
      expect(controller.activePlayer, 1);
      expect(controller.visibleHand, isEmpty);
      expect(controller.lastAction!.playedCard, _heart(7));
    },
  );

  test('pause and resume keep the active hand concealed', () {
    final session = MatchSession(options: _friendOptions(2));
    final controller = CangkulanController(
      session: session,
      initialModel: _model([
        [_heart(7), _club(2)],
        [_heart(8), _club(3)],
      ]),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();
    controller.revealHand();

    session.pause();
    expect(controller.phase, CangkulanViewPhase.handoff);
    expect(controller.visibleHand, isEmpty);
    session.resume();
    expect(controller.phase, CangkulanViewPhase.handoff);
    expect(controller.visibleHand, isEmpty);
    expect(controller.revealHand(), isTrue);
  });

  test('illegal selections are rejected without exposing the next hand', () {
    final session = MatchSession(options: _friendOptions(2))..start();
    final controller = CangkulanController(
      session: session,
      initialModel: CangkulanModel.fromState(
        hands: [
          [_club(2), _heart(8)],
          [_club(3), _spade(2)],
        ],
        currentPlayer: 0,
        trickLeader: 1,
        currentTrickTurns: [
          CangkulanTrickTurn(player: 1, playedCard: _heart(7)),
        ],
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    controller.revealHand();

    expect(
      controller.playCard(_club(2)),
      CangkulanInteractionResult.illegalAction,
    );
    expect(controller.phase, CangkulanViewPhase.turn);
    expect(controller.activePlayer, 0);
  });

  test('empty hand publishes winner and rematch creates a concealed deal', () {
    final session = MatchSession(options: _friendOptions(2));
    final controller = CangkulanController(
      session: session,
      initialModel: _model([
        [_heart(7)],
        [_heart(8), _club(3)],
      ]),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    session.start();
    controller.revealHand();

    expect(
      controller.playCard(_heart(7)),
      CangkulanInteractionResult.matchFinished,
    );
    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.winner, 0);
    expect(session.resultDetails, contains('1. Player 1 (empty)'));
    expect(session.standings, [0, 1]);
    expect(session.scores, [1, 0]);

    session.start();
    expect(controller.model.isFinished, isFalse);
    expect(controller.model.hands, everyElement(hasLength(7)));
    expect(controller.phase, CangkulanViewPhase.handoff);
    expect(controller.visibleHand, isEmpty);
  });

  testWidgets('mixed bots act after a visible delay and chain to a human', (
    tester,
  ) async {
    final session = MatchSession(options: _mixedOptions())..start();
    final controller = CangkulanController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 100),
      initialModel: CangkulanModel.fromState(
        hands: [
          [_club(2), _heart(2)],
          [_heart(8), _club(3)],
          [_heart(10), _club(4)],
          [_heart(11), _club(5)],
        ],
        currentPlayer: 1,
        trickLeader: 0,
        currentTrickTurns: [
          CangkulanTrickTurn(player: 0, playedCard: _heart(7)),
        ],
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.isBotTurn, isTrue);
    expect(controller.isBotThinking, isTrue);
    expect(controller.canRevealHand, isFalse);
    expect(controller.visibleHand, isEmpty);
    await tester.pump(const Duration(milliseconds: 99));
    expect(controller.activePlayer, 1);

    await tester.pump(const Duration(milliseconds: 1));
    expect(controller.activePlayer, 2);
    expect(controller.isBotThinking, isTrue);
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.activePlayer, 3);
    expect(controller.isBotTurn, isFalse);
    expect(controller.phase, CangkulanViewPhase.handoff);
    expect(controller.canRevealHand, isTrue);
    expect(controller.model.trickPlays.map((play) => play.player), [0, 1, 2]);
  });

  testWidgets('pause cancels a bot turn and resume schedules it again', (
    tester,
  ) async {
    final session = MatchSession(options: _mixedOptions())..start();
    final controller = CangkulanController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 100),
      initialModel: CangkulanModel.fromState(
        hands: [
          [_heart(2), _club(2)],
          [_heart(8), _club(3)],
          [_heart(10), _club(4)],
          [_heart(11), _club(5)],
        ],
        currentPlayer: 1,
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.pause();
    expect(controller.isBotThinking, isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.activePlayer, 1);

    session.resume();
    expect(controller.isBotThinking, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.activePlayer, 2);
    session.pause();
  });

  testWidgets('rematch cancels the old bot decision and resets to human', (
    tester,
  ) async {
    final session = MatchSession(options: _mixedOptions())..start();
    final controller = CangkulanController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 100),
      initialModel: CangkulanModel.fromState(
        hands: [
          [_heart(2), _club(2)],
          [_heart(8), _club(3)],
          [_heart(10), _club(4)],
          [_heart(11), _club(5)],
        ],
        currentPlayer: 1,
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.isBotThinking, isTrue);
    session.reportNonPointResult(winner: 0, details: 'Test round complete.');
    session.start();
    expect(controller.activePlayer, 0);
    expect(controller.isBotThinking, isFalse);
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.activePlayer, 0);
  });

  testWidgets('dispose cancels a pending bot decision', (tester) async {
    final session = MatchSession(options: _mixedOptions())..start();
    final controller = CangkulanController(
      session: session,
      botThinkDelay: const Duration(milliseconds: 100),
      initialModel: CangkulanModel.fromState(
        hands: [
          [_heart(2), _club(2)],
          [_heart(8), _club(3)],
          [_heart(10), _club(4)],
          [_heart(11), _club(5)],
        ],
        currentPlayer: 1,
      ),
    );
    addTearDown(session.dispose);
    final before = controller.model;

    controller.dispose();
    await tester.pump(const Duration(milliseconds: 150));
    expect(controller.model, same(before));
  });
}

MatchOptions _friendOptions(int count) => MatchOptions.custom(
  mode: PlayMode.friend,
  participants: [
    for (var index = 0; index < count; index++)
      MatchParticipant.human(
        displayName: 'Player ${index + 1}',
        color: ParticipantColor.values[index],
        token: ParticipantToken.values[index],
      ),
  ],
);

MatchOptions _mixedOptions() => MatchOptions.custom(
  mode: PlayMode.bot,
  participants: const [
    MatchParticipant.human(
      displayName: 'You',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    MatchParticipant.bot(
      displayName: 'Easy Bot',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
      difficulty: BotDifficulty.easy,
    ),
    MatchParticipant.bot(
      displayName: 'Hard Bot',
      color: ParticipantColor.gold,
      token: ParticipantToken.triangle,
      difficulty: BotDifficulty.hard,
    ),
    MatchParticipant.human(
      displayName: 'Player 2',
      color: ParticipantColor.violet,
      token: ParticipantToken.star,
    ),
  ],
);

CangkulanModel _model(List<List<CangkulanCard>> hands) =>
    CangkulanModel.fromState(hands: hands);

CangkulanCard _heart(int strength) =>
    CangkulanCard(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    CangkulanCard(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    CangkulanCard(CangkulanSuit.spades, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
