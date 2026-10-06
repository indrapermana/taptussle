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
import 'package:tap_tussle/games/ludo/ludo_controller.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';
import 'package:tap_tussle/games/ludo/ludo_progress_repository.dart';
import 'package:tap_tussle/games/ludo/ludo_view.dart';

class _RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) {}
}

class _RecordingHapticPlayer implements HapticPlayer {
  var light = 0;
  var medium = 0;

  @override
  Future<void> paddleHit() async => medium++;

  @override
  Future<void> preview() async => light++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  final game = gameCatalog.singleWhere((game) => game.id == 'ludo');

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

  test('catalog exposes artwork, modes, counts, and bot difficulty', () {
    expect(game.artworkAsset, gameLogoAssets['ludo']);
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.supportedPlayerCounts, {
      PlayerCount.two,
      PlayerCount.three,
      PlayerCount.four,
    });
    expect(game.difficultyType, DifficultyType.bot);
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('safe squares'),
    );
  });

  testWidgets('appears in two-player and up-to-four-player filters', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: HomeScreen(settings: settings, games: [game]),
      ),
    );

    expect(find.byKey(const ValueKey('game-card-ludo')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('player-filter-upToFourPlayers')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-card-ludo')), findsOneWidget);
  });

  testWidgets('setup, favourite, lifecycle, results, and rematch integrate', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('ludo'), isTrue);
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('participant-count-3')));
    await tester.pumpAndSettle();

    final kind = find.byKey(const ValueKey('participant-kind-1'));
    await tester.ensureVisible(kind);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: kind, matching: find.text('Bot')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('participant-difficulty-1-normal')),
      findsOneWidget,
    );

    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await _pumpUntilFound(tester, find.byType(LudoBoard));

    var board = tester.widget<LudoBoard>(find.byType(LudoBoard));
    expect(board.options.participants, hasLength(3));
    expect(board.options.participants[1].isBot, isTrue);
    expect(board.controller.session?.phase, MatchPhase.playing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    expect(board.controller.canRoll, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();
    expect(board.controller.canRoll, isTrue);

    board.controller.session!.reportNonPointResult(
      winner: 0,
      scores: const [4, 3, 1],
      standings: const [0, 1, 2],
      details: '1. Player 1  •  2. Bot 2  •  3. Player 3',
    );
    await tester.pumpAndSettle();
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.textContaining('1. Player 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<LudoBoard>(find.byType(LudoBoard));
    expect(
      board.controller.model.tokenProgress.expand((tokens) => tokens),
      everyElement(-1),
    );
    expect(board.controller.session?.phase, MatchPhase.playing);
  });

  testWidgets('roll and movement use shared sound and haptic effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final options = MatchOptions.friend();
    final session = MatchSession(options: options)..start();
    final controller = LudoController(
      playerCount: 2,
      participants: options.participants,
      diceRoller: () => 6,
      movementStepDuration: Duration.zero,
      session: session,
    );
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: LudoView(
          session: session,
          options: options,
          controller: controller,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('ludo-roll')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ludo-token-0-0')));
    await tester.pump();

    expect(sounds.played, contains(SoundEffect.diceRoll));
    expect(sounds.played, contains(SoundEffect.pieceMove));
    expect(sounds.played, contains(SoundEffect.uiConfirm));
    expect(haptics.light, greaterThan(0));
    controller.dispose();
  });

  testWidgets('restores the saved board, turn, and pending token choice', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final repository = LudoProgressRepository(preferences);
    final options = MatchOptions.friend();
    final saved = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 2,
      tokenProgress: const [
        [12, 6, -1, -1],
        [20, -1, -1, -1],
      ],
      currentPlayer: 0,
      pendingRoll: 2,
    );
    await repository.save(options, saved);
    final session = MatchSession(options: options)..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: LudoView(
          session: session,
          options: options,
          repository: repository,
          diceRoller: () => 1,
          movementStepDuration: Duration.zero,
        ),
      ),
    );

    final board = tester.widget<LudoBoard>(find.byType(LudoBoard));
    expect(board.controller.model.tokenProgress, saved.tokenProgress);
    expect(board.controller.model.currentPlayer, 0);
    expect(board.controller.model.pendingRoll, 2);
    expect(board.controller.canChooseToken, isTrue);
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
