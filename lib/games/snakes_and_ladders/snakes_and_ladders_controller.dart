import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/match_session.dart';
import 'snakes_and_ladders_model.dart';

class SnakesAndLaddersController extends ChangeNotifier {
  SnakesAndLaddersController({
    required this.session,
    DiceRoller? diceRoller,
    Map<int, int> transitions = SnakesAndLaddersModel.standardTransitions,
    this.movementStepDuration = const Duration(milliseconds: 110),
    this.botRollDelay,
    Random? random,
  }) : model = SnakesAndLaddersModel(
         playerCount: session.options.participants.length,
         diceRoller: diceRoller ?? _randomRoll,
         transitions: transitions,
       ),
       _displayPositions = List.filled(session.options.participants.length, 0),
       _random = random ?? Random() {
    session.addListener(_syncSession);
    _syncSession();
  }

  final MatchSession session;
  final Duration movementStepDuration;
  final Duration? botRollDelay;
  final SnakesAndLaddersModel model;
  final List<int> _displayPositions;
  final Random _random;

  List<int> get displayPositions => List.unmodifiable(_displayPositions);
  bool get isAnimating => _animationPlayer != null;
  bool get isBotTurn =>
      !model.isFinished &&
      session.options.participants[model.currentPlayer].isBot;
  bool get isBotThinking => _botTimer?.isActive ?? false;
  int get highlightedPlayer => _animationPlayer ?? model.currentPlayer;
  bool get canRoll =>
      !_disposed &&
      session.phase == MatchPhase.playing &&
      !model.isFinished &&
      !isAnimating &&
      !isBotTurn &&
      !isBotThinking;

  int? _lastRoll;
  int? get lastRoll => _lastRoll;

  SnakesAndLaddersTurn? _animatingTurn;
  SnakesAndLaddersTurn? get animatingTurn => _animatingTurn;
  int? _animationPlayer;
  final List<int> _pendingSquares = [];
  Timer? _movementTimer;
  Timer? _botTimer;
  int _observedRound = 0;
  MatchPhase _observedPhase = MatchPhase.ready;
  bool _disposed = false;

  SnakesAndLaddersTurn? roll() {
    if (!canRoll) return null;
    return _rollCurrentTurn();
  }

  SnakesAndLaddersTurn _rollCurrentTurn() {
    final turn = model.rollTurn();
    _lastRoll = turn.roll;
    _animatingTurn = turn;
    _animationPlayer = turn.playerIndex;
    _pendingSquares
      ..clear()
      ..addAll(_movementPath(turn));
    notifyListeners();

    if (_pendingSquares.isEmpty) {
      _finishMovement();
    } else {
      _scheduleNextStep();
    }
    return turn;
  }

  List<int> _movementPath(SnakesAndLaddersTurn turn) {
    if (!turn.moved) return const [];
    final path = <int>[
      for (
        var square = turn.startSquare + 1;
        square <= turn.attemptedSquare;
        square++
      )
        square,
    ];
    if (turn.endSquare != turn.attemptedSquare) path.add(turn.endSquare);
    return path;
  }

  void _scheduleNextStep() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        _movementTimer != null ||
        _pendingSquares.isEmpty) {
      return;
    }
    _movementTimer = Timer(movementStepDuration, () {
      _movementTimer = null;
      if (_disposed || session.phase != MatchPhase.playing) return;
      _displayPositions[_animationPlayer!] = _pendingSquares.removeAt(0);
      notifyListeners();
      if (_pendingSquares.isEmpty) {
        _finishMovement();
      } else {
        _scheduleNextStep();
      }
    });
  }

  void _finishMovement() {
    final turn = _animatingTurn!;
    _displayPositions[turn.playerIndex] = turn.endSquare;
    _animationPlayer = null;
    _animatingTurn = null;
    notifyListeners();
    if (turn.won) {
      _publishResult(turn.playerIndex);
    } else {
      _scheduleBotRoll();
    }
  }

  void _scheduleBotRoll() {
    if (_disposed ||
        session.phase != MatchPhase.playing ||
        !isBotTurn ||
        isAnimating ||
        _botTimer != null) {
      return;
    }
    final delay =
        botRollDelay ?? Duration(milliseconds: 750 + _random.nextInt(451));
    _botTimer = Timer(delay, () {
      _botTimer = null;
      if (_disposed ||
          session.phase != MatchPhase.playing ||
          !isBotTurn ||
          isAnimating) {
        return;
      }
      _rollCurrentTurn();
    });
    notifyListeners();
  }

  void _publishResult(int winner) {
    final standings = List<int>.generate(model.playerCount, (index) => index)
      ..sort((left, right) {
        if (left == winner) return -1;
        if (right == winner) return 1;
        final byPosition = model.positions[right].compareTo(
          model.positions[left],
        );
        return byPosition != 0 ? byPosition : left.compareTo(right);
      });
    session.reportNonPointResult(
      winner: winner,
      scores: model.positions,
      standings: standings,
      details:
          '${standings.indexed.map((entry) => '${entry.$1 + 1}. ${session.options.playerLabel(entry.$2)}').join('  •  ')}  •  Another race?',
    );
  }

  void _syncSession() {
    if (_disposed) return;
    final roundChanged = session.round != _observedRound;
    if (roundChanged) {
      _cancelMovement(clearPath: true);
      _cancelBotRoll();
      _observedRound = session.round;
      model.reset();
      _displayPositions.fillRange(0, _displayPositions.length, 0);
      _lastRoll = null;
    }

    final phaseChanged = session.phase != _observedPhase;
    _observedPhase = session.phase;
    if (session.phase != MatchPhase.playing) {
      _movementTimer?.cancel();
      _movementTimer = null;
      _cancelBotRoll();
    } else if (phaseChanged || roundChanged) {
      if (_pendingSquares.isNotEmpty) {
        _scheduleNextStep();
      } else {
        _scheduleBotRoll();
      }
    }
    if (roundChanged || phaseChanged) notifyListeners();
  }

  void _cancelMovement({required bool clearPath}) {
    _movementTimer?.cancel();
    _movementTimer = null;
    if (!clearPath) return;
    _pendingSquares.clear();
    _animationPlayer = null;
    _animatingTurn = null;
  }

  void _cancelBotRoll() {
    _botTimer?.cancel();
    _botTimer = null;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    session.removeListener(_syncSession);
    _cancelMovement(clearPath: true);
    _cancelBotRoll();
    super.dispose();
  }

  static int _randomRoll() => Random().nextInt(6) + 1;
}
