import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_controller.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_view.dart';

void main() {
  testWidgets('renders a readable board and current turn for four players', (
    tester,
  ) async {
    final options = MatchOptions.custom(
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
    final session = MatchSession(options: options)..start();
    final controller = SnakesAndLaddersController(
      session: session,
      diceRoller: () => 2,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: Scaffold(
          body: SnakesAndLaddersBoard(controller: controller, options: options),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('snakes-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('snakes-square-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('snakes-square-64')), findsOneWidget);
    expect(find.text('ONE’S TURN'), findsOneWidget);
    expect(find.text('One: START'), findsOneWidget);
    expect(find.text('Four: START'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('snakes-roll')));
    await tester.pumpAndSettle();

    expect(find.text('TWO’S TURN'), findsOneWidget);
    expect(find.text('ROLL 2'), findsOneWidget);
    expect(find.text('One: 2'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Square 2, One')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
