import 'dart:math';

import '../../core/match_options.dart';
import 'mancala_model.dart';

/// Bounded alpha-beta search for the Mancala bot participant.
class MancalaBot {
  MancalaBot({
    required this.difficulty,
    this.player = 1,
    Random? random,
    int? searchDepth,
    int? nodeBudget,
    double? mistakeChance,
  }) : assert(player == 0 || player == 1),
       _random = random ?? Random(),
       searchDepth = searchDepth ?? _profileFor(difficulty).depth,
       nodeBudget = nodeBudget ?? _profileFor(difficulty).nodes,
       mistakeChance = mistakeChance ?? _profileFor(difficulty).mistake {
    if (this.searchDepth < 0) {
      throw ArgumentError.value(this.searchDepth, 'searchDepth');
    }
    if (this.nodeBudget < 1) {
      throw ArgumentError.value(this.nodeBudget, 'nodeBudget');
    }
    if (this.mistakeChance < 0 || this.mistakeChance > 1) {
      throw ArgumentError.value(this.mistakeChance, 'mistakeChance');
    }
  }

  final BotDifficulty difficulty;
  final int player;
  final int searchDepth;
  final int nodeBudget;
  final double mistakeChance;
  final Random _random;

  int _searchedNodes = 0;
  int get searchedNodes => _searchedNodes;

  int? choosePit(MancalaModel model) {
    _searchedNodes = 0;
    if (model.isFinished || model.currentPlayer != player) return null;
    final legal = model.legalPitsFor(player);
    if (legal.isEmpty) return null;
    if (difficulty == BotDifficulty.easy ||
        _random.nextDouble() < mistakeChance) {
      return legal[_random.nextInt(legal.length)];
    }

    var bestScore = -_infinity;
    final bestPits = <int>[];
    for (final pit in _orderedPits(model, legal)) {
      if (_searchedNodes >= nodeBudget) break;
      final child = MancalaModel.copy(model)..play(player, pit);
      final score = _search(
        child,
        remainingDepth: searchDepth - 1,
        alpha: -_infinity,
        beta: _infinity,
      );
      if (score > bestScore) {
        bestScore = score;
        bestPits
          ..clear()
          ..add(pit);
      } else if (score == bestScore) {
        bestPits.add(pit);
      }
    }
    if (bestPits.isEmpty) return legal.first;
    return bestPits[_random.nextInt(bestPits.length)];
  }

  int _search(
    MancalaModel model, {
    required int remainingDepth,
    required int alpha,
    required int beta,
  }) {
    _searchedNodes++;
    if (model.isFinished ||
        remainingDepth <= 0 ||
        _searchedNodes >= nodeBudget) {
      return _evaluate(model);
    }

    final maximizing = model.currentPlayer == player;
    var best = maximizing ? -_infinity : _infinity;
    var lower = alpha;
    var upper = beta;
    for (final pit in _orderedPits(
      model,
      model.legalPitsFor(model.currentPlayer),
    )) {
      if (_searchedNodes >= nodeBudget) break;
      final child = MancalaModel.copy(model)..play(model.currentPlayer, pit);
      final score = _search(
        child,
        remainingDepth: remainingDepth - 1,
        alpha: lower,
        beta: upper,
      );
      if (maximizing) {
        best = max(best, score);
        lower = max(lower, best);
      } else {
        best = min(best, score);
        upper = min(upper, best);
      }
      if (upper <= lower) break;
    }
    return best == -_infinity || best == _infinity ? _evaluate(model) : best;
  }

  int _evaluate(MancalaModel model) {
    if (model.winner == player) {
      return _winningScore + _storeDifference(model);
    }
    if (model.winner == 1 - player) {
      return -_winningScore + _storeDifference(model);
    }
    if (model.isDraw) return 0;

    final storeDifference = _storeDifference(model);
    final sideDifference =
        _sideStones(model, player) - _sideStones(model, 1 - player);
    if (difficulty != BotDifficulty.hard) {
      return storeDifference * 100 + sideDifference * 2;
    }

    final mobility =
        (model.currentPlayer == player ? 1 : -1) *
        model.legalPitsFor(model.currentPlayer).length;
    return storeDifference * 120 + sideDifference * 4 + mobility;
  }

  int _storeDifference(MancalaModel model) =>
      model.stonesInStore(player) - model.stonesInStore(1 - player);

  int _sideStones(MancalaModel model, int owner) => List.generate(
    MancalaModel.pitsPerPlayer,
    (pit) => model.stonesInPit(owner, pit),
  ).fold(0, (total, stones) => total + stones);

  List<int> _orderedPits(MancalaModel model, List<int> pits) {
    final ordered = List<int>.of(pits);
    ordered.sort((left, right) {
      final leftScore = _moveOrderScore(model, left);
      final rightScore = _moveOrderScore(model, right);
      final scoreOrder = rightScore.compareTo(leftScore);
      return scoreOrder != 0 ? scoreOrder : left.compareTo(right);
    });
    return ordered;
  }

  int _moveOrderScore(MancalaModel model, int pit) {
    final movingPlayer = model.currentPlayer;
    final beforeStore = model.stonesInStore(movingPlayer);
    final child = MancalaModel.copy(model)..play(movingPlayer, pit);
    final turn = child.lastTurn!;
    return (child.winner == movingPlayer ? 10000 : 0) +
        (turn.extraTurn ? 1000 : 0) +
        turn.capturedStones * 100 +
        (child.stonesInStore(movingPlayer) - beforeStore) * 10;
  }

  static ({int depth, int nodes, double mistake}) _profileFor(
    BotDifficulty difficulty,
  ) => switch (difficulty) {
    BotDifficulty.easy => (depth: 0, nodes: 1, mistake: 1),
    BotDifficulty.normal => (depth: 3, nodes: 2200, mistake: .16),
    BotDifficulty.hard => (depth: 7, nodes: 12000, mistake: 0),
  };

  static const int _winningScore = 100000;
  static const int _infinity = 1000000;
}
