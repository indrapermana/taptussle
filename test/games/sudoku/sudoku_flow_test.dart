import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/app_settings.dart';
import 'package:tap_tussle/core/game_record_repository.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/features/game_setup/game_setup_screen.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_progress_repository.dart';
import 'package:tap_tussle/games/sudoku/sudoku_view.dart';

void main() {
  testWidgets('difficulty setup completes a level, records it, and advances', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final settings = AppSettings(preferences);
    addTearDown(settings.dispose);
    final game = gameCatalog.singleWhere((game) => game.id == 'sudoku');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildTapTussleTheme(),
        home: GameSetupScreen(game: game, settings: settings),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('favourite-toggle')));
    await tester.pumpAndSettle();
    expect(settings.isFavourite('sudoku'), isTrue);
    await tester.ensureVisible(find.byKey(const ValueKey('play-solo')));
    await tester.tap(find.byKey(const ValueKey('play-solo')));
    await tester.pumpAndSettle();

    expect(find.text('Game difficulty'), findsOneWidget);
    expect(find.text('Choose your board'), findsOneWidget);
    expect(
      find.text('Adds locked candidates and pair techniques.'),
      findsOneWidget,
    );
    await _setDifficulty(tester, BotDifficulty.hard);
    expect(
      find.text('Advanced deductions for experienced solvers.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('start-bot-match')));
    await tester.pumpAndSettle();

    final board = tester.widget<SudokuBoard>(find.byType(SudokuBoard));
    expect(board.controller.model.puzzle.difficulty, SudokuDifficulty.hard);
    expect(board.controller.model.puzzle.level, 1);
    final notedCell = board.controller.model.puzzle.givens.indexOf(0);
    board.controller.selectCell(notedCell);
    board.controller.toggleNotesMode();
    board.controller.enterNumber(2);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('Time out'), findsOneWidget);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.tap(find.byKey(const ValueKey('resume-match')));
    await tester.pump();
    expect(board.controller.model.notes[notedCell], {2});
    board.controller.toggleNotesMode();
    final puzzle = board.controller.model.puzzle;
    for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
      if (puzzle.givens[cell] != 0) continue;
      board.controller.selectCell(cell);
      board.controller.enterNumber(puzzle.solution[cell]);
    }
    await tester.pumpAndSettle();

    expect(find.text('Complete!'), findsOneWidget);
    expect(find.textContaining('Level 1 complete'), findsOneWidget);
    const key = GameRecordKey(
      gameId: 'sudoku',
      recordType: 'solo',
      variant: 'hard',
    );
    final records = settings.recordRepository.recordsFor(key);
    expect(records, hasLength(1));
    expect(records.single.metrics['level'], 1);
    expect(records.single.metrics['unassisted'], 1);
    expect(records.single.metrics['mistakes'], 0);
    expect(
      SudokuProgressRepository(
        preferences,
      ).unlockedLevel(SudokuDifficulty.hard),
      2,
    );

    await tester.tap(find.text('Play again'));
    await tester.pumpAndSettle();
    expect(board.controller.model.puzzle.level, 2);
    expect(find.textContaining('LEVEL 2'), findsOneWidget);
    expect(settings.isFavourite('sudoku'), isTrue);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _setDifficulty(
  WidgetTester tester,
  BotDifficulty difficulty,
) async {
  final slider = tester.getRect(find.byType(Slider));
  final fraction = .1 + (.8 * difficulty.index / 2);
  await tester.tapAt(
    Offset(slider.left + slider.width * fraction, slider.center.dy),
  );
  await tester.pumpAndSettle();
}
