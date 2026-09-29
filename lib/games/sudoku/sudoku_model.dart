enum SudokuDifficulty { easy, normal, hard }

enum SudokuTechnique {
  nakedSingle,
  hiddenSingle,
  lockedCandidates,
  nakedPair,
  advancedSearch,
}

enum SudokuEntryResult {
  accepted,
  mistake,
  givenCell,
  outOfBounds,
  invalidValue,
  puzzleComplete,
}

enum SudokuHintResult { revealed, limitReached, puzzleComplete, outOfBounds }

class SudokuPuzzle {
  SudokuPuzzle({
    required this.difficulty,
    required this.level,
    required List<int> givens,
    required List<int> solution,
    required Set<SudokuTechnique> techniques,
  }) : givens = List.unmodifiable(givens),
       solution = List.unmodifiable(solution),
       techniques = Set.unmodifiable(techniques) {
    if (level < 1 || level > SudokuCatalog.levelsPerDifficulty) {
      throw ArgumentError.value(level, 'level', 'Must be from 1 to 60');
    }
    SudokuSolver.validateBoardShape(this.givens, allowEmpty: true);
    SudokuSolver.validateBoardShape(this.solution, allowEmpty: false);
    if (!SudokuSolver.isValidBoard(this.givens) ||
        !SudokuSolver.isValidBoard(this.solution)) {
      throw ArgumentError('Puzzle boards must obey Sudoku constraints');
    }
    for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
      if (this.givens[cell] != 0 && this.givens[cell] != this.solution[cell]) {
        throw ArgumentError('Every given must agree with the solution');
      }
    }
  }

  final SudokuDifficulty difficulty;
  final int level;
  final List<int> givens;
  final List<int> solution;
  final Set<SudokuTechnique> techniques;

  int get clueCount => givens.where((value) => value != 0).length;
}

class SudokuCatalog {
  SudokuCatalog._();

  static const int levelsPerDifficulty = 60;

  static final Map<SudokuDifficulty, List<SudokuPuzzle>> _puzzles = {
    for (final difficulty in SudokuDifficulty.values)
      difficulty: _buildDifficulty(difficulty),
  };

  static SudokuPuzzle puzzle(SudokuDifficulty difficulty, int level) {
    if (level < 1 || level > levelsPerDifficulty) {
      throw RangeError.range(level, 1, levelsPerDifficulty, 'level');
    }
    return _puzzles[difficulty]![level - 1];
  }

  static List<SudokuPuzzle> puzzles(SudokuDifficulty difficulty) =>
      _puzzles[difficulty]!;

  static List<SudokuPuzzle> _buildDifficulty(SudokuDifficulty difficulty) {
    final template = _templates[difficulty]!;
    final templateSolution = SudokuSolver.solve(template);
    if (templateSolution == null ||
        SudokuSolver.countSolutions(template, limit: 2) != 1) {
      throw StateError('$difficulty Sudoku template is not uniquely solvable');
    }

    final puzzles = <SudokuPuzzle>[];
    final signatures = <String>{};
    for (var transform = 0; puzzles.length < levelsPerDifficulty; transform++) {
      final givens = _transform(template, transform);
      final signature = givens.join();
      if (!signatures.add(signature)) continue;
      final solution = _transform(templateSolution, transform);
      final puzzle = SudokuPuzzle(
        difficulty: difficulty,
        level: puzzles.length + 1,
        givens: givens,
        solution: solution,
        techniques: _techniques[difficulty]!,
      );
      // These transformations only relabel digits and move complete row bands
      // or column stacks, so the template's proven uniqueness is preserved.
      puzzles.add(puzzle);
    }
    return List.unmodifiable(puzzles);
  }

  static List<int> _transform(List<int> board, int transform) {
    final digitShift = transform % 9;
    final bandShift = (transform ~/ 9) % 3;
    final stackShift = (transform ~/ 27) % 3;
    final transformed = List.filled(SudokuSolver.cellCount, 0);

    for (var row = 0; row < 9; row++) {
      for (var column = 0; column < 9; column++) {
        final sourceRow = ((row ~/ 3 + bandShift) % 3) * 3 + row % 3;
        final sourceColumn = ((column ~/ 3 + stackShift) % 3) * 3 + column % 3;
        final value = board[sourceRow * 9 + sourceColumn];
        transformed[row * 9 + column] = value == 0
            ? 0
            : ((value - 1 + digitShift) % 9) + 1;
      }
    }
    return transformed;
  }

  static final Map<SudokuDifficulty, List<int>> _templates = {
    SudokuDifficulty.easy: _parse(
      '530070000600195000098000060800060003400803001700020006'
      '060000280000419005000080079',
    ),
    SudokuDifficulty.normal: _parse(
      '000260701680070090190004500820100040004602900050003028'
      '009300074040050036703018000',
    ),
    SudokuDifficulty.hard: _parse(
      '100007090030020008009600500005300900010080002600004000'
      '300000010040000007007000300',
    ),
  };

