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
import 'package:tap_tussle/games/chess/chess_model.dart';
import 'package:tap_tussle/games/chess/chess_view.dart';

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
  final game = gameCatalog.singleWhere((game) => game.id == 'chess');

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
    expect(game.artworkAsset, gameLogoAssets['chess']);
    expect(game.supportedPlayerCounts, {PlayerCount.two});
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.difficultyType, DifficultyType.bot);
    expect(game.matchLabel!(MatchOptions.friend()), 'CHECKMATE THE KING');
    expect(game.instructions, contains('Chess clocks are not used'));
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('three plies'),
    );
  });

  testWidgets('filter, favourite, and bot difficulty setup open Chess', (
    tester,
  ) async {
    final settings = await settingsFor(tester);
    await tester.pumpWidget(TapTussleApp(settings: settings, games: [game]));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('game-card-chess')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-card-chess')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('chess'), isTrue);

    await tester.ensureVisible(find.byKey(const ValueKey('play-vs-bot')));
    await tester.tap(find.byKey(const ValueKey('play-vs-bot')));
    await tester.pumpAndSettle();
    final slider = tester.getRect(
      find.byKey(const ValueKey('bot-difficulty-slider')),
    );
    await tester.tapAt(Offset(slider.right - 4, slider.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Play Hard'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();

    expect(find.byType(ChessView), findsOneWidget);
    expect(settings.preferencesFor('chess').mode, PlayMode.bot);
    expect(settings.preferencesFor('chess').difficulty, BotDifficulty.hard);
  });

  testWidgets('lifecycle, checkmate result, and rematch integrate', (
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

    var board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    final controller = board.controller!;
    var position = ChessModel();
    position = _play(position, 'f2', 'f3');
    position = _play(position, 'e7', 'e5');
    position = _play(position, 'g2', 'g4');
    controller.model = position;
    controller.tapSquare(_sq('d8'));
    controller.tapSquare(_sq('h4'));
    await tester.pumpAndSettle();

    expect(find.text('Player 2 wins!'), findsOneWidget);
    expect(find.textContaining('wins by checkmate'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<ChessBoard>(find.byType(ChessBoard));
    expect(board.controller!.model.history, isEmpty);
    expect(board.controller!.model.sideToMove, ChessColor.white);
    expect(
      board.controller!.model.board.whereType<ChessPiece>(),
      hasLength(32),
    );
  });

  testWidgets('moves, captures, and promotions use shared effects', (
    tester,
  ) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);

    Future<void> pumpPosition(ChessModel model) async {
      final options = MatchOptions.friend();
      final session = MatchSession(options: options)..start();
      addTearDown(session.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTapTussleTheme(),
          home: ChessView(
            key: ValueKey(model),
            session: session,
            options: options,
            initialModel: model,
          ),
        ),
      );
    }

    await pumpPosition(ChessModel());
    await _tapMove(tester, 'e2', 'e4');

    await pumpPosition(
      ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('a1'): _white(ChessPieceType.rook),
          _sq('e8'): _black(ChessPieceType.king),
          _sq('a8'): _black(ChessPieceType.knight),
        },
      ),
    );
    await _tapMove(tester, 'a1', 'a8');

    await pumpPosition(
      ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('a7'): _white(ChessPieceType.pawn),
          _sq('e8'): _black(ChessPieceType.king),
        },
      ),
    );
    await _tapMove(tester, 'a7', 'a8');
    await tester.tap(find.byKey(const ValueKey('chess-promote-queen')));
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

  testWidgets('match host fits compact phone and tablet sizes', (tester) async {
    for (final size in const [Size(320, 568), Size(1024, 1366)]) {
      await tester.binding.setSurfaceSize(size);
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
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Failed at $size');
    }
    await tester.binding.setSurfaceSize(null);
  });
}

Future<void> _tapMove(WidgetTester tester, String from, String to) async {
  await tester.tap(find.byKey(ValueKey('chess-square-${_sq(from)}')));
  await tester.pump();
  await tester.tap(find.byKey(ValueKey('chess-square-${_sq(to)}')));
  await tester.pump();
}

ChessModel _play(ChessModel model, String from, String to) =>
    model.play(ChessMove(from: _sq(from), to: _sq(to))).model;
int _sq(String value) => ChessModel.parseSquare(value);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
