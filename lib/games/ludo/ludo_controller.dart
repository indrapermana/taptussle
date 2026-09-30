import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'ludo_model.dart';

class LudoController extends ChangeNotifier {
  factory LudoController({
    required int playerCount,
    LudoDiceRoller? diceRoller,
    LudoModel? model,
    Duration movementStepDuration = const Duration(milliseconds: 150),
  }) {
    final resolvedModel =
        model ??
        LudoModel(
          playerCount: playerCount,
          diceRoller: diceRoller ?? _randomRoll,
        );
    return LudoController._(
      playerCount: playerCount,
      model: resolvedModel,
      movementStepDuration: movementStepDuration,
    );
  }

  LudoController._({
    required int playerCount,
    required this.model,
    required this.movementStepDuration,
  }) : _displayProgress = [
         for (final tokens in model.tokenProgress) List<int>.of(tokens),
       ] {
    if (model.playerCount != playerCount) {
      throw ArgumentError.value(
        playerCount,
        'playerCount',
        'Must match the supplied model',
      );
    }
  }

  final LudoModel model;
  final Duration movementStepDuration;
  final List<List<int>> _displayProgress;

  List<List<int>> get displayProgress => List.unmodifiable(
    _displayProgress.map((tokens) => List<int>.unmodifiable(tokens)),
  );

  bool get isAnimating => _movementTimer != null || _pendingProgress.isNotEmpty;
  bool get canRoll =>
      !_disposed && !isAnimating && model.phase == LudoTurnPhase.awaitingRoll;
  bool get canChooseToken =>
      !_disposed && !isAnimating && model.phase == LudoTurnPhase.awaitingMove;
  List<int> get legalTokenIndexes =>
      canChooseToken ? model.legalTokenIndexes : const [];

  int? _animationPlayer;
  int? get animationPlayer => _animationPlayer;
  int? _animationToken;
  int? get animationToken => _animationToken;
  final List<int> _pendingProgress = [];
  Timer? _movementTimer;
  bool _disposed = false;

  LudoRoll? roll() {
    if (!canRoll) return null;
    final result = model.rollDice();
    notifyListeners();
    return result;
  }

  LudoMoveResult chooseToken(int tokenIndex) {
    if (!canChooseToken) return LudoMoveResult.rollRequired;
    if (tokenIndex < 0 || tokenIndex >= LudoModel.tokensPerPlayer) {
      return LudoMoveResult.invalidToken;
    }
    final player = model.currentPlayer;
    final start = model.progressFor(player, tokenIndex);
    final result = model.moveToken(player, tokenIndex);
    if (result != LudoMoveResult.accepted) return result;

    final end = model.lastMove!.endProgress;
    _animationPlayer = player;
    _animationToken = tokenIndex;
    _pendingProgress
      ..clear()
      ..addAll(
        start == LudoModel.boxProgress
            ? [end]
            : [
                for (var progress = start + 1; progress <= end; progress++)
                  progress,
              ],
      );
    notifyListeners();

    if (_pendingProgress.isEmpty || movementStepDuration == Duration.zero) {
      _finishMovement();
    } else {
      _scheduleNextStep();
    }
    return result;
  }

  void _scheduleNextStep() {
    if (_disposed || _movementTimer != null || _pendingProgress.isEmpty) return;
    _movementTimer = Timer(movementStepDuration, () {
      _movementTimer = null;
      if (_disposed) return;
      _displayProgress[_animationPlayer!][_animationToken!] = _pendingProgress
          .removeAt(0);
      notifyListeners();
      if (_pendingProgress.isEmpty) {
        _finishMovement();
      } else {
        _scheduleNextStep();
      }
    });
  }

  void _finishMovement() {
    _movementTimer?.cancel();
    _movementTimer = null;
    _pendingProgress.clear();
    for (var player = 0; player < model.playerCount; player++) {
      for (var token = 0; token < LudoModel.tokensPerPlayer; token++) {
        _displayProgress[player][token] = model.progressFor(player, token);
      }
    }
    _animationPlayer = null;
    _animationToken = null;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _movementTimer?.cancel();
    _movementTimer = null;
    super.dispose();
  }

  static int _randomRoll() => Random().nextInt(6) + 1;
}
