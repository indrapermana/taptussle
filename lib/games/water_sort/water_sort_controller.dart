import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'water_sort_levels.dart';
import 'water_sort_model.dart';
import 'water_sort_progress_repository.dart';
import 'water_sort_solver.dart';

enum WaterSortTapResult {
  selected,
  selectionCleared,
  selectionChanged,
  poured,
  invalid,
  inputLocked,
  completed,
}

class WaterSortController extends ChangeNotifier {
  WaterSortController({
    required this.level,
    WaterSortModel? initialModel,
    this.session,
    this.repository,
    WaterSortProgressSnapshot? restoredProgress,
    WaterSortSolver solver = const WaterSortSolver(),
    DateTime Function()? now,
    this.clockTick = const Duration(seconds: 1),
    this.animationDuration = const Duration(milliseconds: 360),
  }) : model =
           restoredProgress?.restoreModel() ??
           initialModel ??
           level.createModel(),
       _elapsedBeforeActive = Duration(
         milliseconds: restoredProgress?.elapsedMilliseconds ?? 0,
       ),
       _now = now ?? DateTime.now,
       _solver = solver {
    if (initialModel != null && restoredProgress != null) {
      throw ArgumentError('Provide initialModel or restoredProgress, not both');
    }
    if (restoredProgress != null &&
        (restoredProgress.difficulty != level.difficulty ||
            restoredProgress.level != level.number)) {
      throw ArgumentError('Restored progress belongs to another level');
    }
    if (model.capacity != level.capacity ||
        model.tubeCount != level.tubes.length) {
      throw ArgumentError('Initial model does not match the level shape');
    }
    session?.addListener(_syncSession);
    _observedPhase = session?.phase ?? MatchPhase.playing;
    if (session != null && _observedPhase == MatchPhase.playing) _startClock();
  }

  WaterSortLevel level;
  final MatchSession? session;
  final WaterSortProgressRepository? repository;
  final Duration animationDuration;
  final Duration clockTick;
  final WaterSortSolver _solver;
  final DateTime Function() _now;
  WaterSortModel model;
  Timer? _animationTimer;
  Timer? _clockTimer;
  DateTime? _activeStartedAt;
  Duration _elapsedBeforeActive;
  MatchPhase _observedPhase = MatchPhase.ready;
  late int _observedRound = session?.round ?? 0;
  bool _disposed = false;
  bool _completionReported = false;
  int? _selectedTube;
  WaterSortMove? _animatingMove;
  WaterSortMove? _hintMove;

  int? get selectedTube => _selectedTube;
  WaterSortMove? get animatingMove => _animatingMove;
  WaterSortMove? get hintMove => _hintMove;
  bool get isAnimating => _animatingMove != null;
  bool get acceptsInput =>
      !isAnimating &&
      !model.isComplete &&
      (session == null || session!.phase == MatchPhase.playing);
  Duration get elapsed =>
      _elapsedBeforeActive +
      (_activeStartedAt == null
          ? Duration.zero
          : _now().difference(_activeStartedAt!));
  WaterSortPersonalBest? get personalBest =>
      repository?.personalBest(level.difficulty, level.number);
  String get elapsedLabel => _formatElapsed(elapsed);

  WaterSortTapResult tapTube(int tube) {
    if (tube < 0 || tube >= model.tubeCount) {
      return WaterSortTapResult.invalid;
    }
    if (model.isComplete) return WaterSortTapResult.completed;
    if (!acceptsInput) return WaterSortTapResult.inputLocked;

    final selected = _selectedTube;
    if (selected == null) {
      if (model.tubes[tube].isEmpty) return WaterSortTapResult.invalid;
      _selectedTube = tube;
      _hintMove = null;
      notifyListeners();
      return WaterSortTapResult.selected;
    }
    if (selected == tube) {
      _selectedTube = null;
      notifyListeners();
      return WaterSortTapResult.selectionCleared;
    }

    final result = model.pour(selected, tube);
    if (!result.accepted) {
      if (model.tubes[tube].isNotEmpty) {
        _selectedTube = tube;
        _hintMove = null;
        notifyListeners();
        return WaterSortTapResult.selectionChanged;
      }
      return WaterSortTapResult.invalid;
    }

    model = result.model;
    _selectedTube = null;
    _hintMove = null;
    _animatingMove = result.move;
    _saveProgress();
    notifyListeners();
    _animationTimer?.cancel();
    if (animationDuration == Duration.zero) {
      _finishAnimation();
    } else {
      _animationTimer = Timer(animationDuration, _finishAnimation);
    }
    return WaterSortTapResult.poured;
  }

