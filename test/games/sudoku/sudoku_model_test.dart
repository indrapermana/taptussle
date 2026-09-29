import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/sudoku/sudoku_model.dart';

void main() {
  group('Sudoku catalog', () {
    for (final difficulty in SudokuDifficulty.values) {
      test('provides 60 deterministic unique $difficulty puzzles', () {
        final puzzles = SudokuCatalog.puzzles(difficulty);

        expect(puzzles, hasLength(60));
        expect(
          puzzles.map((puzzle) => puzzle.level),
          List.generate(60, (i) => i + 1),
        );
        expect(
          puzzles.map((puzzle) => puzzle.givens.join()).toSet(),
          hasLength(60),
        );
        expect(
          SudokuCatalog.puzzle(difficulty, 1).givens,
          puzzles.first.givens,
        );
      });

      test('proves every $difficulty level has exactly one solution', () {
        for (final puzzle in SudokuCatalog.puzzles(difficulty)) {
          expect(
            SudokuSolver.countSolutions(puzzle.givens, limit: 2),
            1,
            reason: '$difficulty level ${puzzle.level}',
          );
          expect(SudokuSolver.solve(puzzle.givens), puzzle.solution);
        }
      });
    }

    test('records the techniques used to rate each difficulty', () {
      expect(SudokuCatalog.puzzle(SudokuDifficulty.easy, 1).techniques, {
        SudokuTechnique.nakedSingle,
        SudokuTechnique.hiddenSingle,
      });
      expect(
        SudokuCatalog.puzzle(SudokuDifficulty.normal, 1).techniques,
        containsAll({
          SudokuTechnique.lockedCandidates,
          SudokuTechnique.nakedPair,
        }),
      );
      expect(
        SudokuCatalog.puzzle(SudokuDifficulty.hard, 1).techniques,
        contains(SudokuTechnique.advancedSearch),
      );
    });

    test('rejects an invalid level', () {
      expect(
        () => SudokuCatalog.puzzle(SudokuDifficulty.easy, 0),
        throwsRangeError,
      );
      expect(
        () => SudokuCatalog.puzzle(SudokuDifficulty.easy, 61),
        throwsRangeError,
      );
    });
  });

  group('SudokuSolver', () {
    test('calculates candidates from row, column, and box constraints', () {
      final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 1);

      expect(SudokuSolver.candidates(puzzle.givens, 2), {1, 2, 4});
      expect(SudokuSolver.candidates(puzzle.givens, 0), isEmpty);
    });

    test('detects duplicate and malformed boards', () {
      final puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 1);
      final duplicate = List<int>.of(puzzle.givens)..[2] = 5;

      expect(SudokuSolver.isValidBoard(duplicate), isFalse);
      expect(SudokuSolver.solve(duplicate), isNull);
      expect(SudokuSolver.countSolutions(duplicate), 0);
      expect(() => SudokuSolver.isValidBoard([1, 2]), throwsArgumentError);
    });
  });

  group('SudokuModel', () {
    late SudokuPuzzle puzzle;
    late SudokuModel model;

    setUp(() {
      puzzle = SudokuCatalog.puzzle(SudokuDifficulty.easy, 1);
      model = SudokuModel(puzzle);
    });

    test('starts from immutable givens and exposes candidates', () {
      expect(model.values, puzzle.givens);
      expect(model.isGiven(0), isTrue);
      expect(model.isGiven(2), isFalse);
      expect(model.candidatesFor(2), {1, 2, 4});
      expect(() => model.values[2] = 4, throwsUnsupportedError);
      expect(() => model.notes[2].add(4), throwsUnsupportedError);
    });

    test('protects givens and validates cell and number bounds', () {
      expect(model.enter(0, 5), SudokuEntryResult.givenCell);
      expect(model.enter(-1, 1), SudokuEntryResult.outOfBounds);
      expect(model.enter(81, 1), SudokuEntryResult.outOfBounds);
      expect(model.enter(2, 0), SudokuEntryResult.invalidValue);
      expect(model.enter(2, 10), SudokuEntryResult.invalidValue);
      expect(model.values, puzzle.givens);
    });

    test('stores incorrect entries, highlights them, and counts mistakes', () {
      expect(model.enter(2, 1), SudokuEntryResult.mistake);
      expect(model.values[2], 1);
      expect(model.incorrectCells, {2});
      expect(model.mistakes, 1);

      expect(model.enter(2, puzzle.solution[2]), SudokuEntryResult.accepted);
      expect(model.incorrectCells, isEmpty);
      expect(model.mistakes, 1);
    });

    test('supports unlimited note toggles and erase without mistakes', () {
      expect(model.toggleNote(2, 1), isTrue);
      expect(model.toggleNote(2, 4), isTrue);
      expect(model.notes[2], {1, 4});
      expect(model.toggleNote(2, 1), isTrue);
      expect(model.notes[2], {4});
      expect(model.erase(2), isTrue);
      expect(model.notes[2], isEmpty);
      expect(model.mistakes, 0);
      expect(model.erase(0), isFalse);
    });

    test('limits hints to three and marks the result assisted', () {
      for (var hint = 0; hint < SudokuModel.maximumHints; hint++) {
        expect(model.revealHint(), SudokuHintResult.revealed);
      }
      expect(model.hintsUsed, 3);
      expect(model.isAssisted, isTrue);
      expect(model.revealHint(), SudokuHintResult.limitReached);
    });

    test('detects completion and locks later entries', () {
      for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
        if (!model.isGiven(cell)) {
          expect(
            model.enter(cell, puzzle.solution[cell]),
            SudokuEntryResult.accepted,
          );
        }
      }

      expect(model.isComplete, isTrue);
      final editable = puzzle.givens.indexOf(0);
      expect(
        model.enter(editable, puzzle.solution[editable]),
        SudokuEntryResult.puzzleComplete,
      );
      expect(model.revealHint(), SudokuHintResult.puzzleComplete);
    });
  });
}
