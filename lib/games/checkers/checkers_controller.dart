import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'checkers_bot.dart';
import 'checkers_model.dart';

enum CheckersTapResult { selected, deselected, moved, ignored }

/// Owns board selection and shared match lifecycle around [CheckersModel].
class CheckersController extends ChangeNotifier {
  CheckersController({
    required this.session,
    CheckersModel? model,
    Random? random,
    this.botThinkDelay,
    this.botChainDelay,
  }) : _random = random ?? Random(),
       model = model ?? CheckersModel() {
    bot = session.options.mode == PlayMode.bot
        ? CheckersBot(
            difficulty: session.options.botDifficulty!,
            random: _random,
          )
        : null;
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final Random _random;
  final Duration? botThinkDelay;
  final Duration? botChainDelay;
  CheckersModel model;
  late final CheckersBot? bot;

  Timer? _botTimer;

  int? _selectedSquare;
  int? get selectedSquare => _selectedSquare;

  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get isBotTurn =>
      bot != null && !model.isFinished && model.currentPlayer == bot!.player;
  bool get isBotThinking => _botTimer?.isActive ?? false;
  bool get acceptsInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !model.isFinished &&
      !isBotTurn;

  List<CheckersMove> get selectedMoves => _selectedSquare == null
      ? const []
      : model.legalMovesFrom(_selectedSquare!);

  CheckersTapResult tapSquare(int square) {
    if (!acceptsInput || square < 0 || square >= CheckersModel.squareCount) {
      return CheckersTapResult.ignored;
    }

    final selected = _selectedSquare;
    if (selected != null) {
      for (final move in selectedMoves) {
        if (move.to != square) continue;
        final result = model.play(model.currentPlayer, move);
        if (result != CheckersMoveResult.accepted) {
          return CheckersTapResult.ignored;
        }
        _selectedSquare = model.forcedCaptureSquare;
        notifyListeners();
        if (model.isFinished) {
          _publishResult();
        } else {
          _scheduleBotTurn();
        }
        return CheckersTapResult.moved;
      }
      if (square == selected && model.forcedCaptureSquare == null) {
        _selectedSquare = null;
        notifyListeners();
        return CheckersTapResult.deselected;
      }
    }

    final piece = model.board[square];
    if (piece?.player == model.currentPlayer &&
        model.legalMovesFrom(square).isNotEmpty) {
      _selectedSquare = square;
      notifyListeners();
      return CheckersTapResult.selected;
    }
    return CheckersTapResult.ignored;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelBotTurn();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model = CheckersModel(startingPlayer: 1 - model.startingPlayer);
        } else {
          _hasStartedRound = true;
        }
        _selectedSquare = null;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelBotTurn();
    } else if (roundChanged || phaseChanged) {
      _scheduleBotTurn();
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _scheduleBotTurn() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !isBotTurn ||
        _botTimer != null) {
      return;
    }
    final continuingCapture = model.forcedCaptureSquare != null;
    final delay = continuingCapture
        ? botChainDelay ?? _naturalChainDelay()
        : botThinkDelay ?? _naturalThinkDelay();
    _selectedSquare = model.forcedCaptureSquare;
    _botTimer = Timer(delay, _performBotMove);
    notifyListeners();
  }

  Duration _naturalThinkDelay() {
    final (minimum, variation) = switch (session.options.botDifficulty!) {
      BotDifficulty.easy => (900, 500),
      BotDifficulty.normal => (650, 400),
      BotDifficulty.hard => (450, 300),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  Duration _naturalChainDelay() =>
      Duration(milliseconds: 320 + _random.nextInt(240));

  void _performBotMove() {
    _botTimer = null;
    if (_disposed || session.phase != MatchPhase.playing || !isBotTurn) return;
    final move = bot!.chooseMove(model);
    if (move == null) return;
    final result = model.play(bot!.player, move);
    if (result != CheckersMoveResult.accepted) return;

    _selectedSquare = model.forcedCaptureSquare;
    notifyListeners();
    if (model.isFinished) {
      _publishResult();
    } else {
      _scheduleBotTurn();
    }
  }

  void _cancelBotTurn() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  void _publishResult() {
    final winner = model.winner;
    if (winner != null) {
      session.reportNonPointResult(
        winner: winner,
        scores: winner == 0 ? const [1, 0] : const [0, 1],
        details:
            '${session.options.playerLabel(winner)} leaves the opponent with no legal move.',
      );
      return;
    }

    final reason = switch (model.drawReason) {
      CheckersDrawReason.threefoldRepetition =>
        'The same position occurred three times.',
      CheckersDrawReason.noProgress =>
        'Forty moves per player passed without a capture or promotion.',
      null => 'Neither player can force a result.',
    };
    session.reportNonPointResult(
      winner: null,
      scores: const [0, 0],
      details: reason,
    );
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelBotTurn();
    super.dispose();
  }
}
