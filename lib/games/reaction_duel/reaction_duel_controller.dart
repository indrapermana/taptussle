import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';

enum ReactionPhase { preparing, waiting, signal, resolving }

enum ReactionRoundOutcome { point, falseStart, tie }

@immutable
class ReactionRoundResult {
  const ReactionRoundResult({
    required this.outcome,
    required this.reactionTimes,
    this.winner,
    this.falseStarter,
  });

  final ReactionRoundOutcome outcome;
  final int? winner;
  final int? falseStarter;
  final List<Duration?> reactionTimes;

  Duration? get difference {
    final first = reactionTimes[0];
    final second = reactionTimes[1];
    if (first == null || second == null) return null;
    return (first - second).abs();
  }
}

/// Frame-independent state machine for Reaction Duel.
class ReactionDuelController extends ChangeNotifier {
  ReactionDuelController({
    required this.session,
    Random? random,
    this.prepareDelay = const Duration(milliseconds: 600),
    this.waitDelay,
    this.botDelay,
    this.resultDelay = const Duration(milliseconds: 1200),
    this.tieDelay = const Duration(milliseconds: 900),
  }) : _random = random ?? Random();

  final MatchSession session;
  final Random _random;
  final Duration prepareDelay;
  final Duration? waitDelay;
  final Duration? botDelay;
  final Duration resultDelay;
  final Duration tieDelay;
  final scores = [0, 0];
  ReactionPhase phase = ReactionPhase.preparing;
  ReactionRoundResult? lastResult;
  Timer? _timer;
  Stopwatch? _signalClock;
  int? _firstTap;
  Duration? _firstTapAt;
  bool _disposed = false;
  static const simultaneousTolerance = Duration(milliseconds: 5);

  void startRound() {
    _timer?.cancel();
    _firstTap = null;
    _firstTapAt = null;
    lastResult = null;
    phase = ReactionPhase.preparing;
    notifyListeners();
    _timer = Timer(prepareDelay, _beginWaiting);
  }

  void _beginWaiting() {
    if (_disposed || session.phase != MatchPhase.playing) return;
    phase = ReactionPhase.waiting;
    notifyListeners();
    final delay =
        waitDelay ?? Duration(milliseconds: 1500 + _random.nextInt(2501));
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
    if (phase == ReactionPhase.preparing || phase == ReactionPhase.waiting) {
      _award(1 - player, falseStarter: player);
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
      notifyListeners();
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
      _award(player, reactionTime: _firstTapAt);
    }
  }

  void _replayRound() {
    _timer?.cancel();
    final times = List<Duration?>.filled(2, null);
    times[_firstTap!] = _firstTapAt;
    times[1 - _firstTap!] = _signalClock?.elapsed;
    lastResult = ReactionRoundResult(
      outcome: ReactionRoundOutcome.tie,
      reactionTimes: times,
    );
    phase = ReactionPhase.resolving;
    notifyListeners();
    _timer = Timer(tieDelay, startRound);
  }

  void _award(int player, {int? falseStarter, Duration? reactionTime}) {
    _timer?.cancel();
    scores[player]++;
    final times = List<Duration?>.filled(2, null);
    times[player] = reactionTime;
    lastResult = ReactionRoundResult(
      outcome: falseStarter == null
          ? ReactionRoundOutcome.point
          : ReactionRoundOutcome.falseStart,
      winner: player,
      falseStarter: falseStarter,
      reactionTimes: times,
    );
    phase = ReactionPhase.resolving;
    final winner = scores[player] >= session.options.winningScore
        ? player
        : null;
    session.reportScore(scores[0], scores[1], winner: winner);
    notifyListeners();
    if (winner == null) {
      _timer = Timer(resultDelay, startRound);
    }
  }

  void pause() {
    _timer?.cancel();
    _firstTap = null;
    _firstTapAt = null;
    lastResult = null;
    phase = ReactionPhase.preparing;
  }

  void resetMatch() {
    _timer?.cancel();
    scores.fillRange(0, 2, 0);
    _firstTap = null;
    _firstTapAt = null;
    lastResult = null;
    phase = ReactionPhase.preparing;
    startRound();
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
