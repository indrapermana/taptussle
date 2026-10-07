enum ChessColor {
  white,
  black;

  ChessColor get opposite => this == white ? black : white;
}

enum ChessPieceType { king, queen, rook, bishop, knight, pawn }

enum ChessOutcome { whiteWin, blackWin, draw }

enum ChessDrawReason {
  stalemate,
  insufficientMaterial,
  threefoldRepetition,
  fiftyMoveRule,
}

enum ChessMoveStatus { accepted, illegalMove, matchFinished }

class ChessPiece {
  const ChessPiece(this.color, this.type);

  final ChessColor color;
  final ChessPieceType type;

  @override
  bool operator ==(Object other) =>
      other is ChessPiece && other.color == color && other.type == type;

  @override
  int get hashCode => Object.hash(color, type);
}

class ChessMove {
  const ChessMove({required this.from, required this.to, this.promotion});

  final int from;
  final int to;
  final ChessPieceType? promotion;

  @override
  bool operator ==(Object other) =>
      other is ChessMove &&
      other.from == from &&
      other.to == to &&
      other.promotion == promotion;

  @override
  int get hashCode => Object.hash(from, to, promotion);

  @override
  String toString() =>
      'ChessMove(${ChessModel.squareName(from)} -> ${ChessModel.squareName(to)}${promotion == null ? '' : '=${promotion!.name}'})';
}

class ChessCastlingRights {
  const ChessCastlingRights({
    this.whiteKingSide = false,
    this.whiteQueenSide = false,
    this.blackKingSide = false,
    this.blackQueenSide = false,
  });

  const ChessCastlingRights.initial()
    : whiteKingSide = true,
      whiteQueenSide = true,
      blackKingSide = true,
      blackQueenSide = true;

  final bool whiteKingSide;
  final bool whiteQueenSide;
  final bool blackKingSide;
  final bool blackQueenSide;

  bool kingSide(ChessColor color) =>
      color == ChessColor.white ? whiteKingSide : blackKingSide;

  bool queenSide(ChessColor color) =>
      color == ChessColor.white ? whiteQueenSide : blackQueenSide;

  ChessCastlingRights copyWith({
    bool? whiteKingSide,
    bool? whiteQueenSide,
    bool? blackKingSide,
    bool? blackQueenSide,
  }) => ChessCastlingRights(
    whiteKingSide: whiteKingSide ?? this.whiteKingSide,
    whiteQueenSide: whiteQueenSide ?? this.whiteQueenSide,
    blackKingSide: blackKingSide ?? this.blackKingSide,
    blackQueenSide: blackQueenSide ?? this.blackQueenSide,
  );

  @override
  bool operator ==(Object other) =>
      other is ChessCastlingRights &&
      other.whiteKingSide == whiteKingSide &&
      other.whiteQueenSide == whiteQueenSide &&
      other.blackKingSide == blackKingSide &&
      other.blackQueenSide == blackQueenSide;

  @override
  int get hashCode =>
      Object.hash(whiteKingSide, whiteQueenSide, blackKingSide, blackQueenSide);
}

class ChessMoveRecord {
  const ChessMoveRecord({
    required this.move,
    required this.piece,
    required this.notation,
    required this.fullmoveNumber,
    this.capturedPiece,
    this.wasEnPassant = false,
    this.wasCastling = false,
  });

  final ChessMove move;
  final ChessPiece piece;
  final ChessPiece? capturedPiece;
  final String notation;
  final int fullmoveNumber;
  final bool wasEnPassant;
  final bool wasCastling;
}

class ChessMoveResult {
  const ChessMoveResult({
    required this.status,
    required this.model,
    this.record,
  });

  final ChessMoveStatus status;
  final ChessModel model;
  final ChessMoveRecord? record;

  bool get accepted => status == ChessMoveStatus.accepted;
}

class _ChessAppliedMove {
  const _ChessAppliedMove({
    required this.model,
    required this.movingPiece,
    required this.capturedPiece,
    required this.wasEnPassant,
    required this.wasCastling,
  });

  final ChessModel model;
  final ChessPiece movingPiece;
  final ChessPiece? capturedPiece;
  final bool wasEnPassant;
  final bool wasCastling;
}

