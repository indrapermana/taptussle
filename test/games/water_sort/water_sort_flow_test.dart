import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_app.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/water_sort/water_sort_levels.dart';
import 'package:tap_tussle/games/water_sort/water_sort_progress_repository.dart';
import 'package:tap_tussle/games/water_sort/water_sort_solver.dart';
import 'package:tap_tussle/games/water_sort/water_sort_view.dart';

void main() {
  testWidgets(
    'solo filter, setup, favourite, lifecycle, record, and rematch integrate',
    (tester) async {
      tester.view.physicalSize = const Size(430, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final settings = AppSettings(preferences);
      addTearDown(settings.dispose);
      final game = gameCatalog.singleWhere(
        (game) => game.id == 'water-sort-puzzle',
      );

      await tester.pumpWidget(TapTussleApp(settings: settings, games: [game]));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('empty-game-catalog')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('player-filter-onePlayer')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('game-card-water-sort-puzzle')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Sort every color'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-record-bests')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
      await tester.pumpAndSettle();
      expect(settings.isFavourite(game.id), isTrue);

      await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
      await tester.tap(find.byKey(const ValueKey('play-solo')));
      await tester.pumpAndSettle();
      expect(find.text('Game difficulty'), findsOneWidget);
      expect(find.text('5–8 colors with longer solutions.'), findsOneWidget);
      await _setDifficulty(tester, BotDifficulty.easy);
      expect(find.text('3–5 colors and two helper tubes.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('start-bot-match')));
      await _pumpUntilFound(tester, find.byType(WaterSortBoard));

      final board = tester.widget<WaterSortBoard>(find.byType(WaterSortBoard));
      expect(board.controller.level.difficulty, WaterSortDifficulty.easy);
      expect(board.controller.level.number, 1);
      final first = board.controller.model.legalMoves.first;
      board.controller.tapTube(first.source);
      board.controller.tapTube(first.destination);
      await tester.pump(board.controller.animationDuration);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.text('Time out'), findsOneWidget);
      expect(board.controller.acceptsInput, isFalse);
      await board.controller.repository!.completed;
      expect(
        board.controller.repository!
            .loadActive(WaterSortDifficulty.easy)
            ?.restoreModel()
            .tubes,
        board.controller.model.tubes,
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.tap(find.byKey(const ValueKey('resume-match')));
      await tester.pump();
      expect(board.controller.acceptsInput, isTrue);

      final solution = const WaterSortSolver().solve(board.controller.model)!;
      for (final move in solution.moves) {
        board.controller.tapTube(move.source);
        board.controller.tapTube(move.destination);
        await tester.pump(board.controller.animationDuration);
      }
      await tester.pumpAndSettle();

      expect(find.text('Complete!'), findsOneWidget);
      expect(find.textContaining('Level 1 complete'), findsOneWidget);
      expect(find.byKey(const ValueKey('record-result-panel')), findsOneWidget);
      const recordKey = GameRecordKey(
        gameId: 'water-sort-puzzle',
        recordType: 'solo',
        variant: 'easy',
      );
      expect(settings.recordRepository.recordsFor(recordKey), hasLength(1));
      expect(
        WaterSortProgressRepository(
          preferences,
        ).unlockedLevel(WaterSortDifficulty.easy),
        2,
      );

      await tester.tap(find.byKey(const ValueKey('play-again')));
      await tester.pump();
      expect(board.controller.session!.phase, MatchPhase.playing);
      expect(board.controller.level.number, 2);
      expect(board.controller.model.moveCount, 0);
      expect(find.textContaining('LEVEL 2'), findsOneWidget);
      expect(settings.isFavourite(game.id), isTrue);
      expect(tester.takeException(), isNull);
    },
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
