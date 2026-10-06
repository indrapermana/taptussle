import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'nuts_and_bolts_levels.dart';
import 'nuts_and_bolts_model.dart';
import 'nuts_and_bolts_progress_repository.dart';

enum NutsAndBoltsTapResult {
  selected,
  selectionCleared,
  selectionChanged,
  moved,
  invalid,
  inputLocked,
  completed,
}

class NutsAndBoltsController extends ChangeNotifier {
  NutsAndBoltsController({
    required this.level,
    NutsAndBoltsModel? initialModel,
    this.session,
    this.repository,
    NutsAndBoltsProgressSnapshot? restoredProgress,
    DateTime Function()? now,
    this.clockTick = const Duration(seconds: 1),
    this.animationDuration = const Duration(milliseconds: 300),
  }) : model =
           restoredProgress?.restoreModel() ??
           initialModel ??
           level.createModel(),
       _elapsedBeforeActive = Duration(
         milliseconds: restoredProgress?.elapsedMilliseconds ?? 0,
       ),
       _now = now ?? DateTime.now {
    if (initialModel != null && restoredProgress != null) {
      throw ArgumentError('Provide initialModel or restoredProgress, not both');
    }
    if (restoredProgress != null &&
        (restoredProgress.difficulty != level.difficulty ||
            restoredProgress.level != level.number)) {
      throw ArgumentError('Restored progress belongs to another level');
    }
    if (model.capacity != level.capacity ||
        model.boltCount != level.bolts.length) {
      throw ArgumentError('Initial model does not match the level shape');
    }
    session?.addListener(_syncSession);
    _observedPhase = session?.phase ?? MatchPhase.playing;
    if (session != null && _observedPhase == MatchPhase.playing) _startClock();
  }

  NutsAndBoltsLevel level;
  final MatchSession? session;
  final NutsAndBoltsProgressRepository? repository;
  final Duration animationDuration;
  final Duration clockTick;
  final DateTime Function() _now;
  NutsAndBoltsModel model;
  Timer? _animationTimer;
  Timer? _clockTimer;
  DateTime? _activeStartedAt;
  Duration _elapsedBeforeActive;
  MatchPhase _observedPhase = MatchPhase.ready;
  late int _observedRound = session?.round ?? 0;
  int? _selectedBolt;
  NutsAndBoltsMove? _animatingMove;
  NutsAndBoltsMove? _hintMove;
  bool _disposed = false;
  bool _completionReported = false;

  int? get selectedBolt => _selectedBolt;
  NutsAndBoltsMove? get animatingMove => _animatingMove;
  NutsAndBoltsMove? get hintMove => _hintMove;
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
  NutsAndBoltsPersonalBest? get personalBest =>
      repository?.personalBest(level.difficulty, level.number);
  String get elapsedLabel => _formatElapsed(elapsed);

  bool isLegalDestination(int bolt) =>
      _selectedBolt != null && model.canMove(_selectedBolt!, bolt);

  NutsAndBoltsTapResult tapBolt(int bolt) {
    if (bolt < 0 || bolt >= model.boltCount) {
      return NutsAndBoltsTapResult.invalid;
    }
    if (model.isComplete) return NutsAndBoltsTapResult.completed;
    if (!acceptsInput) return NutsAndBoltsTapResult.inputLocked;

    final selected = _selectedBolt;
    if (selected == null) {
      if (model.bolts[bolt].isEmpty) return NutsAndBoltsTapResult.invalid;
      _selectedBolt = bolt;
      _hintMove = null;
      notifyListeners();
      return NutsAndBoltsTapResult.selected;
    }
    if (selected == bolt) {
      _selectedBolt = null;
      notifyListeners();
      return NutsAndBoltsTapResult.selectionCleared;
    }

    final result = model.move(selected, bolt);
    if (!result.accepted) {
      if (model.bolts[bolt].isNotEmpty) {
        _selectedBolt = bolt;
        _hintMove = null;
        notifyListeners();
        return NutsAndBoltsTapResult.selectionChanged;
      }
      return NutsAndBoltsTapResult.invalid;
    }

    model = result.model;
    _selectedBolt = null;
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
    return NutsAndBoltsTapResult.moved;
  }

  bool undo() {
    if (!acceptsInput || !model.canUndo) return false;
    model = model.undo();
    _selectedBolt = null;
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
    _selectedBolt = null;
    _hintMove = null;
    _saveProgress();
    notifyListeners();
    return true;
  }

  NutsAndBoltsMove? requestHint() {
    if (!acceptsInput) return null;
    _hintMove = model.hint;
    _selectedBolt = null;
    notifyListeners();
    return _hintMove;
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
      NutsAndBoltsLevelCatalog.levelsPerDifficulty,
    );
    level = NutsAndBoltsLevelCatalog.level(level.difficulty, nextLevel);
    model = level.createModel();
    _elapsedBeforeActive = Duration.zero;
    _selectedBolt = null;
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
