enum CheckersPieceKind { man, king }

enum CheckersOutcome { playerOneWin, playerTwoWin, draw }

enum CheckersDrawReason { threefoldRepetition, noProgress }

enum CheckersMoveResult {
  accepted,
  invalidPlayer,
  outOfBounds,
  emptySource,
  wrongOwner,
  illegalMove,
  matchFinished,
}

class CheckersPiece {
  const CheckersPiece({required this.player, this.kind = CheckersPieceKind.man})
    : assert(player == 0 || player == 1);

  final int player;
  final CheckersPieceKind kind;

  bool get isKing => kind == CheckersPieceKind.king;

  CheckersPiece crowned() =>
      CheckersPiece(player: player, kind: CheckersPieceKind.king);

  @override
  bool operator ==(Object other) =>
      other is CheckersPiece && player == other.player && kind == other.kind;

  @override
  int get hashCode => Object.hash(player, kind);
}

class CheckersMove {
  const CheckersMove({required this.from, required this.to, this.captured});

  final int from;
  final int to;
  final int? captured;

  bool get isCapture => captured != null;

  @override
  bool operator ==(Object other) =>
      other is CheckersMove &&
      from == other.from &&
      to == other.to &&
      captured == other.captured;

  @override
  int get hashCode => Object.hash(from, to, captured);

  @override
  String toString() => 'CheckersMove($from -> $to, captured: $captured)';
}

/// Pure American/English checkers rules for a two-player match.
///
/// Player 1 starts on rows 5–7 and moves toward row 0. Player 2 starts on rows
/// 0–2 and moves toward row 7. A capture chain is represented by consecutive
/// calls to [play], with [forcedCaptureSquare] identifying the only piece that
/// may continue. Under American rules, crowning ends the current turn.
class CheckersModel {
  CheckersModel({
    int startingPlayer = 0,
    int maximumNonProgressPlies = defaultMaximumNonProgressPlies,
  }) : this.fromBoard(
         board: _initialBoard(),
         currentPlayer: startingPlayer,
         startingPlayer: startingPlayer,
         maximumNonProgressPlies: maximumNonProgressPlies,
       );

  CheckersModel.fromBoard({
    required Map<int, CheckersPiece> board,
    this.currentPlayer = 0,
    int? startingPlayer,
    this.maximumNonProgressPlies = defaultMaximumNonProgressPlies,
    int nonProgressPlies = 0,
  }) : startingPlayer = startingPlayer ?? currentPlayer,
       _board = List<CheckersPiece?>.filled(squareCount, null),
       _nonProgressPlies = nonProgressPlies {
    _validatePlayer(currentPlayer, 'currentPlayer');
    _validatePlayer(this.startingPlayer, 'startingPlayer');
    if (maximumNonProgressPlies < 1) {
      throw ArgumentError.value(
        maximumNonProgressPlies,
        'maximumNonProgressPlies',
        'Must be positive',
      );
    }
    if (nonProgressPlies < 0) {
      throw ArgumentError.value(
        nonProgressPlies,
        'nonProgressPlies',
        'Cannot be negative',
      );
    }
    for (final entry in board.entries) {
      if (!_isBoardSquare(entry.key) || !isPlayableSquare(entry.key)) {
        throw ArgumentError.value(
          entry.key,
          'board',
          'Invalid playable square',
        );
      }
      _board[entry.key] = entry.value;
    }
    _recordPosition();
    _resolvePositionWithoutMove();
  }

  CheckersModel.copy(CheckersModel other)
    : startingPlayer = other.startingPlayer,
      maximumNonProgressPlies = other.maximumNonProgressPlies,
      currentPlayer = other.currentPlayer,
      _board = List.of(other._board),
      _nonProgressPlies = other._nonProgressPlies,
      _forcedCaptureSquare = other._forcedCaptureSquare,
      _outcome = other._outcome,
      _drawReason = other._drawReason {
    _positionOccurrences.addAll(other._positionOccurrences);
  }

  static const int boardSize = 8;
  static const int squareCount = boardSize * boardSize;

  /// Forty moves per player without a capture or promotion.
  static const int defaultMaximumNonProgressPlies = 80;

  final int startingPlayer;
  final int maximumNonProgressPlies;
  final List<CheckersPiece?> _board;
  final Map<String, int> _positionOccurrences = {};

  List<CheckersPiece?> get board => List.unmodifiable(_board);

  int currentPlayer;

