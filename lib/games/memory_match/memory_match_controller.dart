import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'memory_match_model.dart';

class MemoryMatchController extends ChangeNotifier {
  MemoryMatchController({
    required this.session,
    required MemoryMatchDifficulty difficulty,
    Random? random,
    this.mismatchRevealDuration = const Duration(milliseconds: 850),
    Duration? openingPreviewDuration,
    DateTime Function()? now,
  }) : model = MemoryMatchModel(
         difficulty: difficulty,
         playerCount: session.options.participants.length,
         random: random,
       ),
       _openingPreviewDuration = openingPreviewDuration,
       _now = now ?? DateTime.now {
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final MemoryMatchModel model;
  final Duration mismatchRevealDuration;
  final Duration? _openingPreviewDuration;
  final DateTime Function() _now;
  Timer? _previewTimer;
  Timer? _mismatchTimer;
  var _previewing = false;
  var _observedRound = 0;
  var _observedPhase = MatchPhase.ready;
  var _hasStartedRound = false;
  var _disposed = false;
  var _elapsedBeforeActive = Duration.zero;
  DateTime? _activeStartedAt;

  bool get isPreviewing => _previewing;
  bool get isResolvingMismatch => _mismatchTimer?.isActive ?? false;
  bool get acceptsInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !_previewing &&
      !model.hasPendingMismatch &&
      !model.isFinished;

  bool isCardFaceUp(int index) =>
      _previewing || model.cardAt(index).state != MemoryCardState.hidden;

  Duration get elapsed {
    final startedAt = _activeStartedAt;
    return _elapsedBeforeActive +
        (startedAt == null ? Duration.zero : _now().difference(startedAt));
  }

  MemorySelectionResult selectCard(int index) {
    if (!acceptsInput) return MemorySelectionResult.unavailable;
    final result = model.selectCard(model.currentPlayer, index);
    if (result == MemorySelectionResult.mismatch) {
      _scheduleMismatchResolution();
    }
    notifyListeners();
    if (result == MemorySelectionResult.matched) {
      session.reportScores(model.scores);
    } else if (result == MemorySelectionResult.completed) {
      _publishResult();
    }
    return result;
  }

  void _syncSession() {
    if (_disposed) return;
    final previousPhase = _observedPhase;
    if (previousPhase == MatchPhase.playing &&
        session.phase != MatchPhase.playing) {
      _stopElapsedClock();
    }
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelTimers();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model.startRematch();
        } else {
          _hasStartedRound = true;
        }
        _elapsedBeforeActive = Duration.zero;
        _activeStartedAt = null;
        _previewing = _previewDuration > Duration.zero;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelTimers();
    } else if (roundChanged || phaseChanged) {
      _activeStartedAt ??= _now();
      if (_previewing) {
        _schedulePreviewEnd();
      } else if (model.hasPendingMismatch) {
        _scheduleMismatchResolution();
      }
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _stopElapsedClock() {
    final startedAt = _activeStartedAt;
    if (startedAt == null) return;
    _elapsedBeforeActive += _now().difference(startedAt);
    _activeStartedAt = null;
  }

  void _publishResult() {
    _stopElapsedClock();
    final elapsedMilliseconds = elapsed.inMilliseconds;
    final details = model.playerCount == 1
        ? 'Completed in ${model.moveCount} moves • '
              '${_formatElapsed(elapsedMilliseconds)} • Play again?'
        : '${session.options.playerLabel(0)} ${model.scores[0]}  •  '
              '${session.options.playerLabel(1)} ${model.scores[1]}  •  '
              'Play again?';
    if (model.playerCount == 1) {
      session.reportCompletion(
        scores: model.scores,
        details: details,
        recordMetrics: {'moves': model.moveCount, 'time': elapsedMilliseconds},
      );
    } else if (model.isDraw) {
      session.reportDrawScores(model.scores, details: details);
    } else {
      session.reportResult(
        outcome: MatchOutcome.winner,
        scores: model.scores,
        winner: model.winner,
        details: details,
      );
    }
  }

  String _formatElapsed(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    final tenths = duration.inMilliseconds.remainder(1000) ~/ 100;
    return minutes > 0
        ? '$minutes:${seconds.toString().padLeft(2, '0')}'
        : '$seconds.${tenths}s';
  }

  Duration get _previewDuration =>
      _openingPreviewDuration ?? model.openingPreviewDuration;

  void _schedulePreviewEnd() {
    _previewTimer?.cancel();
    _previewTimer = Timer(_previewDuration, () {
      _previewTimer = null;
      if (_disposed || session.phase != MatchPhase.playing) return;
      _previewing = false;
      notifyListeners();
    });
  }

  void _scheduleMismatchResolution() {
    _mismatchTimer?.cancel();
    _mismatchTimer = Timer(mismatchRevealDuration, () {
      _mismatchTimer = null;
      if (_disposed || session.phase != MatchPhase.playing) return;
      if (model.resolveMismatch()) notifyListeners();
    });
  }

  void _cancelTimers() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _mismatchTimer?.cancel();
    _mismatchTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelTimers();
    super.dispose();
  }
}
