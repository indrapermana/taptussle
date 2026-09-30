import 'dart:ui';

import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_game.dart';

void main() {
  group('SlitherSnakesGame', () {
    test(
      'camera follows the player and coordinate conversion is reversible',
      () {
        final game = _game(playerHead: const SlitherPoint(500, 650));
        game.onGameResize(Vector2(320, 480));

        expect(game.cameraCenter, const SlitherPoint(500, 650));
        const world = SlitherPoint(560, 720);
        final screen = game.worldToScreen(world);

        expect(screen, const Offset(220, 310));
        expect(game.screenToWorld(screen), world);
      },
    );

    test('camera clamps at arena edges so space outside is never exposed', () {
      final game = _game(playerHead: const SlitherPoint(45, 55));

      game.onGameResize(Vector2(320, 480));

      expect(game.cameraCenter, const SlitherPoint(160, 240));
    });

    test('session pause freezes simulation and steering is safely cleared', () {
      final session = MatchSession(options: MatchOptions.solo())..start();
      final game = _game(
        playerHead: const SlitherPoint(500, 650),
        session: session,
      );
      game.onGameResize(Vector2(320, 480));
      game.steerFromScreen(const Offset(250, 380));
      expect(game.simulation.steeringTarget, isNotNull);

      game.update(.25);
      final runningTime = game.simulation.survivalTime;
      session.pause();
      game.clearSteering();
      game.update(1);

      expect(game.simulation.survivalTime, runningTime);
      expect(game.simulation.steeringTarget, isNull);
      session.resume();
      game.update(.25);
      expect(game.simulation.survivalTime, greaterThan(runningTime));
    });

    test('renders compact and large viewports without changing simulation', () {
      for (final viewport in [Vector2(280, 480), Vector2(1024, 768)]) {
        final game = _game(playerHead: const SlitherPoint(500, 650));
        game.onGameResize(viewport);
        final before = game.simulation.player.head;
        final recorder = PictureRecorder();
        final canvas = Canvas(recorder);

        game.render(canvas);
        recorder.endRecording();

        expect(game.simulation.player.head, before);
      }
    });
  });
}

SlitherSnakesGame _game({
  required SlitherPoint playerHead,
  MatchSession? session,
}) {
  final matchSession =
      session ?? (MatchSession(options: MatchOptions.solo())..start());
  const config = SlitherSimulationConfig(
    arenaWidth: 1000,
    arenaHeight: 1300,
    aiCount: 0,
    foodTarget: 0,
  );
  final player = SlitherSnake(
    id: 0,
    isPlayer: true,
    heading: 0,
    baseSpeed: config.playerBaseSpeed,
    targetSegmentCount: 3,
    segments: [
      playerHead,
      SlitherPoint(playerHead.x - 2.5, playerHead.y),
      SlitherPoint(playerHead.x - 5, playerHead.y),
    ],
  );
  return SlitherSnakesGame(
    session: matchSession,
    config: config,
    simulation: SlitherSimulation.custom(
      seed: 9,
      player: player,
      config: config,
    ),
  );
}