  bool undo() {
    if (!acceptsInput || !model.canUndo) return false;
    model = model.undo();
    _selectedTube = null;
    _hintMove = null;
    _saveProgress();
    notifyListeners();
    return true;
  }

  bool restart() {
    if (!acceptsInput || model.moveCount == 0) return false;
    model = model.restart();
    _elapsedBeforeActive = Duration.zero;
    _activeStartedAt = session?.phase == MatchPhase.playing ? _now() : null;
    _selectedTube = null;
    _hintMove = null;
    _saveProgress();
    notifyListeners();
    return true;
  }

  WaterSortMove? requestHint() {
    if (isAnimating || model.isComplete) return null;
    final solution = _solver.solve(model);
    _hintMove = solution == null || solution.moves.isEmpty
        ? null
        : solution.moves.first;
    _selectedTube = null;
    notifyListeners();
    return _hintMove;
  }

  void clearHint() {
    if (_hintMove == null) return;
    _hintMove = null;
    notifyListeners();
  }

  void _finishAnimation() {
    if (_disposed) return;
    _animationTimer = null;
    _animatingMove = null;
    if (model.isComplete) _completePuzzle();
    notifyListeners();
  }

  void _syncSession() {
    if (_disposed || session == null) return;
    if (session!.round != _observedRound) {
      final previousRound = _observedRound;
      _observedRound = session!.round;
      if (previousRound > 0) _startNextRound();
    }
    final next = session!.phase;
    if (_observedPhase == MatchPhase.playing && next != MatchPhase.playing) {
      _stopClock();
      _saveProgress();
    } else if (_observedPhase != MatchPhase.playing &&
        next == MatchPhase.playing) {
      _startClock();
    }
    _observedPhase = next;
    notifyListeners();
  }

  void _startNextRound() {
    _stopClock();
    final nextLevel = (level.number + 1).clamp(
      1,
      WaterSortLevelCatalog.levelsPerDifficulty,
    );
    level = WaterSortLevelCatalog.level(level.difficulty, nextLevel);
    model = level.createModel();
    _elapsedBeforeActive = Duration.zero;
    _selectedTube = null;
    _animatingMove = null;
    _hintMove = null;
    _completionReported = false;
    _animationTimer?.cancel();
    _animationTimer = null;
    _saveProgress();
  }

  void _startClock() {
    _activeStartedAt ??= _now();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(clockTick, (_) {
      if (!_disposed &&
          (session == null || session!.phase == MatchPhase.playing)) {
        notifyListeners();
      }
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
    final storage = repository;
    if (storage == null || model.isComplete) return;
    unawaited(storage.saveActive(level: level, model: model, elapsed: elapsed));
  }

  void _completePuzzle() {
    if (_completionReported) return;
    _completionReported = true;
    _stopClock();
    final completionTime = elapsed;
    final moves = model.moveCount;
    final storage = repository;
    if (storage != null) {
      unawaited(
        storage.recordCompletion(
          level: level,
          moves: moves,
          elapsed: completionTime,
        ),
      );
    }
    if (session?.phase == MatchPhase.playing) {
      session!.reportCompletion(
        scores: const [0],
        details:
            'Level ${level.number} complete • $moves moves • '
            '${_formatElapsed(completionTime)}',
        recordMetrics: {
          'level': level.number,
          'moves': moves,
          'time': completionTime.inMilliseconds,
        },
      );
    }
  }

  String _formatElapsed(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    _disposed = true;
    _animationTimer?.cancel();
    _stopClock();
    _saveProgress();
    session?.removeListener(_syncSession);
    super.dispose();
  }
}