/// Immutable standard chess rules with no clock or platform dependencies.
///
/// Squares use `a1 = 0` through `h8 = 63`. [play] returns a new model and never
/// mutates the current position, which makes the same rule layer safe for UI,
/// restoration, tests, and later bounded bot search.
class ChessModel {
  factory ChessModel() => ChessModel._create(
    board: _initialBoard(),
    sideToMove: ChessColor.white,
    castlingRights: const ChessCastlingRights.initial(),
    enPassantTarget: null,
    halfmoveClock: 0,
    fullmoveNumber: 1,
    history: const [],
    positionOccurrences: const {},
    resolveOutcome: true,
  );

  factory ChessModel.fromState({
    required Map<int, ChessPiece> board,
    ChessColor sideToMove = ChessColor.white,
    ChessCastlingRights castlingRights = const ChessCastlingRights(),
    int? enPassantTarget,
    int halfmoveClock = 0,
    int fullmoveNumber = 1,
    List<ChessMoveRecord> history = const [],
    Map<String, int> positionOccurrences = const {},
  }) => ChessModel._create(
    board: _boardFromMap(board),
    sideToMove: sideToMove,
    castlingRights: castlingRights,
    enPassantTarget: enPassantTarget,
    halfmoveClock: halfmoveClock,
    fullmoveNumber: fullmoveNumber,
    history: history,
    positionOccurrences: positionOccurrences,
    resolveOutcome: true,
  );

  ChessModel._({
    required List<ChessPiece?> board,
    required this.sideToMove,
    required this.castlingRights,
    required this.enPassantTarget,
    required this.halfmoveClock,
    required this.fullmoveNumber,
    required List<ChessMoveRecord> history,
    required Map<String, int> positionOccurrences,
    required this.outcome,
    required this.drawReason,
  }) : _board = List.unmodifiable(board),
       history = List.unmodifiable(history),
       positionOccurrences = Map.unmodifiable(positionOccurrences);

  factory ChessModel._create({
    required List<ChessPiece?> board,
    required ChessColor sideToMove,
    required ChessCastlingRights castlingRights,
    required int? enPassantTarget,
    required int halfmoveClock,
    required int fullmoveNumber,
    required List<ChessMoveRecord> history,
    required Map<String, int> positionOccurrences,
    required bool resolveOutcome,
  }) {
    _validateState(
      board,
      sideToMove,
      castlingRights,
      enPassantTarget,
      halfmoveClock,
      fullmoveNumber,
      positionOccurrences,
    );
    final provisional = ChessModel._(
      board: board,
      sideToMove: sideToMove,
      castlingRights: castlingRights,
      enPassantTarget: enPassantTarget,
      halfmoveClock: halfmoveClock,
      fullmoveNumber: fullmoveNumber,
      history: history,
      positionOccurrences: positionOccurrences,
      outcome: null,
      drawReason: null,
    );
    final occurrences = Map<String, int>.of(positionOccurrences);
    if (occurrences.isEmpty) {
      occurrences[provisional.positionKey] = 1;
    }
    final withOccurrences = provisional._copy(positionOccurrences: occurrences);
    return resolveOutcome
        ? withOccurrences._resolvedOutcome()
        : withOccurrences;
  }

  static const int boardSize = 8;
  static const int squareCount = 64;

  final List<ChessPiece?> _board;
  List<ChessPiece?> get board => _board;
  final ChessColor sideToMove;
  final ChessCastlingRights castlingRights;
  final int? enPassantTarget;
  final int halfmoveClock;
  final int fullmoveNumber;
  final List<ChessMoveRecord> history;
  final Map<String, int> positionOccurrences;
  final ChessOutcome? outcome;
  final ChessDrawReason? drawReason;

  bool get isFinished => outcome != null;
  bool get isDraw => outcome == ChessOutcome.draw;
  ChessColor? get winner => switch (outcome) {
    ChessOutcome.whiteWin => ChessColor.white,
    ChessOutcome.blackWin => ChessColor.black,
    ChessOutcome.draw || null => null,
  };
  bool get isCheck => isInCheck(sideToMove);
  bool get isCheckmate =>
      outcome ==
      (sideToMove == ChessColor.white
          ? ChessOutcome.blackWin
          : ChessOutcome.whiteWin);
  bool get isStalemate => drawReason == ChessDrawReason.stalemate;

  ChessPiece? pieceAt(int square) => isSquare(square) ? _board[square] : null;

