import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';

enum ReactionPhase { waiting, signal, resolving }

/// Frame-independent state machine for Reaction Duel.
class ReactionDuelController extends ChangeNotifier {
  ReactionDuelController({
    required this.session,
    Random? random,
    this.waitDelay,
    this.botDelay,
  }) : _random = random ?? Random();

  final MatchSession session;
  final Random _random;
  final Duration? waitDelay;
  final Duration? botDelay;
  final scores = [0, 0];
  ReactionPhase phase = ReactionPhase.waiting;
  Timer? _timer;
  Stopwatch? _signalClock;
  int? _firstTap;
  Duration? _firstTapAt;
  bool _disposed = false;
  static const simultaneousTolerance = Duration(milliseconds: 75);

  void startRound() {
    _timer?.cancel();
    _firstTap = null;
    _firstTapAt = null;
    phase = ReactionPhase.waiting;
    notifyListeners();
    final delay =
        waitDelay ?? Duration(milliseconds: 1400 + _random.nextInt(2201));
    _timer = Timer(delay, _showSignal);
  }

  void _showSignal() {
    if (_disposed || session.phase != MatchPhase.playing) return;
    phase = ReactionPhase.signal;
    _signalClock = Stopwatch()..start();
    notifyListeners();
    if (session.options.mode == PlayMode.bot) {
      final difficulty = session.options.botDifficulty!;
      final base = switch (difficulty) {
        BotDifficulty.easy => 720,
        BotDifficulty.normal => 430,
        BotDifficulty.hard => 250,
      };
      final variation = switch (difficulty) {
        BotDifficulty.easy => 380,
        BotDifficulty.normal => 180,
        BotDifficulty.hard => 110,
      };
      _timer = Timer(
        botDelay ?? Duration(milliseconds: base + _random.nextInt(variation)),
        () {
          tap(1);
        },
      );
    }
  }

  void tap(int player) {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        player < 0 ||
        player > 1) {
      return;
    }
    if (phase == ReactionPhase.waiting) {
      _award(1 - player);
      return;
    }
    if (phase != ReactionPhase.signal) {
      return;
    }
    final at = _signalClock?.elapsed ?? Duration.zero;
    if (_firstTap == null) {
      _firstTap = player;
      _firstTapAt = at;
      _timer?.cancel();
      _timer = Timer(simultaneousTolerance, _resolveFirstTap);
      return;
    }
    if (_firstTap != player &&
        (at - _firstTapAt!).abs() <= simultaneousTolerance) {
      _replayRound();
    }
  }

  void _resolveFirstTap() {
    final player = _firstTap;
    if (player != null) {
      _award(player);
    }
  }

  void _replayRound() {
    _timer?.cancel();
    phase = ReactionPhase.resolving;
    notifyListeners();
    _timer = Timer(const Duration(milliseconds: 700), startRound);
  }

  void _award(int player) {
    _timer?.cancel();
    scores[player]++;
    phase = ReactionPhase.resolving;
    final winner = scores[player] >= session.options.winningScore
        ? player
        : null;
    session.reportScore(scores[0], scores[1], winner: winner);
    notifyListeners();
    if (winner == null) {
      _timer = Timer(const Duration(milliseconds: 850), startRound);
    }
  }

  void pause() {
    _timer?.cancel();
    _firstTap = null;
    _firstTapAt = null;
    phase = ReactionPhase.waiting;
  }

  /// An interrupted waiting round never carries its old delay into a resume.
  void resumeAfterPause() => startRound();

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
