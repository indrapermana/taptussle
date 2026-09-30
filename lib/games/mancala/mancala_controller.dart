import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'mancala_bot.dart';
import 'mancala_model.dart';

enum MancalaTapResult { accepted, ignored }

/// Owns input, sowing presentation, and shared match lifecycle for Mancala.
class MancalaController extends ChangeNotifier {
  MancalaController({
    required this.session,
    MancalaModel? model,
    Random? random,
    this.botThinkDelay,
    this.sowingStepDuration = const Duration(milliseconds: 110),
    this.settleDuration = const Duration(milliseconds: 160),
  }) : _random = random ?? Random(),
       model = model ?? MancalaModel() {
    bot = session.options.mode == PlayMode.bot
        ? MancalaBot(
            difficulty: session.options.botDifficulty!,
            random: _random,
          )
        : null;
    _displayBoard = this.model.board;
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final Random _random;
  final Duration? botThinkDelay;
  final Duration sowingStepDuration;
  final Duration settleDuration;
  MancalaModel model;
  late final MancalaBot? bot;

  late List<int> _displayBoard;
  List<int> get displayBoard => List.unmodifiable(_displayBoard);

  Timer? _animationTimer;
  Timer? _botTimer;
  int? _activePosition;
  int? get activePosition => _activePosition;
  bool get isAnimating => _animationTimer != null;
  bool get isBotTurn =>
      bot != null && !model.isFinished && model.currentPlayer == bot!.player;
  bool get isBotThinking => _botTimer?.isActive ?? false;

  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _hasStartedRound = false;
  bool _disposed = false;

  bool get acceptsInput =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !model.isFinished &&
      !isAnimating &&
      !isBotTurn;

  MancalaTapResult tapPit(int player, int pit) {
    if (!acceptsInput || player != model.currentPlayer) {
      return MancalaTapResult.ignored;
    }

    return _startMove(player, pit);
  }

  MancalaTapResult _startMove(int player, int pit) {
    if (player < 0 ||
        player > 1 ||
        pit < 0 ||
        pit >= MancalaModel.pitsPerPlayer) {
      return MancalaTapResult.ignored;
    }
    final before = model.board;
    final source = model.boardPositionForPit(player, pit);
    final result = model.play(player, pit);
    if (result != MancalaMoveResult.accepted) {
      return MancalaTapResult.ignored;
    }

    _displayBoard = List.of(before)..[source] = 0;
    _activePosition = source;
    _animateSowing(model.lastTurn!.sowingPath, 0);
    notifyListeners();
    return MancalaTapResult.accepted;
  }

  void _animateSowing(List<int> path, int step) {
    if (step >= path.length) {
      _scheduleSettlement();
      return;
    }
    _animationTimer = Timer(sowingStepDuration, () {
      _animationTimer = null;
      if (_disposed) return;
      final position = path[step];
      _displayBoard[position]++;
      _activePosition = position;
      notifyListeners();
      if (step + 1 == path.length) {
        _scheduleSettlement();
      } else {
        _animateSowing(path, step + 1);
      }
    });
  }

  void _scheduleSettlement() {
    _animationTimer = Timer(settleDuration, () {
      _animationTimer = null;
      if (_disposed) return;
      _settleAnimation();
    });
  }

  void _settleAnimation({bool publishResult = true}) {
    _animationTimer?.cancel();
    _animationTimer = null;
    _activePosition = null;
    _displayBoard = model.board;
    notifyListeners();
    if (publishResult && model.isFinished) {
      _publishResult();
    } else if (publishResult) {
      _scheduleBotTurn();
    }
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelAnimation();
      _cancelBotTurn();
      _observedRound = session.round;
      if (session.round > 0) {
        if (_hasStartedRound) {
          model = MancalaModel(startingPlayer: 1 - model.startingPlayer);
        } else {
          _hasStartedRound = true;
        }
        _displayBoard = model.board;
        _activePosition = null;
      }
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _cancelBotTurn();
      if (isAnimating) _settleAnimation(publishResult: false);
    } else if (roundChanged || phaseChanged) {
      if (model.isFinished) {
        _publishResult();
      } else {
        _scheduleBotTurn();
      }
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _publishResult() {
    if (session.phase != MatchPhase.playing || !model.isFinished) return;
    final scores = [model.stonesInStore(0), model.stonesInStore(1)];
    final winner = model.winner;
    session.reportNonPointResult(
      winner: winner,
      scores: scores,
      details: winner == null
          ? 'Both stores hold ${scores[0]} stones. • Another round?'
          : '${session.options.playerLabel(winner)} collects the most stones. • Another round?',
    );
  }

  void _cancelAnimation() {
    _animationTimer?.cancel();
    _animationTimer = null;
  }

  void _scheduleBotTurn() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !isBotTurn ||
        isAnimating ||
        _botTimer != null) {
      return;
    }
    _botTimer = Timer(botThinkDelay ?? _naturalThinkDelay(), _performBotMove);
    notifyListeners();
  }

  Duration _naturalThinkDelay() {
    final (minimum, variation) = switch (session.options.botDifficulty!) {
      BotDifficulty.easy => (950, 550),
      BotDifficulty.normal => (700, 450),
      BotDifficulty.hard => (500, 350),
    };
    return Duration(milliseconds: minimum + _random.nextInt(variation));
  }

  void _performBotMove() {
    _botTimer = null;
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !isBotTurn ||
        isAnimating) {
      return;
    }
    final pit = bot!.choosePit(model);
    if (pit == null) return;
    _startMove(bot!.player, pit);
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
    _cancelAnimation();
    _cancelBotTurn();
    super.dispose();
  }
}