  List<ChessMove> get legalMoves {
    if (isFinished) return const [];
    return List.unmodifiable(_legalMovesIgnoringOutcome());
  }

  List<ChessMove> legalMovesFrom(int square) => isSquare(square)
      ? List.unmodifiable(legalMoves.where((move) => move.from == square))
      : const [];

  bool isInCheck(ChessColor color) {
    final king = _board.indexWhere(
      (piece) => piece == ChessPiece(color, ChessPieceType.king),
    );
    return _isSquareAttacked(_board, king, color.opposite);
  }

  ChessMoveResult play(ChessMove requestedMove) {
    if (isFinished) {
      return ChessMoveResult(
        status: ChessMoveStatus.matchFinished,
        model: this,
      );
    }
    ChessMove? move;
    for (final candidate in legalMoves) {
      if (candidate == requestedMove) {
        move = candidate;
        break;
      }
    }
    if (move == null) {
      return ChessMoveResult(status: ChessMoveStatus.illegalMove, model: this);
    }

    final appliedMove = _applyUnchecked(move);
    final applied = appliedMove.model;
    final baseNotation = _notationBase(move);
    final nextOccurrences = Map<String, int>.of(positionOccurrences);
    final key = applied.positionKey;
    nextOccurrences[key] = (nextOccurrences[key] ?? 0) + 1;
    var next = applied._copy(positionOccurrences: nextOccurrences);
    next = next._resolvedOutcome();
    final suffix = next.isCheckmate
        ? '#'
        : next.isCheck
        ? '+'
        : '';
    final record = ChessMoveRecord(
      move: move,
      piece: appliedMove.movingPiece,
      capturedPiece: appliedMove.capturedPiece,
      notation: '$baseNotation$suffix',
      fullmoveNumber: fullmoveNumber,
      wasEnPassant: appliedMove.wasEnPassant,
      wasCastling: appliedMove.wasCastling,
    );
    next = next._copy(history: [...history, record]);
    return ChessMoveResult(
      status: ChessMoveStatus.accepted,
      model: next,
      record: record,
    );
  }

  String get positionKey {
    final pieces = StringBuffer();
    for (final piece in _board) {
      pieces.write(piece == null ? '.' : _pieceKey(piece));
    }
    final rights = StringBuffer()
      ..write(castlingRights.whiteKingSide ? 'K' : '')
      ..write(castlingRights.whiteQueenSide ? 'Q' : '')
      ..write(castlingRights.blackKingSide ? 'k' : '')
      ..write(castlingRights.blackQueenSide ? 'q' : '');
    final effectiveTarget = _effectiveEnPassantTarget();
    return '${pieces.toString()} ${sideToMove == ChessColor.white ? 'w' : 'b'} '
        '${rights.isEmpty ? '-' : rights} '
        '${effectiveTarget == null ? '-' : squareName(effectiveTarget)}';
  }

  List<ChessMove> _legalMovesIgnoringOutcome() {
    final moves = <ChessMove>[];
    for (var square = 0; square < squareCount; square++) {
      final piece = _board[square];
      if (piece?.color != sideToMove) continue;
      for (final move in _pseudoMovesFrom(square, includeCastling: true)) {
        final applied = _applyUnchecked(move).model;
        if (!applied.isInCheck(sideToMove)) moves.add(move);
      }
    }
    return moves;
  }

  List<ChessMove> _pseudoMovesFrom(int from, {required bool includeCastling}) {
    final piece = _board[from]!;
    return switch (piece.type) {
      ChessPieceType.pawn => _pawnMoves(from, piece),
      ChessPieceType.knight => _jumpMoves(from, piece, const [
        (1, 2),
        (2, 1),
        (2, -1),
        (1, -2),
        (-1, -2),
        (-2, -1),
        (-2, 1),
        (-1, 2),
      ]),
      ChessPieceType.bishop => _slidingMoves(from, piece, const [
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
      ]),
      ChessPieceType.rook => _slidingMoves(from, piece, const [
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ]),
      ChessPieceType.queen => _slidingMoves(from, piece, const [
        (1, 1),
        (1, -1),
        (-1, 1),
        (-1, -1),
        (1, 0),
        (-1, 0),
        (0, 1),
        (0, -1),
      ]),
      ChessPieceType.king => [
        ..._jumpMoves(from, piece, const [
          (1, 1),
          (1, 0),
          (1, -1),
          (0, 1),
          (0, -1),
          (-1, 1),
          (-1, 0),
          (-1, -1),
        ]),
        if (includeCastling) ..._castlingMoves(from, piece),
      ],
    };
  }