  int? _forcedCaptureSquare;
  int? get forcedCaptureSquare => _forcedCaptureSquare;

  int _nonProgressPlies;
  int get nonProgressPlies => _nonProgressPlies;

  CheckersOutcome? _outcome;
  CheckersOutcome? get outcome => _outcome;

  CheckersDrawReason? _drawReason;
  CheckersDrawReason? get drawReason => _drawReason;

  bool get isFinished => _outcome != null;
  bool get isDraw => _outcome == CheckersOutcome.draw;
  int? get winner => switch (_outcome) {
    CheckersOutcome.playerOneWin => 0,
    CheckersOutcome.playerTwoWin => 1,
    CheckersOutcome.draw || null => null,
  };

  int pieceCount(int player) {
    _validatePlayer(player, 'player');
    return _board.where((piece) => piece?.player == player).length;
  }

  List<CheckersMove> get legalMoves {
    if (isFinished) return const [];
    if (_forcedCaptureSquare case final square?) {
      return List.unmodifiable(_capturesFrom(square));
    }

    final captures = <CheckersMove>[];
    for (var square = 0; square < squareCount; square++) {
      if (_board[square]?.player == currentPlayer) {
        captures.addAll(_capturesFrom(square));
      }
    }
    if (captures.isNotEmpty) return List.unmodifiable(captures);

    final moves = <CheckersMove>[];
    for (var square = 0; square < squareCount; square++) {
      if (_board[square]?.player == currentPlayer) {
        moves.addAll(_quietMovesFrom(square));
      }
    }
    return List.unmodifiable(moves);
  }

  List<CheckersMove> legalMovesFrom(int square) {
    if (!_isBoardSquare(square)) return const [];
    return List.unmodifiable(legalMoves.where((move) => move.from == square));
  }

  CheckersMoveResult play(int player, CheckersMove requestedMove) {
    if (player < 0 || player > 1) return CheckersMoveResult.invalidPlayer;
    if (!_isBoardSquare(requestedMove.from) ||
        !_isBoardSquare(requestedMove.to)) {
      return CheckersMoveResult.outOfBounds;
    }
    if (isFinished) return CheckersMoveResult.matchFinished;
    if (player != currentPlayer) return CheckersMoveResult.wrongOwner;

    final piece = _board[requestedMove.from];
    if (piece == null) return CheckersMoveResult.emptySource;
    if (piece.player != player) return CheckersMoveResult.wrongOwner;

    CheckersMove? move;
    for (final candidate in legalMoves) {
      if (candidate.from == requestedMove.from &&
          candidate.to == requestedMove.to) {
        move = candidate;
        break;
      }
    }
    if (move == null) return CheckersMoveResult.illegalMove;

    _board[move.from] = null;
    if (move.captured case final captured?) _board[captured] = null;

    final destinationRow = rowOf(move.to);
    final promoted =
        !piece.isKing &&
        ((player == 0 && destinationRow == 0) ||
            (player == 1 && destinationRow == boardSize - 1));
    _board[move.to] = promoted ? piece.crowned() : piece;

    if (move.isCapture || promoted) {
      _nonProgressPlies = 0;
    }

    if (pieceCount(1 - player) == 0) {
      _finishWithWinner(player);
      return CheckersMoveResult.accepted;
    }

    if (move.isCapture && !promoted && _capturesFrom(move.to).isNotEmpty) {
      _forcedCaptureSquare = move.to;
      return CheckersMoveResult.accepted;
    }

    if (!move.isCapture && !promoted) _nonProgressPlies++;
    _forcedCaptureSquare = null;
    currentPlayer = 1 - currentPlayer;

    if (_movesForCurrentPosition().isEmpty) {
      _finishWithWinner(player);
      return CheckersMoveResult.accepted;
    }
    if (_nonProgressPlies >= maximumNonProgressPlies) {
      _finishDraw(CheckersDrawReason.noProgress);
      return CheckersMoveResult.accepted;
    }
    if (_recordPosition() >= 3) {
      _finishDraw(CheckersDrawReason.threefoldRepetition);
    }
    return CheckersMoveResult.accepted;
  }

  static int square(int row, int column) {
    if (row < 0 || row >= boardSize || column < 0 || column >= boardSize) {
      throw RangeError('Row and column must be between 0 and 7');
    }
    return row * boardSize + column;
  }

  static int rowOf(int square) => square ~/ boardSize;
  static int columnOf(int square) => square % boardSize;
  static bool isPlayableSquare(int square) =>
      _isBoardSquare(square) && (rowOf(square) + columnOf(square)).isOdd;

