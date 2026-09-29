import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'sudoku_model.dart';

class SudokuProgressSnapshot {
  const SudokuProgressSnapshot({
    required this.difficulty,
    required this.level,
    required this.values,
    required this.notes,
    required this.incorrectCells,
    required this.mistakes,
    required this.hintsUsed,
    required this.elapsedMilliseconds,
  });

  final SudokuDifficulty difficulty;
  final int level;
  final List<int> values;
  final List<Set<int>> notes;
  final Set<int> incorrectCells;
  final int mistakes;
  final int hintsUsed;
  final int elapsedMilliseconds;

  SudokuModel restoreModel() => SudokuModel.restore(
    SudokuCatalog.puzzle(difficulty, level),
    values: values,
    notes: notes,
    incorrectCells: incorrectCells,
    mistakes: mistakes,
    hintsUsed: hintsUsed,
  );
}

class SudokuProgressRepository {
  SudokuProgressRepository(this._preferences);

  static const _version = 1;
  final SharedPreferences _preferences;
  Future<void> _pendingWrite = Future.value();

  String _key(SudokuDifficulty difficulty) =>
      'sudoku.progress.${difficulty.name}';
  String _levelKey(SudokuDifficulty difficulty) =>
      'sudoku.unlockedLevel.${difficulty.name}';

  int unlockedLevel(SudokuDifficulty difficulty) {
    final saved = _preferences.getInt(_levelKey(difficulty));
    return saved == null ||
            saved < 1 ||
            saved > SudokuCatalog.levelsPerDifficulty
        ? 1
        : saved;
  }

  Future<void> unlockLevel(SudokuDifficulty difficulty, int level) {
    final next = level.clamp(1, SudokuCatalog.levelsPerDifficulty);
    if (next <= unlockedLevel(difficulty)) return Future.value();
    return _enqueue(() async {
      if (!await _preferences.setInt(_levelKey(difficulty), next)) {
        throw StateError('Could not save Sudoku level progress');
      }
    });
  }

  SudokuProgressSnapshot? load(SudokuDifficulty difficulty) {
    final encoded = _preferences.getString(_key(difficulty));
    if (encoded == null) return null;
    try {
      final data = jsonDecode(encoded);
      if (data is! Map<String, dynamic> ||
          data['version'] != _version ||
          data['difficulty'] != difficulty.name) {
        return null;
      }
      final values = _intList(data['values']);
      final rawNotes = data['notes'];
      final incorrect = _intList(data['incorrectCells']).toSet();
      if (rawNotes is! List || rawNotes.length != SudokuSolver.cellCount) {
        return null;
      }
      final notes = <Set<int>>[];
      for (final rawCellNotes in rawNotes) {
        notes.add(_intList(rawCellNotes).toSet());
      }
      final snapshot = SudokuProgressSnapshot(
        difficulty: difficulty,
        level: _integer(data['level']),
        values: values,
        notes: notes,
        incorrectCells: incorrect,
        mistakes: _integer(data['mistakes']),
        hintsUsed: _integer(data['hintsUsed']),
        elapsedMilliseconds: _integer(data['elapsedMilliseconds']),
      );
      if (snapshot.elapsedMilliseconds < 0) return null;
      snapshot.restoreModel();
      return snapshot;
    } on Object {
      return null;
    }
  }

  Future<void> save({required SudokuModel model, required Duration elapsed}) {
    final snapshot = jsonEncode({
      'version': _version,
      'difficulty': model.puzzle.difficulty.name,
      'level': model.puzzle.level,
      'values': model.values,
      'notes': [for (final notes in model.notes) notes.toList()..sort()],
      'incorrectCells': model.incorrectCells.toList()..sort(),
      'mistakes': model.mistakes,
      'hintsUsed': model.hintsUsed,
      'elapsedMilliseconds': elapsed.inMilliseconds,
    });
    return _enqueue(() async {
      if (!await _preferences.setString(
        _key(model.puzzle.difficulty),
        snapshot,
      )) {
        throw StateError('Could not save Sudoku progress');
      }
    });
  }

  Future<void> clear(SudokuDifficulty difficulty) => _enqueue(() async {
    if (!await _preferences.remove(_key(difficulty))) {
      throw StateError('Could not clear Sudoku progress');
    }
  });

  Future<void> get completed => _pendingWrite;

  Future<void> _enqueue(Future<void> Function() action) {
    final result = _pendingWrite.then((_) => action());
    _pendingWrite = result.catchError((Object _) {});
    return result;
  }

  static int _integer(Object? value) {
    if (value is! int) throw const FormatException('Expected an integer');
    return value;
  }

  static List<int> _intList(Object? value) {
    if (value is! List || value.any((item) => item is! int)) {
      throw const FormatException('Expected an integer list');
    }
    return value.cast<int>();
  }
}