  List<ChessMove> _pawnMoves(int from, ChessPiece pawn) {
    final moves = <ChessMove>[];
    final file = fileOf(from);
    final rank = rankOf(from);
    final direction = pawn.color == ChessColor.white ? 1 : -1;
    final startRank = pawn.color == ChessColor.white ? 1 : 6;
    final promotionRank = pawn.color == ChessColor.white ? 7 : 0;
    final oneRank = rank + direction;
    if (_inside(file, oneRank)) {
      final one = square(file, oneRank);
      if (_board[one] == null) {
        _addPawnDestination(moves, from, one, oneRank == promotionRank);
        final twoRank = rank + direction * 2;
        if (rank == startRank && _board[square(file, twoRank)] == null) {
          moves.add(ChessMove(from: from, to: square(file, twoRank)));
        }
      }
    }
    for (final deltaFile in const [-1, 1]) {
      final targetFile = file + deltaFile;
      final targetRank = rank + direction;
      if (!_inside(targetFile, targetRank)) continue;
      final target = square(targetFile, targetRank);
      final occupant = _board[target];
      final capture =
          occupant != null &&
          occupant.color != pawn.color &&
          occupant.type != ChessPieceType.king;
      if (capture || target == enPassantTarget) {
        _addPawnDestination(moves, from, target, targetRank == promotionRank);
      }
    }
    return moves;
  }

  void _addPawnDestination(
    List<ChessMove> moves,
    int from,
    int to,
    bool promotion,
  ) {
    if (!promotion) {
      moves.add(ChessMove(from: from, to: to));
      return;
    }
    for (final type in const [
      ChessPieceType.queen,
      ChessPieceType.rook,
      ChessPieceType.bishop,
      ChessPieceType.knight,
    ]) {
      moves.add(ChessMove(from: from, to: to, promotion: type));
    }
  }

  List<ChessMove> _jumpMoves(
    int from,
    ChessPiece piece,
    List<(int, int)> offsets,
  ) {
    final moves = <ChessMove>[];
    final file = fileOf(from);
    final rank = rankOf(from);
    for (final (fileDelta, rankDelta) in offsets) {
      final targetFile = file + fileDelta;
      final targetRank = rank + rankDelta;
      if (!_inside(targetFile, targetRank)) continue;
      final to = square(targetFile, targetRank);
      final occupant = _board[to];
      if (occupant == null ||
          (occupant.color != piece.color &&
              occupant.type != ChessPieceType.king)) {
        moves.add(ChessMove(from: from, to: to));
      }
    }
    return moves;
  }

  List<ChessMove> _slidingMoves(
    int from,
    ChessPiece piece,
    List<(int, int)> directions,
  ) {
    final moves = <ChessMove>[];
    for (final (fileDelta, rankDelta) in directions) {
      var file = fileOf(from) + fileDelta;
      var rank = rankOf(from) + rankDelta;
      while (_inside(file, rank)) {
        final to = square(file, rank);
        final occupant = _board[to];
        if (occupant == null) {
          moves.add(ChessMove(from: from, to: to));
        } else {
          if (occupant.color != piece.color &&
              occupant.type != ChessPieceType.king) {
            moves.add(ChessMove(from: from, to: to));
          }
          break;
        }
        file += fileDelta;
        rank += rankDelta;
      }
    }
    return moves;
  }

  List<ChessMove> _castlingMoves(int from, ChessPiece king) {
    final home = king.color == ChessColor.white ? 4 : 60;
    if (from != home || isInCheck(king.color)) return const [];
    final moves = <ChessMove>[];
    final enemy = king.color.opposite;
    if (castlingRights.kingSide(king.color)) {
      final rook = home + 3;
      if (_board[home + 1] == null &&
          _board[home + 2] == null &&
          _board[rook] == ChessPiece(king.color, ChessPieceType.rook) &&
          !_isSquareAttacked(_board, home + 1, enemy) &&
          !_isSquareAttacked(_board, home + 2, enemy)) {
        moves.add(ChessMove(from: home, to: home + 2));
      }
    }
    if (castlingRights.queenSide(king.color)) {
      final rook = home - 4;
      if (_board[home - 1] == null &&
          _board[home - 2] == null &&
          _board[home - 3] == null &&
          _board[rook] == ChessPiece(king.color, ChessPieceType.rook) &&
          !_isSquareAttacked(_board, home - 1, enemy) &&
          !_isSquareAttacked(_board, home - 2, enemy)) {
        moves.add(ChessMove(from: home, to: home - 2));
      }
    }
    return moves;
  }

