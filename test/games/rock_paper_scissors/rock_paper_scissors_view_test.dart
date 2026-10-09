import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_controller.dart';
import 'package:tap_tussle/games/rock_paper_scissors/rock_paper_scissors_model.dart';
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
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('PLAYER 1 WINS!'), findsOneWidget);
    expect(find.text('ROCK'), findsOneWidget);
    expect(find.text('SCISSORS'), findsOneWidget);
    expect(find.text('+1 POINT'), findsOneWidget);
    expect(find.byKey(const ValueKey('rps-reveal-cool')), findsOneWidget);
    expect(find.byKey(const ValueKey('rps-reveal-warm')), findsOneWidget);
    expect(find.byKey(const ValueKey('rps-round-winner')), findsOneWidget);
    expect(
      find.bySemanticsLabel('Player 1 chose rock and won the round'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('rps-next-round')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('rps-reveal-card-cool'))),
      tester.getSize(find.byKey(const ValueKey('rps-reveal-card-warm'))),
    );
  });

  testWidgets('choice and reveal fit a compact phone with enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = RockPaperScissorsController(session: session);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: RockPaperScissorsBoard(
          controller: controller,
          playerLabels: const ['Player 1', 'Player 2'],
        ),
      ),
    );

    expect(find.byKey(const ValueKey('rps-choice-paper')), findsOneWidget);
    controller.selectChoice(RockPaperScissorsChoice.paper);
    controller.confirmHandoff();
    controller.selectChoice(RockPaperScissorsChoice.rock);
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('PLAYER 1 WINS!'), findsOneWidget);
    expect(find.byKey(const ValueKey('rps-round-winner')), findsOneWidget);
  });
}
