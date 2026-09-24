import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'tic_tac_toe_bot.dart';
import 'tic_tac_toe_model.dart';

/// Owns match lifecycle and delayed bot turns for the pure Flutter board.
class TicTacToeController extends ChangeNotifier {
  TicTacToeController({
    required this.session,
    Random? random,
    this.botThinkDelay,
  }) : _random = random ?? Random(),
       model = TicTacToeModel() {
    bot = session.options.mode == PlayMode.bot
        ? TicTacToeBot(
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
  final TicTacToeModel model;
  late final TicTacToeBot? bot;

  Timer? _botTimer;
  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get isBotTurn =>
      bot != null && !model.isFinished && model.currentPlayer == bot!.player;
  bool get isBotThinking => _botTimer?.isActive ?? false;
  bool get acceptsHumanInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !model.isFinished &&
      !isBotTurn;

  TicTacToeMoveResult humanMove(int cell) {
    if (!acceptsHumanInput) return TicTacToeMoveResult.wrongTurn;
    final player = session.options.mode == PlayMode.bot
        ? 0
        : model.currentPlayer;
    final result = model.play(player, cell);
    if (result != TicTacToeMoveResult.accepted) return result;

    notifyListeners();
    if (model.isFinished) {
      _publishResult();
    } else {
      _scheduleBotTurn();
    }
    return result;
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelBotTurn();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model.startRematch();
        } else {
          model.reset();
          _hasStartedRound = true;
        }
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
    _botTimer = Timer(botThinkDelay ?? _naturalThinkDelay(), _performBotMove);
    notifyListeners();
  }

  Duration _naturalThinkDelay() {
    final difficulty = session.options.botDifficulty!;
    final (minimum, variation) = switch (difficulty) {
      BotDifficulty.easy => (850, 450),
      BotDifficulty.normal => (600, 350),
      BotDifficulty.hard => (400, 250),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  void _performBotMove() {
    _botTimer = null;
    if (_disposed || session.phase != MatchPhase.playing || !isBotTurn) return;
    final move = bot!.chooseMove(model);
    if (move == null) return;
    final result = model.play(bot!.player, move);
    if (result != TicTacToeMoveResult.accepted) return;

    notifyListeners();
    if (model.isFinished) _publishResult();
  }

  void _publishResult() {
    final winner = model.winner;
    final scores = winner == null
        ? const [0, 0]
        : winner == 0
        ? const [1, 0]
        : const [0, 1];
    session.reportNonPointResult(
      winner: winner,
      scores: scores,
      details: winner == null
          ? 'The board is full with no winning line. • Another round?'
          : '${session.options.playerLabel(winner)} completed three in a row. • Another round?',
    );
  }

  void _cancelBotTurn() {
    _botTimer?.cancel();
    _botTimer = null;
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
