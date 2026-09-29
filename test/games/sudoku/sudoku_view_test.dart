import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/app/tap_tussle_theme.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/sudoku/sudoku_controller.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_progress_repository.dart';
import 'package:tap_tussle/games/sudoku/sudoku_view.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('supports touch number entry, notes, erase, and conflict state', (
    tester,
  ) async {
    final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 1);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = SudokuController(
      session: session,
      puzzle: puzzle,
      repository: SudokuProgressRepository(
        await SharedPreferences.getInstance(),
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _pumpBoard(tester, controller);
    final cell = puzzle.givens.indexOf(0);

    await tester.tap(find.byKey(ValueKey('sudoku-cell-$cell')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sudoku-notes')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sudoku-number-2')));
    await tester.pump();
    expect(controller.model.notes[cell], {2});
    expect(find.text('NOTES ON'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sudoku-notes')));
    final wrong = puzzle.solution[cell] == 1 ? 2 : 1;
    await tester.tap(find.byKey(ValueKey('sudoku-number-$wrong')));
    await tester.pump();
    expect(controller.model.incorrectCells, contains(cell));
    expect(find.text('1 MISTAKES'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('incorrect')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sudoku-erase')));
    await tester.pump();
    expect(controller.model.values[cell], 0);
    expect(controller.model.incorrectCells, isEmpty);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('renders 81 accessible cells and hides the puzzle when paused', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = SudokuController(
      session: session,
      puzzle: SudokuCatalog.puzzle(SudokuDifficulty.normal, 1),
      repository: SudokuProgressRepository(
        await SharedPreferences.getInstance(),
      ),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    await _pumpBoard(tester, controller);

    expect(find.byKey(const ValueKey('sudoku-board')), findsOneWidget);
    expect(find.byKey(const ValueKey('sudoku-cell-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('sudoku-cell-80')), findsOneWidget);

    session.pause();
    await tester.pump();
    expect(find.byKey(const ValueKey('sudoku-paused')), findsOneWidget);
    expect(find.byKey(const ValueKey('sudoku-board')), findsNothing);
    controller.dispose();
  });
}

Future<void> _pumpBoard(
  WidgetTester tester,
  SudokuController controller,
) async {
  tester.view.physicalSize = const Size(430, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTapTussleTheme(),
      home: Scaffold(body: SudokuBoard(controller: controller)),
    ),
  );
}
