import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/games/slither_snakes/slither_challenge_profile.dart';
import 'package:tap_tussle/games/slither_snakes/slither_simulation.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_game.dart';
import 'package:tap_tussle/games/slither_snakes/slither_snakes_view.dart';

class _RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) {}
}

class _RecordingHapticPlayer implements HapticPlayer {
  var lightImpacts = 0;
  var mediumImpacts = 0;

  @override
  Future<void> preview() async => lightImpacts++;

  @override
  Future<void> paddleHit() async => mediumImpacts++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  final gameMetadata = gameCatalog.singleWhere(
    (game) => game.id == 'slither-style-snakes',
  );

  testWidgets(
    'solo filter, favourite, lifecycle, result record, and rematch integrate',
    (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final settings = AppSettings(await SharedPreferences.getInstance());
      addTearDown(settings.dispose);
      await tester.pumpWidget(
        TapTussleApp(settings: settings, games: [gameMetadata]),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('empty-game-catalog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('game-card-slither-style-snakes')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
      await tester.pumpAndSettle();
      expect(settings.isFavourite(gameMetadata.id), isTrue);
      expect(find.byKey(const ValueKey('game-record-bests')), findsOneWidget);

      await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
      await tester.tap(find.byKey(const ValueKey('play-solo')));
      await tester.pumpAndSettle();
      final slider = tester.getRect(
        find.byKey(const ValueKey('bot-difficulty-slider')),
      );
      await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await _pumpUntilFound(tester, find.byType(SlitherSnakesView));

      expect(find.byType(SlitherSnakesView), findsOneWidget);
      final game = _gameFrom(tester);
      expect(game.config.aiCount, 6);

      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(game.session.phase, MatchPhase.paused);
      expect(find.text('Time out'), findsOneWidget);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('resume-match')));
      await tester.pump();
      expect(game.session.phase, MatchPhase.playing);

      game.simulation.player
        ..age = 3
        ..segments[0] = SlitherPoint(
          game.config.arenaWidth - game.config.snakeRadius + 1,
          game.simulation.player.head.y,
        );
      game.update(SlitherSimulation.fixedStep);
      await _pumpUntilFound(tester, find.text('Complete!'));

      expect(find.text('Complete!'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-result-panel')), findsOneWidget);
      expect(
        settings.recordRepository.recordsFor(
          const GameRecordKey(
            gameId: 'slither-style-snakes',
            recordType: 'solo',
            variant: 'hard',
          ),
        ),
        hasLength(1),
      );

      await tester.tap(find.byKey(const ValueKey('play-again')));
      await tester.pump();
      expect(game.session.phase, MatchPhase.playing);
      expect(game.simulation.score, 0);
      expect(game.simulation.isGameOver, isFalse);
      expect(game.simulation.opponents, hasLength(6));
    },
  );

  test('food and crashes use the dedicated shared effects', () {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final session = MatchSession(options: MatchOptions.solo())..start();
    const config = SlitherSimulationConfig(
      arenaWidth: 500,
      arenaHeight: 500,
      aiCount: 0,
      foodTarget: 0,
    );
    final simulation = SlitherSimulation.custom(
      seed: 4,
      player: SlitherSnake(
        id: 0,
        isPlayer: true,
        heading: 0,
        baseSpeed: config.playerBaseSpeed,
        segments: const [SlitherPoint(100, 100)],
        targetSegmentCount: 1,
        age: 3,
      ),
      food: const [SlitherFood(id: 0, position: SlitherPoint(103, 100))],
      config: config,
    );
    final game = SlitherSnakesGame(
      session: session,
      config: config,
      simulation: simulation,
    )..onGameResize(Vector2(320, 480));

    game.update(SlitherSimulation.fixedStep);
    simulation.player.segments[0] = const SlitherPoint(495, 100);
    game.update(SlitherSimulation.fixedStep);

    expect(
      sounds.played,
      containsAll([SoundEffect.snakeEat, SoundEffect.snakeCrash]),
    );
    expect(haptics.lightImpacts, 1);
    expect(haptics.mediumImpacts, 1);
  });

  test('all profiles remain within a bounded host simulation budget', () {
    final stopwatch = Stopwatch()..start();
    var seed = 100;
    for (final profile in [
      SlitherChallengeProfile.easy,
      SlitherChallengeProfile.normal,
      SlitherChallengeProfile.hard,
    ]) {
      var simulation = SlitherSimulation(seed: seed++, config: profile.config);
      for (var frame = 0; frame < 3600; frame++) {
        if (simulation.isGameOver) {
          simulation = SlitherSimulation(seed: seed++, config: profile.config);
        }
        simulation.update(SlitherSimulation.fixedStep);
      }
    }
    stopwatch.stop();

    expect(stopwatch.elapsed, lessThan(const Duration(seconds: 10)));
  });
}

SlitherSnakesGame _gameFrom(WidgetTester tester) {
  final finder = find.byWidgetPredicate(
    (widget) => widget is GameWidget && widget.game is SlitherSnakesGame,
  );
  return tester.widget<GameWidget>(finder).game as SlitherSnakesGame;
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
