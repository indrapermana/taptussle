import 'dart:math';

import '../../core/match_options.dart';
import 'ludo_model.dart';

/// Selects only among moves already declared legal by [LudoModel].
///
/// Dice are deliberately absent from this API: every difficulty receives the
/// rolled value after the model has produced it and cannot reroll or replace it.
class LudoBot {
  LudoBot({Random? random}) : _random = random ?? Random();

  final Random _random;

  int chooseToken(LudoModel model, BotDifficulty difficulty) {
    final legal = model.legalTokenIndexes;
    if (model.phase != LudoTurnPhase.awaitingMove || legal.isEmpty) {
      throw StateError('The bot requires a rolled turn with a legal move');
    }

    return switch (difficulty) {
      BotDifficulty.easy => legal[_random.nextInt(legal.length)],
      BotDifficulty.normal => _bestToken(
        legal,
        (token) => _normalScore(model, token),
      ),
      BotDifficulty.hard => _bestToken(
        legal,
        (token) => _hardScore(model, token),
      ),
    };
  }

  int _bestToken(List<int> legal, int Function(int token) score) {
    var bestScore = -0x7FFFFFFF;
    final best = <int>[];
    for (final token in legal) {
      final candidateScore = score(token);
      if (candidateScore > bestScore) {
        bestScore = candidateScore;
        best
          ..clear()
          ..add(token);
      } else if (candidateScore == bestScore) {
        best.add(token);
      }
    }
    return best[_random.nextInt(best.length)];
  }

  int _normalScore(LudoModel model, int token) {
    final move = _analyze(model, token);
    return (move.finishesToken ? 1000 : 0) +
        move.captures * 650 +
        (move.entersBoard ? 260 : 0) +
        (move.entersHomePath ? 180 : 0) +
        move.endProgress;
  }

  int _hardScore(LudoModel model, int token) {
    final move = _analyze(model, token);
    return (move.finishesToken ? 10000 : 0) +
        move.captures * 4200 +
        (move.entersHomePath ? 900 : 0) +
        (move.entersBoard ? 700 : 0) +
        (move.landsSafe ? 420 : 0) +
        (move.leavesSafety ? -220 : 0) -
        move.captureThreats * 700 +
        move.endProgress * 3;
  }

  _MoveAnalysis _analyze(LudoModel model, int token) {
    final player = model.currentPlayer;
    final roll = model.pendingRoll!;
    final start = model.progressFor(player, token);
    final end = start == LudoModel.boxProgress ? 0 : start + roll;
    final landingTrack = end < LudoModel.trackLength
        ? (LudoModel.startTrackIndexes[player] + end) % LudoModel.trackLength
        : null;
    final startsSafe =
        start >= 0 &&
        start < LudoModel.trackLength &&
        LudoModel.safeTrackIndexes.contains(
          (LudoModel.startTrackIndexes[player] + start) % LudoModel.trackLength,
        );
    final landsSafe =
        landingTrack != null &&
        LudoModel.safeTrackIndexes.contains(landingTrack);

    var captures = 0;
    var threats = 0;
    if (landingTrack != null && !landsSafe) {
      for (var opponent = 0; opponent < model.playerCount; opponent++) {
        if (opponent == player) continue;
        for (
          var opponentToken = 0;
          opponentToken < LudoModel.tokensPerPlayer;
          opponentToken++
        ) {
          final opponentTrack = model.trackIndexFor(opponent, opponentToken);
          if (opponentTrack == null) continue;
          if (opponentTrack == landingTrack) captures++;
          final distance =
              (landingTrack - opponentTrack) % LudoModel.trackLength;
          if (distance >= 1 && distance <= 6) threats++;
        }
      }
    }

    return _MoveAnalysis(
      endProgress: end,
      entersBoard: start == LudoModel.boxProgress,
      entersHomePath:
          start < LudoModel.homePathStart && end >= LudoModel.homePathStart,
      finishesToken: end == LudoModel.finishProgress,
      captures: captures,
      captureThreats: threats,
      landsSafe: landsSafe,
      leavesSafety: startsSafe && !landsSafe,
    );
  }
}

class _MoveAnalysis {
  const _MoveAnalysis({
    required this.endProgress,
    required this.entersBoard,
    required this.entersHomePath,
    required this.finishesToken,
    required this.captures,
    required this.captureThreats,
    required this.landsSafe,
    required this.leavesSafety,
  });

  final int endProgress;
  final bool entersBoard;
  final bool entersHomePath;
  final bool finishesToken;
  final int captures;
  final int captureThreats;
  final bool landsSafe;
  final bool leavesSafety;
}
