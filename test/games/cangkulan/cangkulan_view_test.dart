import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_controller.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_view.dart';

void main() {
  testWidgets('handoff does not build either participant hand', (tester) async {
    final fixture = _fixture([
      [_heart(7), _club(2)],
      [_heart(8), _club(3)],
    ]);
    addTearDown(fixture.dispose);
    await _pumpBoard(tester, fixture.controller, const Size(390, 700));

    expect(find.byKey(const ValueKey('cangkulan-handoff')), findsOneWidget);
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsNothing);
    expect(find.bySemanticsLabel('7 of hearts, playable'), findsNothing);
    expect(find.bySemanticsLabel('8 of hearts, playable'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cangkulan-reveal-hand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsOneWidget);
    expect(find.bySemanticsLabel('7 of hearts, playable'), findsOneWidget);
    expect(find.bySemanticsLabel('8 of hearts, playable'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cangkulan-hand-0')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cangkulan-handoff')), findsOneWidget);
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsNothing);
    expect(find.text('Player 1 played a card.'), findsOneWidget);
  });

  testWidgets(
    'follow-suit cards remain enabled while other suits are disabled',
    (tester) async {
      final model = CangkulanModel.fromState(
        hands: [
          [_heart(8), _club(2)],
          [_heart(9), _club(3)],
        ],
        currentPlayer: 0,
        trickLeader: 1,
        currentTrickTurns: [
          CangkulanTrickTurn(player: 1, playedCard: _heart(7)),
        ],
      );
      final fixture = _fixtureFrom(model);
      addTearDown(fixture.dispose);
      await _pumpBoard(tester, fixture.controller, const Size(430, 760));
      await tester.tap(find.byKey(const ValueKey('cangkulan-reveal-hand')));
      await tester.pumpAndSettle();

      expect(find.textContaining('FOLLOW HEARTS'), findsOneWidget);
      expect(find.bySemanticsLabel('8 of hearts, playable'), findsOneWidget);
      expect(
        find.bySemanticsLabel('2 of clubs, must follow suit'),
        findsOneWidget,
      );
      final legal = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('cangkulan-hand-0')),
          matching: find.byType(FilledButton),
        ),
      );
      final illegal = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('cangkulan-hand-1')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(legal.onPressed, isNotNull);
      expect(illegal.onPressed, isNull);
    },
  );

  testWidgets('cangkul is explicit and only safe summary survives handoff', (
    tester,
  ) async {
    final model = CangkulanModel.fromState(
      hands: [
        [_club(2), _club(4)],
        [_heart(10), _club(3)],
        [_heart(8), _club(5)],
      ],
      drawPile: [_spade(2), _heart(9)],
      currentPlayer: 0,
      trickLeader: 2,
      currentTrickTurns: [CangkulanTrickTurn(player: 2, playedCard: _heart(7))],
    );
    final fixture = _fixtureFrom(model);
    addTearDown(fixture.dispose);
    await _pumpBoard(tester, fixture.controller, const Size(430, 760));
    await tester.tap(find.byKey(const ValueKey('cangkulan-reveal-hand')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cangkulan-cangkul')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Draw pile, 2 cards')), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('cangkulan-cangkul')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsNothing);
    expect(find.text('Player 1 drew 2 cards.'), findsOneWidget);
    expect(find.textContaining('9♥'), findsNothing);
    expect(find.textContaining('2♠'), findsNothing);
  });

  testWidgets('card table fits compact phone and tablet layouts', (
    tester,
  ) async {
    final fixture = _fixture([
      CangkulanModel.standardDeck().take(13).toList(),
      CangkulanModel.standardDeck().skip(13).take(7).toList(),
      CangkulanModel.standardDeck().skip(20).take(7).toList(),
      CangkulanModel.standardDeck().skip(27).take(7).toList(),
    ]);
    addTearDown(fixture.dispose);

    await _pumpBoard(tester, fixture.controller, const Size(350, 600));
    await tester.tap(find.byKey(const ValueKey('cangkulan-reveal-hand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpBoard(tester, fixture.controller, const Size(1024, 768));
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('bot turn stays concealed and shows thinking feedback', (
    tester,
  ) async {
    final options = MatchOptions.bot(difficulty: BotDifficulty.normal);
    final session = MatchSession(options: options)..start();
    final controller = CangkulanController(
      session: session,
      botThinkDelay: const Duration(seconds: 2),
      initialModel: CangkulanModel.fromState(
        hands: [
          [_heart(7), _club(2)],
          [_heart(8), _club(3)],
        ],
        currentPlayer: 1,
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _pumpBoard(tester, controller, const Size(390, 700));

    expect(
      find.byKey(const ValueKey('cangkulan-bot-thinking')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('cangkulan-reveal-hand')), findsNothing);
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsNothing);
    expect(find.bySemanticsLabel('Bot thinking'), findsOneWidget);
    session.pause();
  });
}

class _Fixture {
  const _Fixture(this.session, this.controller);
  final MatchSession session;
  final CangkulanController controller;

  void dispose() {
    controller.dispose();
    session.dispose();
  }
}

_Fixture _fixture(List<List<CangkulanCard>> hands) =>
    _fixtureFrom(CangkulanModel.fromState(hands: hands));

_Fixture _fixtureFrom(CangkulanModel model) {
  final options = _friendOptions(model.participantCount);
  final session = MatchSession(options: options)..start();
  return _Fixture(
    session,
    CangkulanController(session: session, initialModel: model),
  );
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

Future<void> _pumpBoard(
  WidgetTester tester,
  CangkulanController controller,
  Size size,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: Scaffold(
        body: CangkulanBoard(
          controller: controller,
          playerLabels: [
            for (
              var index = 0;
              index < controller.model.participantCount;
              index++
            )
              'Player ${index + 1}',
          ],
        ),
      ),
    ),
  );
  await tester.pump();
}

CangkulanCard _heart(int strength) =>
    CangkulanCard(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    CangkulanCard(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    CangkulanCard(CangkulanSuit.spades, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
