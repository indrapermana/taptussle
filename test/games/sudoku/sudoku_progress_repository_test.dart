import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';
import 'package:tap_tussle/games/sudoku/sudoku_progress_repository.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('round-trips board, notes, mistakes, hints, and elapsed time', () async {
    final repository = SudokuProgressRepository(
      await SharedPreferences.getInstance(),
    );
    final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 4);
    final model = SudokuModel(puzzle);
    final editable = puzzle.givens.indexOf(0);
    final otherEditable = puzzle.givens.indexOf(0, editable + 1);
    model.toggleNote(editable, 2);
    model.enter(otherEditable, _wrongValue(puzzle.solution[otherEditable]));
    model.revealHint();

    await repository.save(model: model, elapsed: const Duration(seconds: 37));
    final saved = repository.load(SudokuDifficulty.easy)!;
    final restored = saved.restoreModel();

    expect(saved.level, 4);
    expect(saved.elapsedMilliseconds, 37000);
    expect(restored.values, model.values);
    expect(restored.notes, model.notes);
    expect(restored.incorrectCells, model.incorrectCells);
    expect(restored.mistakes, 1);
    expect(restored.hintsUsed, 1);
  });

  test(
    'isolates difficulties and clears only the requested progress',
    () async {
      final repository = SudokuProgressRepository(
        await SharedPreferences.getInstance(),
      );
      final easy = SudokuModel(SudokuCatalog.puzzle(SudokuDifficulty.easy, 1));
      final hard = SudokuModel(SudokuCatalog.puzzle(SudokuDifficulty.hard, 2));
      await repository.save(model: easy, elapsed: Duration.zero);
      await repository.save(model: hard, elapsed: Duration.zero);

      await repository.clear(SudokuDifficulty.easy);

      expect(repository.load(SudokuDifficulty.easy), isNull);
      expect(repository.load(SudokuDifficulty.hard)?.level, 2);
    },
  );

  test('rejects malformed and puzzle-mismatched saved data', () async {
    SharedPreferences.setMockInitialValues({
      'sudoku.progress.easy':
          '{"version":1,"difficulty":"easy","level":1,"values":[1]}',
    });
    final repository = SudokuProgressRepository(
      await SharedPreferences.getInstance(),
    );

    expect(repository.load(SudokuDifficulty.easy), isNull);
  });

  test(
    'unlocks levels independently and never moves progress backward',
    () async {
      final repository = SudokuProgressRepository(
        await SharedPreferences.getInstance(),
      );

      expect(repository.unlockedLevel(SudokuDifficulty.easy), 1);
      await repository.unlockLevel(SudokuDifficulty.easy, 2);
      await repository.unlockLevel(SudokuDifficulty.easy, 1);

      expect(repository.unlockedLevel(SudokuDifficulty.easy), 2);
      expect(repository.unlockedLevel(SudokuDifficulty.normal), 1);
    },
  );
}

int _wrongValue(int solution) => solution == 1 ? 2 : 1;