  _ChessAppliedMove _applyUnchecked(ChessMove move) {
    final board = List<ChessPiece?>.of(_board);
    final moving = board[move.from]!;
    var captured = board[move.to];
    var enPassant = false;
    final castling =
        moving.type == ChessPieceType.king && (move.to - move.from).abs() == 2;
    if (moving.type == ChessPieceType.pawn &&
        move.to == enPassantTarget &&
        captured == null &&
        fileOf(move.from) != fileOf(move.to)) {
      final capturedSquare =
          move.to + (moving.color == ChessColor.white ? -boardSize : boardSize);
      captured = board[capturedSquare];
      board[capturedSquare] = null;
      enPassant = true;
    }
    board[move.from] = null;
    board[move.to] = move.promotion == null
        ? moving
        : ChessPiece(moving.color, move.promotion!);
    if (castling) {
      final kingSide = move.to > move.from;
      final rookFrom = move.from + (kingSide ? 3 : -4);
      final rookTo = move.from + (kingSide ? 1 : -1);
      board[rookTo] = board[rookFrom];
      board[rookFrom] = null;
    }

    var rights = castlingRights;
    if (moving.type == ChessPieceType.king) {
      rights = moving.color == ChessColor.white
          ? rights.copyWith(whiteKingSide: false, whiteQueenSide: false)
          : rights.copyWith(blackKingSide: false, blackQueenSide: false);
    }
    if (moving.type == ChessPieceType.rook) {
      rights = _removeRookRight(rights, move.from);
    }
    if (captured?.type == ChessPieceType.rook && !enPassant) {
      rights = _removeRookRight(rights, move.to);
    }

    final doublePawn =
        moving.type == ChessPieceType.pawn &&
        (rankOf(move.to) - rankOf(move.from)).abs() == 2;
    final target = doublePawn ? (move.from + move.to) ~/ 2 : null;
    final resetClock = moving.type == ChessPieceType.pawn || captured != null;
    return _ChessAppliedMove(
      model: ChessModel._(
        board: board,
        sideToMove: sideToMove.opposite,
        castlingRights: rights,
        enPassantTarget: target,
        halfmoveClock: resetClock ? 0 : halfmoveClock + 1,
        fullmoveNumber: sideToMove == ChessColor.black
            ? fullmoveNumber + 1
            : fullmoveNumber,
        history: history,
        positionOccurrences: positionOccurrences,
        outcome: null,
        drawReason: null,
      ),
      movingPiece: moving,
      capturedPiece: captured,
      wasEnPassant: enPassant,
      wasCastling: castling,
    );
  }

  ChessCastlingRights _removeRookRight(
    ChessCastlingRights rights,
    int square,
  ) => switch (square) {
    0 => rights.copyWith(whiteQueenSide: false),
    7 => rights.copyWith(whiteKingSide: false),
    56 => rights.copyWith(blackQueenSide: false),
    63 => rights.copyWith(blackKingSide: false),
    _ => rights,
  };

  ChessModel _resolvedOutcome() {
    ChessOutcome? nextOutcome;
    ChessDrawReason? nextDraw;
    final moves = _legalMovesIgnoringOutcome();
    if (moves.isEmpty) {
      if (isInCheck(sideToMove)) {
        nextOutcome = sideToMove == ChessColor.white
            ? ChessOutcome.blackWin
            : ChessOutcome.whiteWin;
      } else {
        nextOutcome = ChessOutcome.draw;
        nextDraw = ChessDrawReason.stalemate;
      }
    } else if (_hasInsufficientMaterial()) {
      nextOutcome = ChessOutcome.draw;
      nextDraw = ChessDrawReason.insufficientMaterial;
    } else if (halfmoveClock >= 100) {
      nextOutcome = ChessOutcome.draw;
      nextDraw = ChessDrawReason.fiftyMoveRule;
    } else if ((positionOccurrences[positionKey] ?? 0) >= 3) {
      nextOutcome = ChessOutcome.draw;
      nextDraw = ChessDrawReason.threefoldRepetition;
    }
    return _copy(outcome: nextOutcome, drawReason: nextDraw);
  }

