import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_game.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_view.dart';

void main() {
  testWidgets('selected difficulty configures pressure and survives rematch', (
    tester,
  ) async {
    for (final difficulty in BotDifficulty.values) {
      final options = MatchOptions.solo(difficulty: difficulty);
      final session = MatchSession(options: options)..start();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SlitherSnakesView(
              key: ValueKey(difficulty),
              session: session,
              options: options,
            ),
          ),
        ),
      );
      await tester.pump();
      final game = _gameFrom(tester);
      final aiCount = switch (difficulty) {
        BotDifficulty.easy => 10,
        BotDifficulty.normal => 18,
        BotDifficulty.hard => 26,
      };
      final foodCount = switch (difficulty) {
        BotDifficulty.easy => 280,
        BotDifficulty.normal => 220,
        BotDifficulty.hard => 180,
      };

      expect(game.simulation.opponents, hasLength(aiCount));
      expect(game.simulation.food, hasLength(foodCount));
      session.reportCompletion();
      session.start();
      expect(game.simulation.opponents, hasLength(aiCount));
      expect(game.simulation.food, hasLength(foodCount));
    }

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the whole arena steers and release clears the target', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    await _pumpView(tester, session);
    final game = _gameFrom(tester);

    final upper = await tester.startGesture(const Offset(160, 120));
    expect(game.simulation.steeringTarget, isNotNull);
    await upper.moveTo(const Offset(230, 150));
    expect(game.simulation.steeringTarget, isNotNull);
    await upper.up();
    expect(game.simulation.steeringTarget, isNull);

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

      await _pumpView(tester, session, textScaler: const TextScaler.linear(2));

      expect(find.text('DRAG ANYWHERE TO STEER'), findsOneWidget);
      expect(find.bySemanticsLabel('Slither snake arena'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('slither-steering-instruction')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}

Future<void> _pumpView(
  WidgetTester tester,
  MatchSession session, {
  TextScaler textScaler = TextScaler.noScaling,
}) async {
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
      home: MediaQuery(
        data: MediaQueryData(textScaler: textScaler),
        child: Scaffold(
          body: SlitherSnakesView(
            session: session,
            options: session.options,
            initialSimulation: simulation,
          ),
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
