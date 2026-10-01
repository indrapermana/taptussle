import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/ludo/ludo_controller.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';
import 'package:tap_tussle/games/ludo/ludo_view.dart';

void main() {
  testWidgets('renders four players and requires a legal token choice', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 820));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final options = _fourPlayers();
    final controller = LudoController(
      playerCount: 4,
      diceRoller: () => 6,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, options));

    expect(find.byKey(const ValueKey('ludo-board')), findsOneWidget);
    expect(find.text('ONE’S TURN'), findsOneWidget);
    expect(find.text('One 0/4'), findsOneWidget);
    expect(find.text('Four 0/4'), findsOneWidget);
    expect(
      find.bySemanticsLabel('One, token 1, in the starting box'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('ludo-roll')));
    await tester.pump();

    expect(find.text('ROLL 6 • CHOOSE A TOKEN'), findsOneWidget);
    expect(find.byKey(const ValueKey('ludo-die')), findsOneWidget);
    expect(
      tester.getSemantics(find.byKey(const ValueKey('ludo-die'))).label,
      contains('Last roll 6'),
    );
    expect(
      find.bySemanticsLabel(
        'One, token 1, in the starting box, available to move',
      ),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ludo-roll')))
          .onPressed,
      isNull,
    );

    await tester.tap(find.byKey(const ValueKey('ludo-token-0-0')));
    await tester.pump();

    expect(find.text('ONE’S TURN'), findsOneWidget);
    expect(
      find.bySemanticsLabel('One, token 1, on track space 1'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows ordered final standings when the last move wins', (
    tester,
  ) async {
    final options = MatchOptions.friend();
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 1,
      tokenProgress: const [
        [57, 57, 57, 56],
        [40, 30, 20, 10],
      ],
    );
    final controller = LudoController(
      playerCount: 2,
      model: model,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, options));
    await tester.tap(find.byKey(const ValueKey('ludo-roll')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ludo-token-0-3')));
    await tester.pump();

    expect(find.text('FINAL STANDINGS'), findsOneWidget);
    expect(find.text('1ST Player 1'), findsOneWidget);
    expect(find.text('2ND Player 2'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Player 1, token 4, at final home'),
      findsOneWidget,
    );
  });

  testWidgets('fits the board and controls on a compact phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final options = MatchOptions.friend();
    final controller = LudoController(
      playerCount: 2,
      diceRoller: () => 2,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, options));

    expect(find.byKey(const ValueKey('ludo-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('ludo-roll')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows separate locked bot roll and move thinking states', (
    tester,
  ) async {
    final options = MatchOptions.custom(
      mode: PlayMode.bot,
      participants: [
        const MatchParticipant.human(
          displayName: 'You',
          color: ParticipantColor.mint,
          token: ParticipantToken.circle,
        ),
        const MatchParticipant.bot(
          displayName: 'Rival',
          color: ParticipantColor.coral,
          token: ParticipantToken.diamond,
          difficulty: BotDifficulty.normal,
        ),
      ],
    );
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 6,
      tokenProgress: const [
        [-1, -1, -1, -1],
        [-1, -1, -1, -1],
      ],
      currentPlayer: 1,
    );
    final controller = LudoController(
      playerCount: 2,
      participants: options.participants,
      model: model,
      movementStepDuration: Duration.zero,
      botRollDelay: const Duration(milliseconds: 100),
      botMoveDelay: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(_app(controller, options));

    expect(find.text('RIVAL IS GETTING READY…'), findsOneWidget);
    expect(find.text('WAIT'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('ludo-roll')))
          .onPressed,
      isNull,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('RIVAL IS CHOOSING…'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        'Rival, token 1, in the starting box, available to move',
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(
      model.tokenProgress[1].where((progress) => progress == 0),
      hasLength(1),
    );
    controller.dispose();
  });
}

Widget _app(LudoController controller, MatchOptions options) => MaterialApp(
  theme: buildTapTussleTheme(),
  home: Scaffold(
    body: LudoBoard(controller: controller, options: options),
  ),
);

MatchOptions _fourPlayers() => MatchOptions.custom(
  mode: PlayMode.friend,
  participants: const [
    MatchParticipant.human(
      displayName: 'One',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    MatchParticipant.human(
      displayName: 'Two',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
    ),
    MatchParticipant.human(
      displayName: 'Three',
      color: ParticipantColor.gold,
      token: ParticipantToken.triangle,
    ),
    MatchParticipant.human(
      displayName: 'Four',
      color: ParticipantColor.violet,
      token: ParticipantToken.star,
    ),
  ],
);
