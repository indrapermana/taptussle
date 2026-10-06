import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/games/solitaire/solitaire_model.dart';
import 'package:tap_tussle/games/solitaire/solitaire_progress_repository.dart';
import 'package:tap_tussle/games/solitaire/solitaire_view.dart';

void main() {
  testWidgets(
    'solo filter, favourite, restoration, lifecycle, record, and rematch integrate',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = AppSettings(preferences);
      addTearDown(settings.dispose);
      final progress = SolitaireProgressRepository(preferences);
      await progress.saveActive(
        difficulty: SolitaireDifficulty.easy,
        model: _almostCompleteModel(),
        elapsed: const Duration(seconds: 17),
      );
      await progress.completed;
      final game = gameCatalog.singleWhere((game) => game.id == 'solitaire');

      expect(game.artworkAsset, contains('solitaire.png'));
      expect(game.supportedModes, {PlayMode.solo});
      expect(game.supportedPlayerCounts, {PlayerCount.one});
      expect(game.recordDefinition?.recordType, 'win');

      await tester.pumpWidget(TapTussleApp(settings: settings, games: [game]));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('empty-game-catalog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('game-card-solitaire')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Build each foundation'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-record-bests')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
      await tester.pumpAndSettle();
      expect(settings.isFavourite(game.id), isTrue);

      await tester.drag(find.byType(ListView), const Offset(0, -320));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('play-solo')));
      await tester.pumpAndSettle();
      expect(find.text('Game difficulty'), findsOneWidget);
      expect(
        find.text('Draw one card and improve your time and moves.'),
        findsOneWidget,
      );
      await _setDifficulty(tester, BotDifficulty.easy);
      expect(find.text('Draw one card for a relaxed game.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await _pumpUntilFound(tester, find.byType(SolitaireBoard));

      final board = tester.widget<SolitaireBoard>(find.byType(SolitaireBoard));
      final controller = board.controller;
      expect(controller.difficulty, SolitaireDifficulty.easy);
      expect(controller.model.moveCount, 0);
      expect(
        controller.elapsed,
        greaterThanOrEqualTo(const Duration(seconds: 17)),
      );
      expect(controller.model.tableau[0].single.card.rank, SolitaireRank.king);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Time out'), findsOneWidget);
      expect(controller.acceptsInput, isFalse);
      await controller.repository!.completed;
      final saved = controller.repository!.loadActive(
        SolitaireDifficulty.easy,
      )!;
      expect(saved.restoreModel().tableau, controller.model.tableau);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('resume-match')));
      await tester.pump();
      expect(controller.acceptsInput, isTrue);

      await tester.tap(
        find.byKey(const ValueKey('solitaire-tableau-0-card-0')),
      );
      await tester.tap(
        find.byKey(const ValueKey('solitaire-foundation-spades')),
      );
      await tester.pump(controller.animationDuration);
      await tester.pumpAndSettle();

      expect(find.text('Complete!'), findsOneWidget);
      expect(find.textContaining('Won in 1 moves'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-result-panel')), findsOneWidget);
      const recordKey = GameRecordKey(
        gameId: 'solitaire',
        recordType: 'win',
        variant: 'easy',
      );
      expect(settings.recordRepository.recordsFor(recordKey), hasLength(1));
      expect(
        controller.repository!.loadActive(SolitaireDifficulty.easy),
        isNull,
      );

      await tester.tap(find.byKey(const ValueKey('play-again')));
      await tester.pump();
      expect(controller.session!.phase, MatchPhase.playing);
      expect(controller.model.isComplete, isFalse);
      expect(controller.model.moveCount, 0);
      expect(controller.elapsed, lessThan(const Duration(seconds: 2)));
      expect(settings.isFavourite(game.id), isTrue);
      expect(tester.takeException(), isNull);
    },
  );
}

SolitaireModel _almostCompleteModel() {
  final foundations = {
    for (final suit in SolitaireSuit.values)
      suit: [
        for (final rank in SolitaireRank.values)
          if (suit != SolitaireSuit.spades || rank != SolitaireRank.king)
            SolitaireCard(suit, rank),
      ],
  };
  return SolitaireModel.fromState(
    drawMode: SolitaireDrawMode.drawOne,
    tableau: List.generate(
      SolitaireModel.tableauPileCount,
      (index) => index == 0
          ? const [
              SolitaireTableauCard(
                SolitaireCard(SolitaireSuit.spades, SolitaireRank.king),
                isFaceUp: true,
              ),
            ]
          : <SolitaireTableauCard>[],
    ),
    foundations: foundations,
  );
}

Future<void> _setDifficulty(
  WidgetTester tester,
  BotDifficulty difficulty,
) async {
  final slider = tester.getRect(
    find.byKey(const ValueKey('bot-difficulty-slider')),
  );
  final fraction = .1 + (.8 * difficulty.index / 2);
  await tester.tapAt(
    Offset(slider.left + slider.width * fraction, slider.center.dy),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpUntilFound(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(finder, findsOneWidget);
}