  static const Map<SudokuDifficulty, Set<SudokuTechnique>> _techniques = {
    SudokuDifficulty.easy: {
      SudokuTechnique.nakedSingle,
      SudokuTechnique.hiddenSingle,
    },
    SudokuDifficulty.normal: {
      SudokuTechnique.nakedSingle,
      SudokuTechnique.hiddenSingle,
      SudokuTechnique.lockedCandidates,
      SudokuTechnique.nakedPair,
    },
    SudokuDifficulty.hard: {
      SudokuTechnique.nakedSingle,
      SudokuTechnique.hiddenSingle,
      SudokuTechnique.lockedCandidates,
      SudokuTechnique.nakedPair,
      SudokuTechnique.advancedSearch,
    },
  };

  static List<int> _parse(String encoded) => [
    for (final codeUnit in encoded.codeUnits) codeUnit - 48,
  ];
}

class SudokuSolver {
  SudokuSolver._();

  static const int boardSize = 9;
  static const int cellCount = 81;

  static void validateBoardShape(List<int> board, {required bool allowEmpty}) {
    if (board.length != cellCount) {
      throw ArgumentError.value(board.length, 'board', 'Must contain 81 cells');
    }
    final minimum = allowEmpty ? 0 : 1;
    if (board.any((value) => value < minimum || value > 9)) {
      throw ArgumentError('Board values must be from $minimum to 9');
    }
  }

  static bool isValidBoard(List<int> board) {
    validateBoardShape(board, allowEmpty: true);
    for (var index = 0; index < cellCount; index++) {
      final value = board[index];
      if (value == 0) continue;
      final copy = List<int>.of(board)..[index] = 0;
      if (!candidates(copy, index).contains(value)) return false;
    }
    return true;
  }

  static Set<int> candidates(List<int> board, int cell) {
    validateBoardShape(board, allowEmpty: true);
    if (cell < 0 || cell >= cellCount) {
      throw RangeError.range(cell, 0, cellCount - 1, 'cell');
    }
    if (board[cell] != 0) return const {};

    final used = <int>{};
    final row = cell ~/ boardSize;
    final column = cell % boardSize;
    for (var offset = 0; offset < boardSize; offset++) {
      used.add(board[row * boardSize + offset]);
      used.add(board[offset * boardSize + column]);
    }
    final boxRow = (row ~/ 3) * 3;
    final boxColumn = (column ~/ 3) * 3;
    for (var rowOffset = 0; rowOffset < 3; rowOffset++) {
      for (var columnOffset = 0; columnOffset < 3; columnOffset++) {
        used.add(board[(boxRow + rowOffset) * 9 + boxColumn + columnOffset]);
      }
    }
    return {
      for (var value = 1; value <= 9; value++)
        if (!used.contains(value)) value,
    };
  }

  static List<int>? solve(List<int> board) {
    validateBoardShape(board, allowEmpty: true);
    if (!isValidBoard(board)) return null;
    final working = List<int>.of(board);
    return _solve(working) ? List.unmodifiable(working) : null;
  }

  static int countSolutions(List<int> board, {int limit = 2}) {
    validateBoardShape(board, allowEmpty: true);
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    if (!isValidBoard(board)) return 0;
    return _count(List<int>.of(board), limit);
  }

  static bool _solve(List<int> board) {
    final next = _nextCell(board);
    if (next == null) return true;
    if (next.$2.isEmpty) return false;
    for (final value in next.$2) {
      board[next.$1] = value;
      if (_solve(board)) return true;
    }
    board[next.$1] = 0;
    return false;
  }

  static int _count(List<int> board, int remaining) {
    final next = _nextCell(board);
    if (next == null) return 1;
    if (next.$2.isEmpty) return 0;
    var count = 0;
    for (final value in next.$2) {
      board[next.$1] = value;
      count += _count(board, remaining - count);
      if (count >= remaining) break;
    }
    board[next.$1] = 0;
    return count;
  }

  static (int, Set<int>)? _nextCell(List<int> board) {
    (int, Set<int>)? best;
    for (var cell = 0; cell < cellCount; cell++) {
      if (board[cell] != 0) continue;
      final options = candidates(board, cell);
      if (best == null || options.length < best.$2.length) {
        best = (cell, options);
        if (options.length <= 1) break;
      }
    }
    return best;
  }
}

class SudokuModel {
  SudokuModel(this.puzzle)
    : _values = List.of(puzzle.givens),
      _notes = List.generate(SudokuSolver.cellCount, (_) => <int>{}),
      _incorrectCells = <int>{};

