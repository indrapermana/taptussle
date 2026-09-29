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
    _observedRound = session.round;
    _syncSession();
  }

  final MatchSession session;
  final SudokuProgressRepository repository;
  SudokuModel model;
  final DateTime Function() _now;
  final Duration clockTick;
  Timer? _clockTimer;
  DateTime? _activeStartedAt;
  Duration _elapsedBeforeActive;
  MatchPhase _observedPhase = MatchPhase.ready;
  late int _observedRound;
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
      model.isComplete ? _completePuzzle() : _saveProgress();
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
      model.isComplete ? _completePuzzle() : _saveProgress();
      notifyListeners();
    }
    return result;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      final previousRound = _observedRound;
      _observedRound = session.round;
      if (previousRound > 0) _startNextRound();
    }
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

  void _startNextRound() {
    _stopClock();
    final nextLevel = model.puzzle.level < SudokuCatalog.levelsPerDifficulty
        ? model.puzzle.level + 1
        : model.puzzle.level;
    model = SudokuModel(
      SudokuCatalog.puzzle(model.puzzle.difficulty, nextLevel),
    );
    _elapsedBeforeActive = Duration.zero;
    _selectedCell = null;
    _notesMode = false;
  }

  void _completePuzzle() {
    _stopClock();
    final elapsedMilliseconds = elapsed.inMilliseconds;
    final puzzle = model.puzzle;
    final nextLevel = (puzzle.level + 1).clamp(
      1,
      SudokuCatalog.levelsPerDifficulty,
    );
    unawaited(repository.clear(puzzle.difficulty));
    unawaited(repository.unlockLevel(puzzle.difficulty, nextLevel));
    session.reportCompletion(
      scores: const [0],
      details:
          'Level ${puzzle.level} complete • ${model.mistakes} mistakes • '
          '${_formatElapsed(elapsedMilliseconds)}${model.isAssisted ? ' • Assisted' : ''}',
      recordMetrics: {
        'level': puzzle.level,
        'unassisted': model.isAssisted ? 0 : 1,
        'mistakes': model.mistakes,
        'time': elapsedMilliseconds,
      },
    );
  }

  String _formatElapsed(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
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
