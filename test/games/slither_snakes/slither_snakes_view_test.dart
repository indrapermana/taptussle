import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_game.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_view.dart';

void main() {
  testWidgets('only a lower-half drag steers and release clears the target', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    await _pumpView(tester, session);
    final game = _gameFrom(tester);

    final upper = await tester.startGesture(const Offset(160, 120));
    await upper.moveTo(const Offset(230, 150));
    expect(game.simulation.steeringTarget, isNull);
    await upper.up();

    final lower = await tester.startGesture(const Offset(160, 390));
    expect(game.simulation.steeringTarget, isNotNull);
    final firstTarget = game.simulation.steeringTarget;
    await lower.moveTo(const Offset(240, 410));
    expect(game.simulation.steeringTarget, isNot(firstTarget));
    await lower.up();
    expect(game.simulation.steeringTarget, isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('pausing during a drag clears input and freezes the run', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    await _pumpView(tester, session);
    final game = _gameFrom(tester);
    final drag = await tester.startGesture(const Offset(180, 410));
    expect(game.simulation.steeringTarget, isNotNull);

    session.pause();
    final pausedAt = game.simulation.survivalTime;
    game.update(1);

    expect(game.simulation.steeringTarget, isNull);
    expect(game.simulation.survivalTime, pausedAt);
    await drag.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'compact layout exposes the steering affordance without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(280, 480);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final session = MatchSession(options: MatchOptions.solo())..start();

      await _pumpView(tester, session);

      expect(find.text('DRAG HERE TO STEER'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _pumpView(WidgetTester tester, MatchSession session) async {
  const config = SlitherSimulationConfig(aiCount: 0, foodTarget: 0);
  final simulation = SlitherSimulation.custom(
    seed: 10,
    player: SlitherSnake(
      id: 0,
      isPlayer: true,
      heading: 0,
      baseSpeed: config.playerBaseSpeed,
      segments: const [SlitherPoint(1200, 900), SlitherPoint(1197.5, 900)],
      targetSegmentCount: 2,
    ),
    config: config,
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SlitherSnakesView(
          session: session,
          options: session.options,
          initialSimulation: simulation,
        ),
      ),
    ),
  );
  await tester.pump();
}

SlitherSnakesGame _gameFrom(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is GameWidget && widget.game is SlitherSnakesGame,
  );
  final widget = tester.widget<GameWidget>(finder);
  return widget.game as SlitherSnakesGame;
}
