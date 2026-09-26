import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/memory_match/memory_match_controller.dart';
import 'package:tap_tussle/games/memory_match/memory_match_model.dart';
import 'package:tap_tussle/games/memory_match/memory_match_view.dart';

void useCompactPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget app(MemoryMatchController controller, List<String> labels) =>
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: MemoryMatchBoard(controller: controller, playerLabels: labels),
    );

void main() {
  testWidgets('hidden cards expose position but not their pair identity', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(5),
      openingPreviewDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(app(controller, const ['You']));

    expect(find.bySemanticsLabel('Hidden card 1'), findsOneWidget);
    final pair = controller.model.deck[0] + 1;
    expect(find.bySemanticsLabel('Revealed card $pair'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('memory-card-0')));
    await tester.pump();

    expect(find.bySemanticsLabel('Hidden card 1'), findsNothing);
    expect(find.bySemanticsLabel('Revealed card $pair'), findsOneWidget);
    expect(find.text('MOVES 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hard grid fits a compact phone without scrolling or overflow', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.hard,
      random: Random(6),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(app(controller, const ['You']));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('memory-card-grid')), findsOneWidget);
    final grid = tester.widget<GridView>(
      find.byKey(const ValueKey('memory-card-grid')),
    );
    expect(grid.physics, isA<NeverScrollableScrollPhysics>());
    expect(find.byKey(const ValueKey('memory-card-23')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
