import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/paddle_duel/paddle_duel_game.dart';

void main() {
  testWidgets(
    'home, settings, two touches, lifecycle pause, result and rematch',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());
      addTearDown(settings.dispose);
      await tester.pumpWidget(TapTussleApp(settings: settings));
      expect(find.text('Paddle Duel'), findsOneWidget);
      await tester.tap(find.byTooltip('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();
      expect(settings.winningScore, 5);
      // Dismiss the settings sheet using the modal barrier.
      await tester.tapAt(const Offset(10, 20));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Let’s play'), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Let’s play'));
      await tester.pumpAndSettle();
      expect(find.text('Take your sides'), findsOneWidget);
      expect(find.text('FIRST TO 5'), findsOneWidget);
      await tester.tap(find.text('Start match'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final game = tester
          .widget<GameWidget<PaddleDuelGame>>(
            find.byType(GameWidget<PaddleDuelGame>),
          )
          .game!;
      final court = tester.getRect(find.byKey(const ValueKey('paddle-court')));
      final bottom = await tester.startGesture(
        Offset(court.left + court.width * .25, court.top + court.height * .8),
        pointer: 1,
      );
      final top = await tester.startGesture(
        Offset(court.left + court.width * .75, court.top + court.height * .2),
        pointer: 2,
      );
      expect(game.model.paddles[0], closeTo(90, .1));
      expect(game.model.paddles[1], closeTo(270, .1));
      // Crossing the middle never transfers a finger to the other player.
      await bottom.moveTo(
        Offset(court.left + court.width * .4, court.top + court.height * .1),
      );
      expect(game.model.paddles[0], closeTo(144, .1));
      expect(game.model.paddles[1], closeTo(270, .1));
      await bottom.up();
      await top.up();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Time out'), findsOneWidget);
      final ballY = game.model.ballY;
      await tester.pump(const Duration(seconds: 1));
      expect(game.model.ballY, ballY);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text('Resume match'), findsOneWidget);
      await tester.tap(find.text('Resume match'));
      await tester.pump();
      // Score through the simulation to exercise the Flame -> shell bridge.
      for (var i = 0; i < 5; i++) {
        game.model
          ..serveRemaining = 0
          ..ballX = 20
          ..ballY = -6
          ..velocityY = -400;
        game.update(.02);
      }
      await tester.pump();
      expect(find.text('Player 1 wins!'), findsOneWidget);
      await tester.tap(find.text('Play again'));
      await tester.pump();
      expect(game.model.scores, [0, 0]);
      expect(game.model.winner, isNull);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Time out'), findsOneWidget);
      await tester.tap(find.text('Back to games'));
      await tester.pumpAndSettle();
      expect(find.text('Paddle Duel'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('pure Flutter game uses the same shell without Flame', (
    tester,
  ) async {
    late MatchSession session;
    final definition = MiniGame(
      id: 'test-flutter-game',
      title: 'Test game',
      subtitle: 'Test',
      instructions: 'Tap to win',
      icon: Icons.touch_app,
      build: (match, _) {
        session = match;
        return Center(
          child: TextButton(
            onPressed: () => match.reportScore(1, 0, winner: 0),
            child: const Text('Win round'),
          ),
        );
      },
    );
    await tester.pumpWidget(
      MaterialApp(home: MatchScreen(game: definition, winningScore: 7)),
    );
    await tester.tap(find.text('Start match'));
    await tester.pump();
    await tester.tap(find.text('Win round'));
    await tester.pump();
    expect(session.phase, MatchPhase.finished);
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.text('2 PLAYERS'), findsOneWidget);
  });

  testWidgets('small phone home and instructions do not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    await tester.pumpWidget(TapTussleApp(settings: settings));
    await tester.scrollUntilVisible(find.text('Let’s play'), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Let’s play'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