  bool _hasInsufficientMaterial() {
    final nonKings = <(int, ChessPiece)>[];
    for (var square = 0; square < squareCount; square++) {
      final piece = _board[square];
      if (piece != null && piece.type != ChessPieceType.king) {
        nonKings.add((square, piece));
      }
    }
    if (nonKings.isEmpty) return true;
    if (nonKings.length == 1) {
      final type = nonKings.single.$2.type;
      return type == ChessPieceType.bishop || type == ChessPieceType.knight;
    }
    if (nonKings.every((entry) => entry.$2.type == ChessPieceType.bishop)) {
      final colors = nonKings
          .map((entry) => (fileOf(entry.$1) + rankOf(entry.$1)) & 1)
          .toSet();
      return colors.length == 1;
    }
    return false;
  }

  String _notationBase(ChessMove move) {
    final piece = _board[move.from]!;
    final wasCastling =
        piece.type == ChessPieceType.king && (move.to - move.from).abs() == 2;
    if (wasCastling) return move.to > move.from ? 'O-O' : 'O-O-O';
    final enPassantCapture =
        piece.type == ChessPieceType.pawn &&
        move.to == enPassantTarget &&
        _board[move.to] == null &&
        fileOf(move.from) != fileOf(move.to);
    final capture = _board[move.to] != null || enPassantCapture;
    final buffer = StringBuffer();
    if (piece.type == ChessPieceType.pawn) {
      if (capture) buffer.write(String.fromCharCode(97 + fileOf(move.from)));
    } else {
      buffer.write(_notationLetter(piece.type));
      final alternatives = legalMoves.where((candidate) {
        if (candidate == move || candidate.to != move.to) return false;
        final candidatePiece = _board[candidate.from];
        return candidatePiece?.type == piece.type;
      }).toList();
      if (alternatives.isNotEmpty) {
        final sameFile = alternatives.any(
          (candidate) => fileOf(candidate.from) == fileOf(move.from),
        );
        final sameRank = alternatives.any(
          (candidate) => rankOf(candidate.from) == rankOf(move.from),
        );
        if (!sameFile) {
          buffer.write(String.fromCharCode(97 + fileOf(move.from)));
        } else if (!sameRank) {
          buffer.write(rankOf(move.from) + 1);
        } else {
          buffer
            ..write(String.fromCharCode(97 + fileOf(move.from)))
            ..write(rankOf(move.from) + 1);
        }
      }
    }
    if (capture) buffer.write('x');
    buffer.write(squareName(move.to));
    if (move.promotion case final promotion?) {
      buffer
        ..write('=')
        ..write(_notationLetter(promotion));
    }
    return buffer.toString();
  }

  int? _effectiveEnPassantTarget() {
    final target = enPassantTarget;
    if (target == null) return null;
    final sourceRank =
        rankOf(target) + (sideToMove == ChessColor.white ? -1 : 1);
    for (final fileDelta in const [-1, 1]) {
      final sourceFile = fileOf(target) + fileDelta;
      if (!_inside(sourceFile, sourceRank)) continue;
      if (_board[square(sourceFile, sourceRank)] ==
          ChessPiece(sideToMove, ChessPieceType.pawn)) {
        return target;
      }
    }
    return null;
  }

  ChessModel _copy({
    List<ChessMoveRecord>? history,
    Map<String, int>? positionOccurrences,
    ChessOutcome? outcome,
    ChessDrawReason? drawReason,
  }) => ChessModel._(
    board: _board,
    sideToMove: sideToMove,
    castlingRights: castlingRights,
    enPassantTarget: enPassantTarget,
    halfmoveClock: halfmoveClock,
    fullmoveNumber: fullmoveNumber,
    history: history ?? this.history,
    positionOccurrences: positionOccurrences ?? this.positionOccurrences,
    outcome: outcome ?? this.outcome,
    drawReason: drawReason ?? this.drawReason,
  );

