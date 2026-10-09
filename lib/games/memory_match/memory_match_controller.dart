import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'memory_match_bot.dart';
import 'memory_match_model.dart';

class MemoryMatchController extends ChangeNotifier {
  MemoryMatchController({
    required this.session,
    required MemoryMatchDifficulty difficulty,
    Random? random,
    this.mismatchRevealDuration = const Duration(milliseconds: 850),
    Duration? openingPreviewDuration,
    Duration? botThinkDuration,
    this.resultRevealDelay = Duration.zero,
    DateTime Function()? now,
    this.onSelection,
  }) : _random = random ?? Random(),
       model = MemoryMatchModel(
         difficulty: difficulty,
         playerCount: session.options.participants.length,
         random: random ?? Random(),
       ),
       _openingPreviewDuration = openingPreviewDuration,
       _botThinkDuration = botThinkDuration,
       _now = now ?? DateTime.now {
    final botDifficulty = session.options.botDifficulty;
    _bot = botDifficulty == null
        ? null
        : MemoryMatchBot(difficulty: botDifficulty, random: _random);
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final MemoryMatchModel model;
  final Duration mismatchRevealDuration;
  final Duration resultRevealDelay;
  final ValueChanged<MemorySelectionResult>? onSelection;
  final Random _random;
  final Duration? _openingPreviewDuration;
  final Duration? _botThinkDuration;
  final DateTime Function() _now;
  late final MemoryMatchBot? _bot;
  Timer? _previewTimer;
  Timer? _mismatchTimer;
  Timer? _botTimer;
  Timer? _resultTimer;
  var _previewing = false;
  var _observedRound = 0;
  var _observedPhase = MatchPhase.ready;
  var _hasStartedRound = false;
  var _disposed = false;
  var _elapsedBeforeActive = Duration.zero;
  int? _completedElapsedMilliseconds;
  List<int> _lastSelectedCards = const [];
  DateTime? _activeStartedAt;

  bool get isPreviewing => _previewing;
  Duration get previewDuration => _previewDuration;
  bool get isResolvingMismatch => _mismatchTimer?.isActive ?? false;
  bool get isPresentingResult => model.isFinished && _resultTimer != null;
  List<int> get lastSelectedCards => List.unmodifiable(_lastSelectedCards);
  int? get _botPlayer {
    final participants = session.options.participants;
    for (var index = 0; index < participants.length; index++) {
      if (participants[index].isBot) return index;
    }
    return null;
  }

  bool get isBotTurn =>
      _botPlayer != null &&
      model.currentPlayer == _botPlayer &&
      !model.isFinished;
  bool get isBotThinking => isBotTurn && (_botTimer?.isActive ?? false);
  bool get acceptsInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !_previewing &&
      !model.hasPendingMismatch &&
      !model.isFinished &&
      !isBotTurn;

  bool isCardFaceUp(int index) =>
      _previewing || model.cardAt(index).state != MemoryCardState.hidden;

  Duration get elapsed {
    final startedAt = _activeStartedAt;
    return _elapsedBeforeActive +
        (startedAt == null ? Duration.zero : _now().difference(startedAt));
  }

  MemorySelectionResult selectCard(int index) {
    if (!acceptsInput) return MemorySelectionResult.unavailable;
    return _selectCard(model.currentPlayer, index);
  }

  MemorySelectionResult _selectCard(int player, int index) {
    final previouslyRevealed = model.revealedCards;
    final result = model.selectCard(player, index);
    if (_isReveal(result)) {
      _lastSelectedCards = [...previouslyRevealed, index];
      _bot?.observeCard(index, model.cardAt(index).pairId);
      onSelection?.call(result);
    }
    if (result == MemorySelectionResult.mismatch) {
      _scheduleMismatchResolution();
    }
    notifyListeners();
    if (result == MemorySelectionResult.matched) {
      session.reportScores(model.scores);
    } else if (result == MemorySelectionResult.completed) {
      _scheduleResult();
    }
    if ((result == MemorySelectionResult.firstCard ||
            result == MemorySelectionResult.matched) &&
        isBotTurn) {
      _scheduleBotSelection();
    }
    return result;
  }

  bool _isReveal(MemorySelectionResult result) =>
      result == MemorySelectionResult.firstCard ||
      result == MemorySelectionResult.matched ||
      result == MemorySelectionResult.mismatch ||
      result == MemorySelectionResult.completed;

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
      _lastSelectedCards = const [];
      _bot?.reset();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model.startRematch();
        } else {
          _hasStartedRound = true;
        }
        _elapsedBeforeActive = Duration.zero;
        _completedElapsedMilliseconds = null;
        _activeStartedAt = null;
        _previewing = _previewDuration > Duration.zero;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelTimers();
    } else if (roundChanged || phaseChanged) {
      if (!model.isFinished) _activeStartedAt ??= _now();
      if (model.isFinished) {
        _scheduleResult();
      } else if (_previewing) {
        _schedulePreviewEnd();
      } else if (model.hasPendingMismatch) {
        _scheduleMismatchResolution();
      } else if (isBotTurn) {
        _scheduleBotSelection();
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
    final elapsedMilliseconds =
        _completedElapsedMilliseconds ?? elapsed.inMilliseconds;
    final details = model.playerCount == 1
        ? 'Completed in ${model.moveCount} moves • '
              '${_formatElapsed(elapsedMilliseconds)}'
        : null;
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

  void _scheduleResult() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !model.isFinished ||
        _resultTimer != null) {
      return;
    }
    _stopElapsedClock();
    _completedElapsedMilliseconds ??= elapsed.inMilliseconds;
    if (resultRevealDelay == Duration.zero) {
      _publishResult();
      return;
    }
    _resultTimer = Timer(resultRevealDelay, () {
      _resultTimer = null;
      if (_disposed ||
          session.phase != MatchPhase.playing ||
          !model.isFinished) {
        return;
      }
      _publishResult();
    });
    notifyListeners();
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
      if (isBotTurn) _scheduleBotSelection();
    });
  }

  void _scheduleMismatchResolution() {
    _mismatchTimer?.cancel();
    _mismatchTimer = Timer(mismatchRevealDuration, () {
      _mismatchTimer = null;
      if (_disposed || session.phase != MatchPhase.playing) return;
      if (model.resolveMismatch()) {
        notifyListeners();
        if (isBotTurn) _scheduleBotSelection();
      }
    });
  }

  void _scheduleBotSelection() {
    final bot = _bot;
    final botPlayer = _botPlayer;
    if (bot == null ||
        botPlayer == null ||
        _disposed ||
        session.phase != MatchPhase.playing ||
        _previewing ||
        model.hasPendingMismatch ||
        model.isFinished ||
        model.currentPlayer != botPlayer) {
      return;
    }
    _botTimer?.cancel();
    _botTimer = Timer(_currentBotThinkDuration, () {
      _botTimer = null;
      if (_disposed ||
          session.phase != MatchPhase.playing ||
          model.currentPlayer != botPlayer ||
          model.hasPendingMismatch ||
          model.isFinished) {
        return;
      }
      final legalIndexes = <int>[
        for (var index = 0; index < model.cardCount; index++)
          if (model.cardAt(index).state == MemoryCardState.hidden) index,
      ];
      final firstIndex = model.revealedCards.firstOrNull;
      final choice = bot.chooseCard(
        legalIndexes: legalIndexes,
        revealedPairId: firstIndex == null
            ? null
            : model.cardAt(firstIndex).pairId,
      );
      if (choice != null) _selectCard(botPlayer, choice);
    });
    notifyListeners();
  }

  Duration get _currentBotThinkDuration {
    final override = _botThinkDuration;
    if (override != null) return override;
    final choosingSecondCard = model.revealedCards.isNotEmpty;
    return switch (session.options.botDifficulty!) {
      BotDifficulty.easy => Duration(
        milliseconds: choosingSecondCard ? 700 : 1050,
      ),
      BotDifficulty.normal => Duration(
        milliseconds: choosingSecondCard ? 550 : 850,
      ),
      BotDifficulty.hard => Duration(
        milliseconds: choosingSecondCard ? 450 : 700,
      ),
    };
  }

  void _cancelTimers() {
    _previewTimer?.cancel();
    _previewTimer = null;
    _mismatchTimer?.cancel();
    _mismatchTimer = null;
    _botTimer?.cancel();
    _botTimer = null;
    _resultTimer?.cancel();
    _resultTimer = null;
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
