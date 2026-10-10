import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/game_logo_assets.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/haptic_service.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/core/sound_service.dart';
import 'package:tap_tussle/features/match/match_screen.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';
import 'package:tap_tussle/games/mancala/mancala_view.dart';

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
  final game = gameCatalog.singleWhere((game) => game.id == 'mancala');

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

  test('catalog metadata enables two-player friend and bot setup', () {
    expect(game.artworkAsset, gameLogoAssets['mancala']);
    expect(game.supportedPlayerCounts, {PlayerCount.two});
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.bot);
    expect(game.matchLabel!(MatchOptions.friend()), 'MOST STONES');
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('seven moves'),
    );
  });

  testWidgets('filter, favourite, and bot difficulty setup open Mancala', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(TapTussleApp(settings: settings, games: [game]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-card-mancala')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-card-mancala')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('mancala'), isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('play-vs-bot')));
    await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
    await tester.pumpAndSettle();
    final slider = tester.getRect(
      find.byKey(const ValueKey('bot-difficulty-slider')),
    );
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('PLAY'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();

    expect(find.byType(MancalaView), findsOneWidget);
    expect(settings.preferencesFor('mancala').mode, PlayMode.bot);
    expect(settings.preferencesFor('mancala').difficulty, BotDifficulty.hard);
  });

  testWidgets('lifecycle, final scores, and alternating rematch integrate', (
    tester,
  ) async {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: MatchScreen(
          game: game,
          options: MatchOptions.friend(),
          startImmediately: true,
        ),
      ),
    );

    binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    var board = tester.widget<MancalaBoard>(find.byType(MancalaBoard));
    final controller = board.controller!;
    controller.model = MancalaModel.fromBoard(
      board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
    );
    expect(controller.tapPit(0, 5).name, 'accepted');
    await tester.pump(const Duration(milliseconds: 1070));
    await tester.pumpAndSettle();

    expect(find.text('Player 2 wins!'), findsOneWidget);
    expect(find.textContaining('most stones'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<MancalaBoard>(find.byType(MancalaBoard));
    expect(board.controller!.model.currentPlayer, 1);
    expect(board.controller!.model.stonesInStore(0), 0);
    expect(board.controller!.model.stonesInStore(1), 0);
  });

  testWidgets('sowing, capture, and extra turns use shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);

    Future<void> playPosition(MancalaModel model, int pit) async {
      final stonesToSow = model.stonesInPit(0, pit);
      final options = MatchOptions.friend();
      final session = MatchSession(options: options)..start();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTapTussleTheme(),
          home: MancalaView(
            key: ValueKey(model),
            session: session,
            options: options,
            initialModel: model,
          ),
        ),
      );
      await tester.tap(find.byKey(ValueKey('mancala-pit-0-$pit')));
      await tester.pump(Duration(milliseconds: stonesToSow * 420 + 901));
      await tester.pumpAndSettle();
    }

    await playPosition(MancalaModel(), 0);
    await playPosition(
      MancalaModel.fromBoard(
        board: const [1, 0, 1, 0, 0, 0, 0, 1, 0, 4, 0, 0, 0, 0],
      ),
      2,
    );
    await playPosition(MancalaModel(), 2);

    expect(
      sounds.played,
      containsAll([
        SoundEffect.collect,
        SoundEffect.boardCapture,
        SoundEffect.uiConfirm,
      ]),
    );
    expect(haptics.lightImpacts, 3);
    expect(haptics.mediumImpacts, 2);
  });
}
