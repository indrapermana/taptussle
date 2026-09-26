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
  }) : model = MemoryMatchModel(
         difficulty: difficulty,
         playerCount: session.options.participants.length,
         random: random,
       ),
       _openingPreviewDuration = openingPreviewDuration {
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final MemoryMatchModel model;
  final Duration mismatchRevealDuration;
  final Duration? _openingPreviewDuration;
  Timer? _previewTimer;
  Timer? _mismatchTimer;
  var _previewing = false;
  var _observedRound = 0;
  var _observedPhase = MatchPhase.ready;
  var _hasStartedRound = false;
  var _disposed = false;

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

  MemorySelectionResult selectCard(int index) {
    if (!acceptsInput) return MemorySelectionResult.unavailable;
    final result = model.selectCard(model.currentPlayer, index);
    if (result == MemorySelectionResult.mismatch) {
      _scheduleMismatchResolution();
    }
    notifyListeners();
    return result;
  }

  void _syncSession() {
    if (_disposed) return;
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
        _previewing = _previewDuration > Duration.zero;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelTimers();
    } else if (roundChanged || phaseChanged) {
      if (_previewing) {
        _schedulePreviewEnd();
      } else if (model.hasPendingMismatch) {
        _scheduleMismatchResolution();
      }
    }
    if (roundChanged || phaseChanged) notifyListeners();
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
