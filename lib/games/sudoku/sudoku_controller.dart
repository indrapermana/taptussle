import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'sudoku_model.dart';
import 'sudoku_progress_repository.dart';

class SudokuController extends ChangeNotifier {
  SudokuController({
    required this.session,
    required SudokuPuzzle puzzle,
    required this.repository,
    SudokuProgressSnapshot? restoredProgress,
    DateTime Function()? now,
    this.clockTick = const Duration(seconds: 1),
  }) : model = restoredProgress?.restoreModel() ?? SudokuModel(puzzle),
       _elapsedBeforeActive = Duration(
         milliseconds: restoredProgress?.elapsedMilliseconds ?? 0,
       ),
       _now = now ?? DateTime.now {
    if (model.puzzle.difficulty != puzzle.difficulty ||
        model.puzzle.level != puzzle.level) {
      throw ArgumentError('Restored progress belongs to another puzzle');
    }
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final SudokuProgressRepository repository;
  final SudokuModel model;
  final DateTime Function() _now;
  final Duration clockTick;
  Timer? _clockTimer;
  DateTime? _activeStartedAt;
  Duration _elapsedBeforeActive;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _disposed = false;
  int? _selectedCell;
  bool _notesMode = false;

  int? get selectedCell => _selectedCell;
  bool get notesMode => _notesMode;
  bool get isBoardVisible => session.phase == MatchPhase.playing;
  Duration get elapsed =>
      _elapsedBeforeActive +
      (_activeStartedAt == null
          ? Duration.zero
          : _now().difference(_activeStartedAt!));

  void selectCell(int cell) {
    if (!isBoardVisible || cell < 0 || cell >= SudokuSolver.cellCount) return;
    _selectedCell = cell;
    notifyListeners();
  }

  void toggleNotesMode() {
    if (!isBoardVisible || model.isComplete) return;
    _notesMode = !_notesMode;
    notifyListeners();
  }

  SudokuEntryResult? enterNumber(int value) {
    final cell = _selectedCell;
    if (!isBoardVisible || cell == null) return null;
    if (_notesMode) {
      if (model.toggleNote(cell, value)) {
        _saveProgress();
        notifyListeners();
      }
      return null;
    }
    final result = model.enter(cell, value);
    if (result == SudokuEntryResult.accepted ||
        result == SudokuEntryResult.mistake) {
      _saveProgress();
      notifyListeners();
    }
    return result;
  }

  bool eraseSelected() {
    final cell = _selectedCell;
    if (!isBoardVisible || cell == null || !model.erase(cell)) return false;
    _saveProgress();
    notifyListeners();
    return true;
  }

  SudokuHintResult? revealHint() {
    if (!isBoardVisible) return null;
    var result = model.revealHint(_selectedCell);
    if (result == SudokuHintResult.outOfBounds) result = model.revealHint();
    if (result == SudokuHintResult.revealed) {
      _saveProgress();
      notifyListeners();
    }
    return result;
  }

  void _syncSession() {
    if (_disposed) return;
    if (_observedPhase == MatchPhase.playing &&
        session.phase != MatchPhase.playing) {
      _stopClock();
      _saveProgress();
    }
    if (session.phase == MatchPhase.playing &&
        _observedPhase != MatchPhase.playing) {
      _activeStartedAt = _now();
      _startTicker();
    }
    if (session.phase == MatchPhase.finished) _clockTimer?.cancel();
    _observedPhase = session.phase;
    notifyListeners();
  }

  void _startTicker() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(clockTick, (_) {
      if (!_disposed && session.phase == MatchPhase.playing) notifyListeners();
    });
  }

  void _stopClock() {
    final started = _activeStartedAt;
    if (started != null) _elapsedBeforeActive += _now().difference(started);
    _activeStartedAt = null;
    _clockTimer?.cancel();
    _clockTimer = null;
  }

  void _saveProgress() {
    if (model.isComplete) {
      unawaited(repository.clear(model.puzzle.difficulty));
    } else {
      unawaited(repository.save(model: model, elapsed: elapsed));
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _stopClock();
    _saveProgress();
    _disposed = true;
    session.removeListener(_syncSession);
    super.dispose();
  }
}
