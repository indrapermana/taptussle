import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/game_logo_assets.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/features/home/home_screen.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_view.dart';

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
  Future<void> paddleHit() async => mediumImpacts++;

  @override
  Future<void> preview() async => lightImpacts++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  final game = gameCatalog.singleWhere(
    (game) => game.id == 'snakes-and-ladders',
  );

  Future<AppSettings> settingsFor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final settings = AppSettings(await SharedPreferences.getInstance());
    addTearDown(settings.dispose);
    return settings;
  }

  test('catalog metadata uses the supplied artwork and flexible modes', () {
    expect(game.artworkAsset, gameLogoAssets['snakes-and-ladders']);
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.supportedPlayerCounts, {
      PlayerCount.two,
      PlayerCount.three,
      PlayerCount.four,
    });
    expect(game.difficultyType, DifficultyType.none);
  });

  testWidgets('appears in both multiplayer filters', (tester) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: HomeScreen(settings: settings, games: [game]),
      ),
    );

    expect(
      find.byKey(const ValueKey('game-card-snakes-and-ladders')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('player-filter-upToFourPlayers')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('game-card-snakes-and-ladders')),
      findsOneWidget,
    );
    expect(settings.catalogPlayerFilter, CatalogPlayerFilter.upToFourPlayers);
  });

  testWidgets('setup, favourite, lifecycle, result, and rematch integrate', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    final settings = await settingsFor(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite(game.id), isTrue);
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('participant-count-4')));
    await tester.pumpAndSettle();

    final secondKind = find.byKey(const ValueKey('participant-kind-1'));
    await tester.ensureVisible(secondKind);
    await tester.tap(
      find.descendant(of: secondKind, matching: find.text('Bot')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Difficulty'), findsNothing);

    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pumpAndSettle();

    var board = tester.widget<SnakesAndLaddersBoard>(
      find.byType(SnakesAndLaddersBoard),
    );
    expect(board.options.participants, hasLength(4));
    expect(board.options.participants[1].isBot, isTrue);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    board.controller.session.reportNonPointResult(
      winner: 0,
      scores: const [64, 42, 31, 20],
      standings: const [0, 1, 2, 3],
      details:
          '1. Player 1  •  2. Bot 2  •  3. Player 3  •  4. Player 4  •  Another race?',
    );
    await tester.pumpAndSettle();
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.textContaining('1. Player 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<SnakesAndLaddersBoard>(
      find.byType(SnakesAndLaddersBoard),
    );
    expect(board.controller.displayPositions, [0, 0, 0, 0]);
    expect(board.controller.session.phase, MatchPhase.playing);
  });

  testWidgets('roll and completed movement use shared effects', (tester) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final options = MatchOptions.friend();
    final session = MatchSession(options: options)..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: SnakesAndLaddersView(session: session, options: options),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('snakes-roll')));
    await tester.pumpAndSettle();

    expect(sounds.played, contains(SoundEffect.diceRoll));
    expect(
      sounds.played,
      anyOf(
        contains(SoundEffect.pieceMove),
        contains(SoundEffect.levelUp),
        contains(SoundEffect.impactSoft),
      ),
    );
    expect(haptics.lightImpacts + haptics.mediumImpacts, greaterThan(0));
  });
}