  static bool _isSquareAttacked(
    List<ChessPiece?> board,
    int target,
    ChessColor byColor,
  ) {
    final targetFile = fileOf(target);
    final targetRank = rankOf(target);
    final pawnSourceRank = targetRank + (byColor == ChessColor.white ? -1 : 1);
    for (final delta in const [-1, 1]) {
      final file = targetFile + delta;
      if (_inside(file, pawnSourceRank) &&
          board[square(file, pawnSourceRank)] ==
              ChessPiece(byColor, ChessPieceType.pawn)) {
        return true;
      }
    }
    for (final (fileDelta, rankDelta) in const [
      (1, 2),
      (2, 1),
      (2, -1),
      (1, -2),
      (-1, -2),
      (-2, -1),
      (-2, 1),
      (-1, 2),
    ]) {
      final file = targetFile + fileDelta;
      final rank = targetRank + rankDelta;
      if (_inside(file, rank) &&
          board[square(file, rank)] ==
              ChessPiece(byColor, ChessPieceType.knight)) {
        return true;
      }
    }
    for (final (fileDelta, rankDelta, first, second) in const [
      (1, 0, ChessPieceType.rook, ChessPieceType.queen),
      (-1, 0, ChessPieceType.rook, ChessPieceType.queen),
      (0, 1, ChessPieceType.rook, ChessPieceType.queen),
      (0, -1, ChessPieceType.rook, ChessPieceType.queen),
      (1, 1, ChessPieceType.bishop, ChessPieceType.queen),
      (1, -1, ChessPieceType.bishop, ChessPieceType.queen),
      (-1, 1, ChessPieceType.bishop, ChessPieceType.queen),
      (-1, -1, ChessPieceType.bishop, ChessPieceType.queen),
    ]) {
      var file = targetFile + fileDelta;
      var rank = targetRank + rankDelta;
      while (_inside(file, rank)) {
        final piece = board[square(file, rank)];
        if (piece != null) {
          if (piece.color == byColor &&
              (piece.type == first || piece.type == second)) {
            return true;
          }
          break;
        }
        file += fileDelta;
        rank += rankDelta;
      }
    }
    for (var fileDelta = -1; fileDelta <= 1; fileDelta++) {
      for (var rankDelta = -1; rankDelta <= 1; rankDelta++) {
        if (fileDelta == 0 && rankDelta == 0) continue;
        final file = targetFile + fileDelta;
        final rank = targetRank + rankDelta;
        if (_inside(file, rank) &&
            board[square(file, rank)] ==
                ChessPiece(byColor, ChessPieceType.king)) {
          return true;
        }
      }
    }
    return false;
  }

  static void _validateState(
    List<ChessPiece?> board,
    ChessColor sideToMove,
    ChessCastlingRights rights,
    int? enPassantTarget,
    int halfmoveClock,
    int fullmoveNumber,
    Map<String, int> occurrences,
  ) {
    if (board.length != squareCount) {
      throw ArgumentError.value(board.length, 'board', 'Must have 64 squares');
    }
    for (final color in ChessColor.values) {
      if (board
              .where((piece) => piece == ChessPiece(color, ChessPieceType.king))
              .length !=
          1) {
        throw ArgumentError('Each side must have exactly one king');
      }
    }
    for (var file = 0; file < boardSize; file++) {
      if (board[file]?.type == ChessPieceType.pawn ||
          board[56 + file]?.type == ChessPieceType.pawn) {
        throw ArgumentError('Pawns cannot remain on a promotion rank');
      }
    }
    final whiteKing = board.indexOf(
      const ChessPiece(ChessColor.white, ChessPieceType.king),
    );
    final blackKing = board.indexOf(
      const ChessPiece(ChessColor.black, ChessPieceType.king),
    );
    if ((fileOf(whiteKing) - fileOf(blackKing)).abs() <= 1 &&
        (rankOf(whiteKing) - rankOf(blackKing)).abs() <= 1) {
      throw ArgumentError('Kings cannot occupy adjacent squares');
    }
    if (enPassantTarget != null &&
        (!isSquare(enPassantTarget) ||
            (rankOf(enPassantTarget) != 2 && rankOf(enPassantTarget) != 5))) {
      throw ArgumentError.value(enPassantTarget, 'enPassantTarget');
    }
    if (enPassantTarget != null) {
      final expectedRank = sideToMove == ChessColor.white ? 5 : 2;
      final passedPawnSquare =
          enPassantTarget +
          (sideToMove == ChessColor.white ? -boardSize : boardSize);
      if (rankOf(enPassantTarget) != expectedRank ||
          board[passedPawnSquare] !=
              ChessPiece(sideToMove.opposite, ChessPieceType.pawn)) {
        throw ArgumentError.value(
          enPassantTarget,
          'enPassantTarget',
          'Must identify a pawn that just advanced two squares',
        );
      }
    }
    if (halfmoveClock < 0 || fullmoveNumber < 1) {
      throw ArgumentError('Move counters are invalid');
    }
    if (occurrences.values.any((count) => count < 1)) {
      throw ArgumentError('Position occurrence counts must be positive');
    }
    _validateCastlingPieces(board, rights);
  }

