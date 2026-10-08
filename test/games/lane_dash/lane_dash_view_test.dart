import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_game.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_model.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_view.dart';

void main() {
  test('assigns friend and difficulty-specific bot cars', () {
    final friendSession = MatchSession(options: MatchOptions.friend());
    final friendGame = LaneDashGame(friendSession);
    expect(friendGame.carSpriteForPlayer(0), 'car_blue');
    expect(friendGame.carSpriteForPlayer(1), 'car_red');
    friendGame.stopMatch();
    friendSession.dispose();

    const expected = {
      BotDifficulty.easy: 'car_green',
      BotDifficulty.normal: 'car_yellow',
      BotDifficulty.hard: 'car_purple',
    };
    for (final entry in expected.entries) {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: entry.key),
      );
      final game = LaneDashGame(session);
      expect(game.carSpriteForPlayer(0), 'car_blue');
      expect(game.carSpriteForPlayer(1), entry.value);
      game.stopMatch();
      session.dispose();
    }
  });

  test('maps every obstacle kind to a production sprite', () {
    final session = MatchSession(options: MatchOptions.friend());
    final game = LaneDashGame(session);

    expect(
      LaneObstacleKind.values.map(game.obstacleSpriteForKind).toSet().length,
      LaneObstacleKind.values.length,
    );

    game.stopMatch();
    session.dispose();
  });

  test('all bot difficulties advance without changing race speed', () {
    for (final difficulty in BotDifficulty.values) {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: difficulty),
      )..start();
      final game = LaneDashGame(session)..resetMatch();
      game.model.countdown = 0;

      for (var frame = 0; frame < 60; frame += 1) {
        game.update(1 / 60);
      }

      expect(game.model.distance[0], greaterThan(0));
      expect(game.model.distance[1], closeTo(game.model.distance[0], .001));
      expect(session.phase, MatchPhase.playing);

      game.stopMatch();
      session.dispose();
    }
  });

  test('paused session freezes simulation and resumes safely', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final game = LaneDashGame(session)..resetMatch();
    game.model.countdown = 0;
    game.update(.25);
    final beforePause = List<double>.of(game.model.distance);

    session.pause();
    game.update(2);
    expect(game.model.distance, beforePause);

    session.resume();
    game.update(.25);
    expect(game.model.distance[0], greaterThan(beforePause[0]));
    expect(game.model.distance[1], greaterThan(beforePause[1]));

    game.stopMatch();
    session.dispose();
  });

  test('holds the finish presentation before reporting the result', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final game = LaneDashGame(session)..resetMatch();
    game.model.countdown = 0;
    game.model.distance[0] = LaneDashModel.finishDistance - 1;

    game.update(.1);

    expect(game.isPresentingFinish, isTrue);
    expect(session.phase, MatchPhase.playing);

    game.update(LaneDashGame.finishPresentationDuration - .01);
    expect(session.phase, MatchPhase.playing);

    game.update(.02);
    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 0);

    game.stopMatch();
    session.dispose();
  });

  testWidgets('both players move in the same screen direction as their swipe', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.dragFrom(const Offset(180, 450), const Offset(-80, 0));
    expect(game.model.lanes[0], 0, reason: 'Player 1 swiped left');
    game.model.lanes[0] = 1;
    await tester.dragFrom(const Offset(180, 450), const Offset(80, 0));
    expect(game.model.lanes[0], 2, reason: 'Player 1 swiped right');

    await tester.dragFrom(const Offset(180, 150), const Offset(-80, 0));
    expect(game.model.lanes[1], 0, reason: 'Player 2 swiped left');
    game.model.lanes[1] = 1;
    await tester.dragFrom(const Offset(180, 150), const Offset(80, 0));
    expect(game.model.lanes[1], 2, reason: 'Player 2 swiped right');
  });

  testWidgets('short and mostly vertical gestures do not change lanes', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(const Offset(180, 450), const Offset(20, 0));
    await tester.dragFrom(const Offset(180, 150), const Offset(30, 90));

    expect(game.model.lanes, [1, 1]);
  });

  testWidgets('simultaneous friend swipes keep independent pointer ownership', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bottom = await tester.startGesture(
      const Offset(180, 450),
      pointer: 1,
    );
    final top = await tester.startGesture(const Offset(180, 150), pointer: 2);
    await bottom.moveBy(const Offset(80, 0));
    await top.moveBy(const Offset(-80, 0));
    await bottom.up();
    await top.up();

    expect(game.model.lanes, [2, 0]);
  });

  testWidgets('exposes adjustable player zones and live race status', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.bySemanticsLabel('Player 1 track. Middle lane'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Player 2 track. Middle lane'),
      findsOneWidget,
    );
    final lowerZone = tester.widget<Semantics>(
      find.byKey(const ValueKey('lane-dash-player-zone-0')),
    );
    expect(lowerZone.properties.onIncrease, isNotNull);
    expect(lowerZone.properties.onDecrease, isNotNull);
    final status = tester.widget<Semantics>(
      find.byKey(const ValueKey('lane-dash-status')),
    );
    expect(status.properties.liveRegion, isTrue);
    expect(status.properties.label, 'Get ready');

    lowerZone.properties.onIncrease!();
    await tester.pump();
    expect(find.bySemanticsLabel('Player 1 track. Right lane'), findsOneWidget);

    game.accessibilityAnnouncement.value = 'Go';
    await tester.pump();
    expect(find.bySemanticsLabel('Go'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('fits compact enlarged-text layout without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.8)),
            child: Scaffold(
              body: LaneDashView(session: session, options: session.options),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byKey(const ValueKey('lane-dash-track')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared lifecycle pauses and resumes Lane Dash', (tester) async {
    final laneDash = gameCatalog.singleWhere((game) => game.id == 'lane-dash');
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MatchScreen(
          game: laneDash,
          options: MatchOptions.friend(),
          startImmediately: true,
        ),
      ),
    );
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();
    expect(find.byType(LaneDashView), findsOneWidget);
    expect(find.text('Time out'), findsNothing);
  });

  testWidgets('rematch resets race progress and presentation state', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LaneDashView(
            session: session,
            options: session.options,
            gameOverride: game,
          ),
        ),
      ),
    );
    game.model
      ..countdown = 0
      ..distance[0] = LaneDashModel.finishDistance - 1;
    game.update(.1);
    game.update(LaneDashGame.finishPresentationDuration + .1);
    expect(session.phase, MatchPhase.finished);

    session.start();
    await tester.pump();

    expect(game.model.distance, [0, 0]);
    expect(game.model.lanes, [1, 1]);
    expect(game.isPresentingFinish, isFalse);
  });
}
