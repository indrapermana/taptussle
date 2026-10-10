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
import 'package:tap_tussle/games/cangkulan/cangkulan_controller.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_model.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_progress_repository.dart';
import 'package:tap_tussle/games/cangkulan/cangkulan_view.dart';

class _RecordingSoundPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  Future<void> play(SoundEffect effect) async => played.add(effect);

  @override
  void setVolume(double value) {}
}

class _RecordingHapticPlayer implements HapticPlayer {
  var light = 0;

  @override
  Future<void> paddleHit() async {}

  @override
  Future<void> preview() async => light++;

  @override
  void setEnabled(bool value) {}
}

void main() {
  final game = gameCatalog.singleWhere((game) => game.id == 'cangkulan');

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
    expect(game.artworkAsset, gameLogoAssets['cangkulan']);
    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.supportedPlayerCounts, {
      PlayerCount.two,
      PlayerCount.three,
      PlayerCount.four,
    });
    expect(game.difficultyType, DifficultyType.bot);
    expect(
      game.difficultyDescription!(BotDifficulty.hard),
      contains('longest suit'),
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

    expect(find.byKey(const ValueKey('game-card-cangkulan')), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('player-filter-upToFourPlayers')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('game-card-cangkulan')), findsOneWidget);
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
    expect(settings.isFavourite('cangkulan'), isTrue);
    await tester.tap(find.byKey(const ValueKey('configure-participants')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('participant-count-3')));
    await tester.pumpAndSettle();
    final kind = find.byKey(const ValueKey('participant-kind-1'));
    await tester.ensureVisible(kind);
    await tester.tap(find.descendant(of: kind, matching: find.text('Bot')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('participant-difficulty-1-normal')),
      findsOneWidget,
    );

    final start = find.byKey(const ValueKey('start-configured-match'));
    await tester.scrollUntilVisible(start, 500);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await _pumpUntilFound(tester, find.byType(CangkulanBoard));
    var board = tester.widget<CangkulanBoard>(find.byType(CangkulanBoard));
    expect(board.playerLabels, hasLength(3));
    expect(board.controller.session.options.participants[1].isBot, isTrue);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    expect(board.controller.canRevealHand, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();

    board.controller.model = CangkulanModel.fromState(
      hands: [
        [_heart(7)],
        [_heart(8), _club(3)],
        [_heart(9), _club(4), _club(5)],
      ],
    );
    expect(board.controller.revealHand(), isTrue);
    expect(
      board.controller.playCard(_heart(7)),
      CangkulanInteractionResult.matchFinished,
    );
    await tester.pumpAndSettle();
    expect(find.text('Player 1 wins!'), findsOneWidget);
    expect(find.textContaining('1. Player 1 (empty)'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('play-again')));
    await tester.pump();
    board = tester.widget<CangkulanBoard>(find.byType(CangkulanBoard));
    expect(board.controller.model.hands, everyElement(hasLength(7)));
    expect(board.controller.phase, CangkulanViewPhase.handoff);
  });

  testWidgets('restores a saved match in the concealed state', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repository = CangkulanProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final options = MatchOptions.friend();
    final saved = CangkulanModel.fromState(
      hands: [
        [_club(2), _spade(2)],
        [_heart(8), _club(3)],
      ],
      drawPile: [_diamond(2)],
      currentPlayer: 1,
      trickLeader: 0,
      currentTrickTurns: [CangkulanTrickTurn(player: 0, playedCard: _heart(7))],
    );
    await repository.save(options, saved);
    final session = MatchSession(options: options)..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: CangkulanView(
          session: session,
          options: options,
          repository: repository,
        ),
      ),
    );
    await tester.pump();

    final board = tester.widget<CangkulanBoard>(find.byType(CangkulanBoard));
    expect(board.controller.model.currentPlayer, 1);
    expect(board.controller.model.trickPlays.single.card, _heart(7));
    expect(board.controller.phase, CangkulanViewPhase.handoff);
    expect(find.byKey(const ValueKey('cangkulan-hand-grid')), findsNothing);
  });

  testWidgets('shuffle, play, and cangkul use shared effects', (tester) async {
    final sounds = _RecordingSoundPlayer();
    final haptics = _RecordingHapticPlayer();
    SoundEffects.configure(sounds);
    HapticEffects.configure(haptics);
    final options = MatchOptions.friend();
    final session = MatchSession(options: options)..start();
    final controller = CangkulanController(
      session: session,
      initialModel: CangkulanModel.fromState(
        hands: [
          [_heart(7), _club(2)],
          [_spade(3), _club(3)],
        ],
        drawPile: [_diamond(4), _heart(9)],
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: CangkulanView(
          session: session,
          options: options,
          controller: controller,
        ),
      ),
    );

    controller.revealHand();
    controller.playCard(_heart(7));
    controller.revealHand();
    controller.cangkul();
    await tester.pump();

    expect(
      sounds.played,
      containsAll([
        SoundEffect.cardShuffle,
        SoundEffect.cardPlace,
        SoundEffect.cardDraw,
      ]),
    );
    expect(haptics.light, 2);
    await tester.pump(const Duration(milliseconds: 1200));
  });
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}

CangkulanCard _heart(int strength) =>
    CangkulanCard(CangkulanSuit.hearts, _rank(strength));
CangkulanCard _club(int strength) =>
    CangkulanCard(CangkulanSuit.clubs, _rank(strength));
CangkulanCard _spade(int strength) =>
    CangkulanCard(CangkulanSuit.spades, _rank(strength));
CangkulanCard _diamond(int strength) =>
    CangkulanCard(CangkulanSuit.diamonds, _rank(strength));
CangkulanRank _rank(int strength) =>
    CangkulanRank.values.singleWhere((rank) => rank.strength == strength);