  List<CheckersMove> _movesForCurrentPosition() {
    final captures = <CheckersMove>[];
    final quietMoves = <CheckersMove>[];
    for (var square = 0; square < squareCount; square++) {
      if (_board[square]?.player != currentPlayer) continue;
      captures.addAll(_capturesFrom(square));
      quietMoves.addAll(_quietMovesFrom(square));
    }
    return captures.isNotEmpty ? captures : quietMoves;
  }

  List<CheckersMove> _quietMovesFrom(int from) {
    final piece = _board[from];
    if (piece == null) return const [];
    final moves = <CheckersMove>[];
    for (final direction in _directionsFor(piece)) {
      final to = _offset(from, direction.$1, direction.$2);
      if (to != null && _board[to] == null) {
        moves.add(CheckersMove(from: from, to: to));
      }
    }
    return moves;
  }

  List<CheckersMove> _capturesFrom(int from) {
    final piece = _board[from];
    if (piece == null) return const [];
    final captures = <CheckersMove>[];
    for (final direction in _directionsFor(piece)) {
      final jumped = _offset(from, direction.$1, direction.$2);
      final to = _offset(from, direction.$1 * 2, direction.$2 * 2);
      if (jumped != null &&
          to != null &&
          _board[jumped]?.player == 1 - piece.player &&
          _board[to] == null) {
        captures.add(CheckersMove(from: from, to: to, captured: jumped));
      }
    }
    return captures;
  }

  static List<(int, int)> _directionsFor(CheckersPiece piece) {
    if (piece.isKing) return const [(-1, -1), (-1, 1), (1, -1), (1, 1)];
    return piece.player == 0
        ? const [(-1, -1), (-1, 1)]
        : const [(1, -1), (1, 1)];
  }

  static int? _offset(int square, int rowDelta, int columnDelta) {
    final row = rowOf(square) + rowDelta;
    final column = columnOf(square) + columnDelta;
    if (row < 0 || row >= boardSize || column < 0 || column >= boardSize) {
      return null;
    }
    return CheckersModel.square(row, column);
  }

  void _resolvePositionWithoutMove() {
    final currentCount = pieceCount(currentPlayer);
    final opponentCount = pieceCount(1 - currentPlayer);
    if (currentCount == 0) {
      _finishWithWinner(1 - currentPlayer);
    } else if (opponentCount == 0 || _movesForCurrentPosition().isEmpty) {
      _finishWithWinner(opponentCount == 0 ? currentPlayer : 1 - currentPlayer);
    }
  }

  void _finishWithWinner(int player) {
    _outcome = player == 0
        ? CheckersOutcome.playerOneWin
        : CheckersOutcome.playerTwoWin;
    _forcedCaptureSquare = null;
  }

  void _finishDraw(CheckersDrawReason reason) {
    _outcome = CheckersOutcome.draw;
    _drawReason = reason;
    _forcedCaptureSquare = null;
  }

  int _recordPosition() {
    final signature = StringBuffer('$currentPlayer:');
    for (final piece in _board) {
      signature.write(switch (piece) {
        null => '.',
        CheckersPiece(player: 0, kind: CheckersPieceKind.man) => 'a',
        CheckersPiece(player: 0, kind: CheckersPieceKind.king) => 'A',
        CheckersPiece(player: 1, kind: CheckersPieceKind.man) => 'b',
        CheckersPiece(player: 1, kind: CheckersPieceKind.king) => 'B',
        _ => throw StateError('Unsupported checkers piece'),
      });
    }
    final key = signature.toString();
    return _positionOccurrences.update(
      key,
      (count) => count + 1,
      ifAbsent: () => 1,
    );
  }

  static Map<int, CheckersPiece> _initialBoard() => {
    for (var row = 0; row < 3; row++)
      for (var column = 0; column < boardSize; column++)
        if ((row + column).isOdd)
          square(row, column): const CheckersPiece(player: 1),
    for (var row = 5; row < boardSize; row++)
      for (var column = 0; column < boardSize; column++)
        if ((row + column).isOdd)
          square(row, column): const CheckersPiece(player: 0),
  };

  static bool _isBoardSquare(int square) => square >= 0 && square < squareCount;

  static void _validatePlayer(int player, String name) {
    if (player < 0 || player > 1) {
      throw ArgumentError.value(player, name, 'Must be player 0 or 1');
    }
  }
}