  static void _validateCastlingPieces(
    List<ChessPiece?> board,
    ChessCastlingRights rights,
  ) {
    void require(bool enabled, int king, int rook, ChessColor color) {
      if (!enabled) return;
      if (board[king] != ChessPiece(color, ChessPieceType.king) ||
          board[rook] != ChessPiece(color, ChessPieceType.rook)) {
        throw ArgumentError('Castling rights require the home king and rook');
      }
    }

    require(rights.whiteKingSide, 4, 7, ChessColor.white);
    require(rights.whiteQueenSide, 4, 0, ChessColor.white);
    require(rights.blackKingSide, 60, 63, ChessColor.black);
    require(rights.blackQueenSide, 60, 56, ChessColor.black);
  }

  static List<ChessPiece?> _boardFromMap(Map<int, ChessPiece> pieces) {
    final board = List<ChessPiece?>.filled(squareCount, null);
    for (final entry in pieces.entries) {
      if (!isSquare(entry.key)) {
        throw ArgumentError.value(entry.key, 'board', 'Invalid square');
      }
      board[entry.key] = entry.value;
    }
    return board;
  }

  static List<ChessPiece?> _initialBoard() {
    final board = List<ChessPiece?>.filled(squareCount, null);
    const backRank = [
      ChessPieceType.rook,
      ChessPieceType.knight,
      ChessPieceType.bishop,
      ChessPieceType.queen,
      ChessPieceType.king,
      ChessPieceType.bishop,
      ChessPieceType.knight,
      ChessPieceType.rook,
    ];
    for (var file = 0; file < boardSize; file++) {
      board[file] = ChessPiece(ChessColor.white, backRank[file]);
      board[8 + file] = const ChessPiece(ChessColor.white, ChessPieceType.pawn);
      board[48 + file] = const ChessPiece(
        ChessColor.black,
        ChessPieceType.pawn,
      );
      board[56 + file] = ChessPiece(ChessColor.black, backRank[file]);
    }
    return board;
  }

  static bool isSquare(int value) => value >= 0 && value < squareCount;
  static int fileOf(int square) => square % boardSize;
  static int rankOf(int square) => square ~/ boardSize;
  static int square(int file, int rank) => rank * boardSize + file;

  static int parseSquare(String name) {
    if (name.length != 2) throw ArgumentError.value(name, 'name');
    final file = name.codeUnitAt(0) - 97;
    final rank = name.codeUnitAt(1) - 49;
    if (!_inside(file, rank)) throw ArgumentError.value(name, 'name');
    return square(file, rank);
  }

  static String squareName(int square) {
    if (!isSquare(square)) throw ArgumentError.value(square, 'square');
    return '${String.fromCharCode(97 + fileOf(square))}${rankOf(square) + 1}';
  }

  static bool _inside(int file, int rank) =>
      file >= 0 && file < boardSize && rank >= 0 && rank < boardSize;

  static String _pieceKey(ChessPiece piece) {
    final letter = _notationLetter(piece.type);
    final pawn = piece.type == ChessPieceType.pawn ? 'P' : letter;
    return piece.color == ChessColor.white ? pawn : pawn.toLowerCase();
  }

  static String _notationLetter(ChessPieceType type) => switch (type) {
    ChessPieceType.king => 'K',
    ChessPieceType.queen => 'Q',
    ChessPieceType.rook => 'R',
    ChessPieceType.bishop => 'B',
    ChessPieceType.knight => 'N',
    ChessPieceType.pawn => '',
  };
}
