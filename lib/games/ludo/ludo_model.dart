typedef LudoDiceRoller = int Function();

enum LudoTurnPhase { awaitingRoll, awaitingMove, finished }

enum LudoMoveResult {
  accepted,
  invalidPlayer,
  invalidToken,
  wrongTurn,
  rollRequired,
  illegalMove,
  matchFinished,
}

class LudoTokenRef {
  const LudoTokenRef(this.playerIndex, this.tokenIndex);

  final int playerIndex;
  final int tokenIndex;

  @override
  bool operator ==(Object other) =>
      other is LudoTokenRef &&
      other.playerIndex == playerIndex &&
      other.tokenIndex == tokenIndex;

  @override
  int get hashCode => Object.hash(playerIndex, tokenIndex);
}

class LudoRoll {
  const LudoRoll({
    required this.playerIndex,
    required this.value,
    required this.legalTokenIndexes,
    required this.bonusRoll,
    required this.nextPlayerIndex,
  });

  final int playerIndex;
  final int value;
  final List<int> legalTokenIndexes;

  /// True only when a six had no legal token and immediately grants a reroll.
  final bool bonusRoll;
  final int? nextPlayerIndex;

  bool get requiresTokenChoice => legalTokenIndexes.isNotEmpty;
}

class LudoMove {
  const LudoMove({
    required this.playerIndex,
    required this.tokenIndex,
    required this.roll,
    required this.startProgress,
    required this.endProgress,
    required this.capturedTokens,
    required this.bonusRoll,
    required this.completedPlayer,
    required this.nextPlayerIndex,
  });

  final int playerIndex;
  final int tokenIndex;
  final int roll;
  final int startProgress;
  final int endProgress;
  final List<LudoTokenRef> capturedTokens;
  final bool bonusRoll;
  final bool completedPlayer;
  final int? nextPlayerIndex;

  bool get enteredBoard => startProgress == LudoModel.boxProgress;
  bool get reachedFinalHome => endProgress == LudoModel.finishProgress;
  bool get wasCapture => capturedTokens.isNotEmpty;
}

/// Pure rules and turn state for a two-to-four-player Ludo match.
///
/// Each token uses progress relative to its owner: -1 is the starting box,
/// 0-51 are the shared track, 52-56 are the private home path, and 57 is the
/// final home position. This keeps movement independent from board rendering.
class LudoModel {
  LudoModel({
    required this.playerCount,
    required LudoDiceRoller diceRoller,
    this.startingPlayer = 0,
  }) : _diceRoller = diceRoller,
       _tokenProgress = List.generate(
         playerCount,
         (_) => List.filled(tokensPerPlayer, boxProgress),
       ) {
    _validatePlayerCount(playerCount);
    _validatePlayer(startingPlayer, playerCount, 'startingPlayer');
    _currentPlayer = startingPlayer;
  }

  /// Creates a validated position for saved-match restoration and rule tests.
  LudoModel.fromState({
    required this.playerCount,
    required LudoDiceRoller diceRoller,
    required List<List<int>> tokenProgress,
    this.startingPlayer = 0,
    int? currentPlayer,
    List<int> standings = const [],
  }) : _diceRoller = diceRoller,
       _tokenProgress = [for (final tokens in tokenProgress) List.of(tokens)],
       _standings = List.of(standings) {
    _validatePlayerCount(playerCount);
    _validatePlayer(startingPlayer, playerCount, 'startingPlayer');
    if (_tokenProgress.length != playerCount ||
        _tokenProgress.any((tokens) => tokens.length != tokensPerPlayer)) {
      throw ArgumentError.value(
        tokenProgress,
        'tokenProgress',
        'Must contain four tokens for every participant',
      );
    }
    for (final tokens in _tokenProgress) {
      for (final progress in tokens) {
        if (progress < boxProgress || progress > finishProgress) {
          throw ArgumentError.value(
            progress,
            'tokenProgress',
            'Must be between $boxProgress and $finishProgress',
          );
        }
      }
    }
    if (_standings.toSet().length != _standings.length ||
        _standings.any((player) => player < 0 || player >= playerCount)) {
      throw ArgumentError.value(
        standings,
        'standings',
        'Must contain unique participant indexes',
      );
    }
    for (final player in _standings) {
      if (!_tokenProgress[player].every((value) => value == finishProgress)) {
        throw ArgumentError.value(
          standings,
          'standings',
          'Ranked participants must have finished every token',
        );
      }
    }
    if (_standings.length >= playerCount - 1) {
      for (var player = 0; player < playerCount; player++) {
        if (!_standings.contains(player)) _standings.add(player);
      }
      _phase = LudoTurnPhase.finished;
      _currentPlayer = _standings.last;
    } else {
      final requestedPlayer = currentPlayer ?? startingPlayer;
      _validatePlayer(requestedPlayer, playerCount, 'currentPlayer');
      if (_standings.contains(requestedPlayer)) {
        throw ArgumentError.value(
          requestedPlayer,
          'currentPlayer',
          'A ranked participant cannot take another turn',
        );
      }
      _currentPlayer = requestedPlayer;
    }
  }

