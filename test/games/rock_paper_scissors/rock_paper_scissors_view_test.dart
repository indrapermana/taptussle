import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_controller.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_view.dart';

void main() {
  testWidgets('friend handoff conceals both choices until round reveal', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = RockPaperScissorsController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: RockPaperScissorsBoard(
          controller: controller,
          playerLabels: const ['Player 1', 'Player 2'],
        ),
      ),
    );

    expect(find.text('PLAYER 1, CHOOSE'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('rps-choice-rock')));
    await tester.pump();

    expect(find.text('CHOICE LOCKED'), findsOneWidget);
    expect(find.text('ROCK'), findsNothing);
    expect(find.text('SCISSORS'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('rps-handoff-ready')));
    await tester.pump();
    expect(find.text('PLAYER 2, CHOOSE'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('rps-choice-scissors')));
    await tester.pump();
    expect(find.text('PLAYER 1 WINS!'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);
    expect(find.byKey(const ValueKey('rps-next-round')), findsOneWidget);
  });
}
