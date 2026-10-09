import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/memory_match/memory_match_assets.dart';
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
    expect(find.byKey(const ValueKey('memory-card-back-0')), findsOneWidget);
    final pair = controller.model.deck[0];
    final symbol = MemoryMatchAssets.symbols[pair];
    expect(
      find.bySemanticsLabel('Revealed ${symbol.name}, card 1'),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('memory-card-0')));
    await tester.pump();

    expect(find.bySemanticsLabel('Hidden card 1'), findsNothing);
    expect(
      find.bySemanticsLabel('Revealed ${symbol.name}, card 1'),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 170));
    final face = tester.widget<Image>(
      find.byKey(const ValueKey('memory-card-front-0')),
    );
    expect((face.image as AssetImage).assetName, symbol.path);
    expect(find.byKey(const ValueKey('memory-moves')), findsOneWidget);
    expect(find.text('MOVES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('solo preview has visible progress then yields to your turn', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(options: MatchOptions.solo());
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(8),
      openingPreviewDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(app(controller, const ['You']));
    session.start();
    await tester.pump();

    expect(find.text('MEMORIZE!'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('memory-preview-progress')),
      findsOneWidget,
    );

    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('YOUR TURN'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-preview-progress')), findsNothing);
  });

  testWidgets('friend mode shows scores and current player without preview', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(options: MatchOptions.friend());
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(9),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(app(controller, const ['Player 1', 'Player 2']));
    session.start();
    await tester.pump();

    expect(find.byKey(const ValueKey('memory-player-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-player-1')), findsOneWidget);
    expect(find.text('PLAYER 1 TURN'), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-preview-progress')), findsNothing);
    expect(
      find.bySemanticsLabel('Player 1, 0 pairs, current turn'),
      findsOneWidget,
    );
  });

  testWidgets('matched cards stay readable with a persistent completion mark', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.easy,
      random: Random(7),
      openingPreviewDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(app(controller, const ['You']));

    final first = 0;
    final second = controller.model.deck.indexOf(
      controller.model.deck[first],
      first + 1,
    );
    await tester.tap(find.byKey(ValueKey('memory-card-$first')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 330));
    await tester.tap(find.byKey(ValueKey('memory-card-$second')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 330));

    expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    expect(find.byKey(ValueKey('memory-card-front-$first')), findsOneWidget);
    final opacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.byKey(ValueKey('memory-card-$first')),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(opacity.opacity, .88);
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

  testWidgets('hard friend grid supports enlarged text on a compact phone', (
    tester,
  ) async {
    useCompactPhone(tester);
    final session = MatchSession(
      options: MatchOptions.friend(difficulty: BotDifficulty.hard),
    )..start();
    final controller = MemoryMatchController(
      session: session,
      difficulty: MemoryMatchDifficulty.hard,
      random: Random(12),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
        child: app(controller, const ['Player One', 'Player Two']),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('memory-player-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-player-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('memory-card-23')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