  SudokuModel.restore(
    this.puzzle, {
    required List<int> values,
    required List<Set<int>> notes,
    required Set<int> incorrectCells,
    required this.mistakes,
    required this.hintsUsed,
  }) : _values = List.of(values),
       _notes = notes.map(Set<int>.of).toList(),
       _incorrectCells = Set.of(incorrectCells) {
    SudokuSolver.validateBoardShape(_values, allowEmpty: true);
    if (_notes.length != SudokuSolver.cellCount ||
        _notes.any(
          (cellNotes) => cellNotes.any((value) => value < 1 || value > 9),
        ) ||
        mistakes < 0 ||
        hintsUsed < 0 ||
        hintsUsed > maximumHints ||
        _incorrectCells.any(
          (cell) => cell < 0 || cell >= SudokuSolver.cellCount,
        )) {
      throw ArgumentError('Invalid saved Sudoku state');
    }
    for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
      final given = puzzle.givens[cell];
      final shouldBeIncorrect =
          given == 0 &&
          _values[cell] != 0 &&
          _values[cell] != puzzle.solution[cell];
      if ((given != 0 && _values[cell] != given) ||
          (_values[cell] != 0 && _notes[cell].isNotEmpty) ||
          _incorrectCells.contains(cell) != shouldBeIncorrect) {
        throw ArgumentError('Saved Sudoku state does not match its puzzle');
      }
    }
  }

  static const int maximumHints = 3;

  final SudokuPuzzle puzzle;
  final List<int> _values;
  final List<Set<int>> _notes;
  final Set<int> _incorrectCells;

  List<int> get values => List.unmodifiable(_values);
  List<Set<int>> get notes =>
      List.unmodifiable(_notes.map((notes) => Set<int>.unmodifiable(notes)));
  Set<int> get incorrectCells => Set.unmodifiable(_incorrectCells);
  int mistakes = 0;
  int hintsUsed = 0;
  bool get isAssisted => hintsUsed > 0;
  bool get isComplete => _values.asMap().entries.every(
    (entry) => entry.value == puzzle.solution[entry.key],
  );

  bool isGiven(int cell) {
    _checkCell(cell);
    return puzzle.givens[cell] != 0;
  }

  Set<int> candidatesFor(int cell) => SudokuSolver.candidates(_values, cell);

  SudokuEntryResult enter(int cell, int value) {
    if (cell < 0 || cell >= SudokuSolver.cellCount) {
      return SudokuEntryResult.outOfBounds;
    }
    if (value < 1 || value > 9) return SudokuEntryResult.invalidValue;
    if (isComplete) return SudokuEntryResult.puzzleComplete;
    if (isGiven(cell)) return SudokuEntryResult.givenCell;

    _values[cell] = value;
    _notes[cell].clear();
    if (value != puzzle.solution[cell]) {
      mistakes++;
      _incorrectCells.add(cell);
      return SudokuEntryResult.mistake;
    }
    _incorrectCells.remove(cell);
    return SudokuEntryResult.accepted;
  }

  bool toggleNote(int cell, int value) {
    _checkCell(cell);
    if (value < 1 || value > 9) {
      throw RangeError.range(value, 1, 9, 'value');
    }
    if (isGiven(cell) || _values[cell] != 0 || isComplete) return false;
    if (!_notes[cell].add(value)) _notes[cell].remove(value);
    return true;
  }

  bool erase(int cell) {
    _checkCell(cell);
    if (isGiven(cell) || isComplete) return false;
    final changed = _values[cell] != 0 || _notes[cell].isNotEmpty;
    _values[cell] = 0;
    _notes[cell].clear();
    _incorrectCells.remove(cell);
    return changed;
  }

  SudokuHintResult revealHint([int? cell]) {
    if (isComplete) return SudokuHintResult.puzzleComplete;
    if (hintsUsed >= maximumHints) return SudokuHintResult.limitReached;
    if (cell != null && (cell < 0 || cell >= SudokuSolver.cellCount)) {
      return SudokuHintResult.outOfBounds;
    }
    final target = cell ?? _firstUnsolvedCell();
    if (target == null || isGiven(target)) return SudokuHintResult.outOfBounds;

    _values[target] = puzzle.solution[target];
    _notes[target].clear();
    _incorrectCells.remove(target);
    hintsUsed++;
    return SudokuHintResult.revealed;
  }

  int? _firstUnsolvedCell() {
    for (var cell = 0; cell < SudokuSolver.cellCount; cell++) {
      if (!isGiven(cell) && _values[cell] != puzzle.solution[cell]) return cell;
    }
    return null;
  }

  void _checkCell(int cell) {
    if (cell < 0 || cell >= SudokuSolver.cellCount) {
      throw RangeError.range(cell, 0, SudokuSolver.cellCount - 1, 'cell');
    }
  }
}