  static const int tokensPerPlayer = 4;
  static const int trackLength = 52;
  static const int homePathStart = 52;
  static const int finishProgress = 57;
  static const int boxProgress = -1;

  static const List<int> startTrackIndexes = [0, 13, 26, 39];
  static const Set<int> safeTrackIndexes = {0, 8, 13, 21, 26, 34, 39, 47};

  final int playerCount;
  final int startingPlayer;
  final LudoDiceRoller _diceRoller;
  final List<List<int>> _tokenProgress;
  List<int> _standings = [];

  late int _currentPlayer;
  int get currentPlayer => _currentPlayer;

  LudoTurnPhase _phase = LudoTurnPhase.awaitingRoll;
  LudoTurnPhase get phase => _phase;
  bool get isFinished => _phase == LudoTurnPhase.finished;

  int? _pendingRoll;
  int? get pendingRoll => _pendingRoll;

  LudoRoll? _lastRoll;
  LudoRoll? get lastRoll => _lastRoll;

  LudoMove? _lastMove;
  LudoMove? get lastMove => _lastMove;

  List<List<int>> get tokenProgress => List.unmodifiable(
    _tokenProgress.map((tokens) => List<int>.unmodifiable(tokens)),
  );

  List<int> get standings => List.unmodifiable(_standings);
  int? get winner => isFinished ? _standings.first : null;

  int progressFor(int playerIndex, int tokenIndex) {
    _validatePlayer(playerIndex, playerCount, 'playerIndex');
    _validateToken(tokenIndex);
    return _tokenProgress[playerIndex][tokenIndex];
  }

  bool isInBox(int playerIndex, int tokenIndex) =>
      progressFor(playerIndex, tokenIndex) == boxProgress;

  bool isAtFinalHome(int playerIndex, int tokenIndex) =>
      progressFor(playerIndex, tokenIndex) == finishProgress;

  /// Returns the shared-track index, or null for box/home-path/final tokens.
  int? trackIndexFor(int playerIndex, int tokenIndex) {
    final progress = progressFor(playerIndex, tokenIndex);
    if (progress < 0 || progress >= trackLength) return null;
    return (startTrackIndexes[playerIndex] + progress) % trackLength;
  }

  bool isSafeToken(int playerIndex, int tokenIndex) {
    final trackIndex = trackIndexFor(playerIndex, tokenIndex);
    return trackIndex != null && safeTrackIndexes.contains(trackIndex);
  }

  List<int> get legalTokenIndexes {
    final roll = _pendingRoll;
    if (isFinished || _phase != LudoTurnPhase.awaitingMove || roll == null) {
      return const [];
    }
    return _legalTokensFor(_currentPlayer, roll);
  }

  LudoRoll rollDice() {
    if (isFinished) throw StateError('The match has already finished');
    if (_phase != LudoTurnPhase.awaitingRoll) {
      throw StateError('A token must be moved before rolling again');
    }

    final player = _currentPlayer;
    final value = _diceRoller();
    if (value < 1 || value > 6) {
      throw StateError(
        'Dice roller returned $value; expected a value from 1 to 6',
      );
    }

    final legalTokens = _legalTokensFor(player, value);
    if (legalTokens.isNotEmpty) {
      _pendingRoll = value;
      _phase = LudoTurnPhase.awaitingMove;
      return _lastRoll = LudoRoll(
        playerIndex: player,
        value: value,
        legalTokenIndexes: legalTokens,
        bonusRoll: false,
        nextPlayerIndex: null,
      );
    }

    final bonusRoll = value == 6;
    if (!bonusRoll) _currentPlayer = _nextActivePlayer(player);
    return _lastRoll = LudoRoll(
      playerIndex: player,
      value: value,
      legalTokenIndexes: const [],
      bonusRoll: bonusRoll,
      nextPlayerIndex: _currentPlayer,
    );
  }

