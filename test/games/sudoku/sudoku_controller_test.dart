import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/sudoku/sudoku_controller.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('active timer stops while paused and continues after resume', (
    tester,
  ) async {
    var now = DateTime(2026);
    final session = MatchSession(options: MatchOptions.solo());
    final repository = SudokuProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final controller = SudokuController(
      session: session,
      puzzle: SudokuCatalog.puzzle(SudokuDifficulty.easy, 1),
      repository: repository,
      now: () => now,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    session.start();
    now = now.add(const Duration(seconds: 12));
    expect(controller.elapsed, const Duration(seconds: 12));
    session.pause();
    now = now.add(const Duration(seconds: 30));
    expect(controller.elapsed, const Duration(seconds: 12));

    session.resume();
    now = now.add(const Duration(seconds: 5));
    expect(controller.elapsed, const Duration(seconds: 17));
    controller.dispose();
  });

  testWidgets(
    'input is locked while paused and progress resumes from storage',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final repository = SudokuProgressRepository(preferences);
      final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 3);
      final session = MatchSession(options: MatchOptions.solo())..start();
      final controller = SudokuController(
        session: session,
        puzzle: puzzle,
        repository: repository,
      );
      final cell = puzzle.givens.indexOf(0);
      controller.selectCell(cell);
      controller.toggleNotesMode();
      controller.enterNumber(3);
      session.pause();
      expect(controller.isBoardVisible, isFalse);
      expect(controller.enterNumber(4), isNull);
      await repository.completed;
      final saved = repository.load(SudokuDifficulty.easy)!;
      controller.dispose();
      session.dispose();

      final resumedSession = MatchSession(options: MatchOptions.solo())
        ..start();
      final resumed = SudokuController(
        session: resumedSession,
        puzzle: puzzle,
        repository: repository,
        restoredProgress: saved,
      );
      addTearDown(resumed.dispose);
      addTearDown(resumedSession.dispose);

      expect(resumed.model.notes[cell], {3});
      expect(resumed.model.mistakes, 0);
      resumed.dispose();
    },
  );

  testWidgets('completion removes resumable progress', (tester) async {
    final repository = SudokuProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 1);
    final session = MatchSession(options: MatchOptions.solo())..start();
    final controller = SudokuController(
      session: session,
      puzzle: puzzle,
      repository: repository,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
      if (puzzle.givens[cell] != 0) continue;
      controller.selectCell(cell);
      controller.enterNumber(puzzle.solution[cell]);
    }
    await repository.completed;

    expect(controller.model.isComplete, isTrue);
    expect(repository.load(SudokuDifficulty.easy), isNull);
    expect(repository.unlockedLevel(SudokuDifficulty.easy), 2);
    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.completed);
    expect(session.recordMetrics, {
      'level': 1,
      'unassisted': 1,
      'mistakes': 0,
      'time': isA<int>(),
    });

    session.start();
    expect(controller.model.puzzle.level, 2);
    expect(controller.model.isComplete, isFalse);
    controller.dispose();
  });
}
