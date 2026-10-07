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
import 'package:tap_tussle/games/checkers/checkers_model.dart';
import 'package:tap_tussle/games/checkers/checkers_view.dart';

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
  final game = gameCatalog.singleWhere((game) => game.id == 'checkers');

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
    expect(game.artworkAsset, gameLogoAssets['checkers']);
    expect(game.supportedPlayerCounts, {PlayerCount.two});
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.bot);
    expect(game.matchLabel!(MatchOptions.friend()), 'AMERICAN CHECKERS');
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('four turns'),
    );
  });

  testWidgets('filter, favourite, and bot difficulty setup open Checkers', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(TapTussleApp(settings: settings, games: [game]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-card-checkers')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-card-checkers')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('checkers'), isTrue);

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

    expect(find.byType(CheckersView), findsOneWidget);
    expect(settings.preferencesFor('checkers').mode, PlayMode.bot);
    expect(settings.preferencesFor('checkers').difficulty, BotDifficulty.hard);
  });

  testWidgets('lifecycle, result, and starter-alternating rematch integrate', (
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

    var board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    final controller = board.controller!;
    controller.model = CheckersModel.fromBoard(
      board: {
        40: const CheckersPiece(player: 0),
        33: const CheckersPiece(player: 1),
      },
    );
    controller.tapSquare(40);
    controller.tapSquare(26);
    await tester.pumpAndSettle();

    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.textContaining('no legal move'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<CheckersBoard>(find.byType(CheckersBoard));
    expect(board.controller!.model.currentPlayer, 1);
    expect(board.controller!.model.pieceCount(0), 12);
    expect(board.controller!.model.pieceCount(1), 12);
  });

  testWidgets('moves, captures, and promotions use shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);

    Future<void> pumpPosition(CheckersModel model) async {
      final options = MatchOptions.friend();
      final session = MatchSession(options: options)..start();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTapTussleTheme(),
          home: CheckersView(
            key: ValueKey(model),
            session: session,
            options: options,
            initialModel: model,
          ),
        ),
      );
    }

    await pumpPosition(CheckersModel());
    await tester.tap(find.byKey(const ValueKey('checkers-square-40')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkers-square-33')));
    await tester.pump();

    await pumpPosition(
      CheckersModel.fromBoard(
        board: {
          40: const CheckersPiece(player: 0),
          33: const CheckersPiece(player: 1),
          1: const CheckersPiece(player: 1),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('checkers-square-40')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkers-square-26')));
    await tester.pump();

    await pumpPosition(
      CheckersModel.fromBoard(
        board: {
          10: const CheckersPiece(player: 0),
          62: const CheckersPiece(player: 1),
        },
      ),
    );
    await tester.tap(find.byKey(const ValueKey('checkers-square-10')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('checkers-square-1')));
    await tester.pump();

    expect(
      sounds.played,
      containsAll([
        SoundEffect.pieceMove,
        SoundEffect.boardCapture,
        SoundEffect.levelUp,
      ]),
    );
    expect(haptics.lightImpacts, 1);
    expect(haptics.mediumImpacts, 2);
  });
}