  LudoMoveResult moveToken(int playerIndex, int tokenIndex) {
    if (playerIndex < 0 || playerIndex >= playerCount) {
      return LudoMoveResult.invalidPlayer;
    }
    if (tokenIndex < 0 || tokenIndex >= tokensPerPlayer) {
      return LudoMoveResult.invalidToken;
    }
    if (isFinished) return LudoMoveResult.matchFinished;
    if (playerIndex != _currentPlayer) return LudoMoveResult.wrongTurn;
    final roll = _pendingRoll;
    if (_phase != LudoTurnPhase.awaitingMove || roll == null) {
      return LudoMoveResult.rollRequired;
    }
    if (!_isLegalProgress(_tokenProgress[playerIndex][tokenIndex], roll)) {
      return LudoMoveResult.illegalMove;
    }

    final start = _tokenProgress[playerIndex][tokenIndex];
    final end = start == boxProgress ? 0 : start + roll;
    _tokenProgress[playerIndex][tokenIndex] = end;

    final captured = <LudoTokenRef>[];
    final landingTrackIndex = trackIndexFor(playerIndex, tokenIndex);
    if (landingTrackIndex != null &&
        !safeTrackIndexes.contains(landingTrackIndex)) {
      for (var opponent = 0; opponent < playerCount; opponent++) {
        if (opponent == playerIndex) continue;
        for (
          var opponentToken = 0;
          opponentToken < tokensPerPlayer;
          opponentToken++
        ) {
          if (trackIndexFor(opponent, opponentToken) == landingTrackIndex) {
            _tokenProgress[opponent][opponentToken] = boxProgress;
            captured.add(LudoTokenRef(opponent, opponentToken));
          }
        }
      }
    }

    final completedPlayer = _tokenProgress[playerIndex].every(
      (progress) => progress == finishProgress,
    );
    if (completedPlayer && !_standings.contains(playerIndex)) {
      _standings.add(playerIndex);
    }

    _pendingRoll = null;
    final earnedBonus =
        roll == 6 || start == boxProgress || captured.isNotEmpty;
    int? nextPlayer;
    if (_standings.length >= playerCount - 1) {
      for (var player = 0; player < playerCount; player++) {
        if (!_standings.contains(player)) _standings.add(player);
      }
      _phase = LudoTurnPhase.finished;
    } else {
      if (!earnedBonus || completedPlayer) {
        _currentPlayer = _nextActivePlayer(playerIndex);
      }
      _phase = LudoTurnPhase.awaitingRoll;
      nextPlayer = _currentPlayer;
    }

    _lastMove = LudoMove(
      playerIndex: playerIndex,
      tokenIndex: tokenIndex,
      roll: roll,
      startProgress: start,
      endProgress: end,
      capturedTokens: List.unmodifiable(captured),
      bonusRoll: earnedBonus && !completedPlayer && !isFinished,
      completedPlayer: completedPlayer,
      nextPlayerIndex: nextPlayer,
    );
    return LudoMoveResult.accepted;
  }

  void reset() {
    for (final tokens in _tokenProgress) {
      tokens.fillRange(0, tokens.length, boxProgress);
    }
    _standings = [];
    _currentPlayer = startingPlayer;
    _phase = LudoTurnPhase.awaitingRoll;
    _pendingRoll = null;
    _lastRoll = null;
    _lastMove = null;
  }

  List<int> _legalTokensFor(int playerIndex, int roll) => List.unmodifiable([
    for (var token = 0; token < tokensPerPlayer; token++)
      if (_isLegalProgress(_tokenProgress[playerIndex][token], roll)) token,
  ]);

  static bool _isLegalProgress(int progress, int roll) {
    if (progress == boxProgress) return roll == 6;
    if (progress == finishProgress) return false;
    return progress + roll <= finishProgress;
  }

  int _nextActivePlayer(int afterPlayer) {
    for (var offset = 1; offset <= playerCount; offset++) {
      final candidate = (afterPlayer + offset) % playerCount;
      if (!_standings.contains(candidate)) return candidate;
    }
    throw StateError('No active Ludo participant remains');
  }

  static void _validatePlayerCount(int playerCount) {
    if (playerCount < 2 || playerCount > 4) {
      throw ArgumentError.value(playerCount, 'playerCount', 'Must be 2 to 4');
    }
  }

  static void _validatePlayer(int player, int count, String name) {
    if (player < 0 || player >= count) {
      throw ArgumentError.value(player, name, 'Must identify a participant');
    }
  }

  static void _validateToken(int token) {
    if (token < 0 || token >= tokensPerPlayer) {
      throw RangeError.range(token, 0, tokensPerPlayer - 1, 'tokenIndex');
    }
  }
}
