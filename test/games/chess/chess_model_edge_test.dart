import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/chess/chess_model.dart';

void main() {
  group('ChessModel perft', () {
    test('matches standard opening counts through depth three', () {
      final model = ChessModel();

      expect(_perft(model, 1), 20);
      expect(_perft(model, 2), 400);
      expect(_perft(model, 3), 8902);
    });

    test('matches Kiwipete castling and tactical counts', () {
      final model = _fromFen(
        'r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1',
      );

      expect(_perft(model, 1), 48);
      expect(_perft(model, 2), 2039);
    });

    test('matches endgame en-passant and check-evasion counts', () {
      final model = _fromFen('8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1');

      expect(_perft(model, 1), 14);
      expect(_perft(model, 2), 191);
      expect(_perft(model, 3), 2812);
    });
  });

  group('ChessModel special-move edges', () {
    test('en passant is illegal when it exposes the king to a rook', () {
      final model = _fromFen('k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1');

      expect(
        model.legalMovesFrom(_sq('e5')),
        isNot(contains(_move('e5', 'd6'))),
      );
    });

    test('king and rook moves permanently remove castling rights', () {
      var kingMoved = _fromFen('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      kingMoved = _play(kingMoved, 'e1', 'f1');
      kingMoved = _play(kingMoved, 'e8', 'e7');
      kingMoved = _play(kingMoved, 'f1', 'e1');
      expect(kingMoved.castlingRights.whiteKingSide, isFalse);
      expect(kingMoved.castlingRights.whiteQueenSide, isFalse);

      var rookMoved = _fromFen('4k3/8/8/8/8/8/8/R3K2R w KQ - 0 1');
      rookMoved = _play(rookMoved, 'h1', 'h2');
      rookMoved = _play(rookMoved, 'e8', 'e7');
      rookMoved = _play(rookMoved, 'h2', 'h1');
      expect(rookMoved.castlingRights.whiteKingSide, isFalse);
      expect(rookMoved.castlingRights.whiteQueenSide, isTrue);
    });

    test('capturing a home rook removes only its castling right', () {
      final model = _fromFen('4k3/8/8/8/8/8/1b6/R3K2R b KQ - 0 1');
      final next = _play(model, 'b2', 'a1');

      expect(next.castlingRights.whiteQueenSide, isFalse);
      expect(next.castlingRights.whiteKingSide, isTrue);
    });

    test('promotion capture records the chosen piece and check', () {
      final model = _fromFen('4k2r/6P1/8/8/8/8/8/4K3 w - - 0 1');
      final result = model.play(
        _move('g7', 'h8', promotion: ChessPieceType.queen),
      );

      expect(result.accepted, isTrue);
      expect(result.model.pieceAt(_sq('h8')), _white(ChessPieceType.queen));
      expect(result.record!.capturedPiece, _black(ChessPieceType.rook));
      expect(result.record!.notation, 'gxh8=Q+');
    });

    test('SAN disambiguates same-type movers by file and rank', () {
      final byFile = _fromFen('4k3/8/8/8/8/8/8/1N2KN2 w - - 0 1');
      expect(byFile.play(_move('b1', 'd2')).record!.notation, 'Nbd2');

      final byRank = _fromFen('7k/8/8/8/R7/8/8/R3K3 w - - 0 1');
      expect(byRank.play(_move('a1', 'a3')).record!.notation, 'R1a3');
    });
  });

  group('ChessModel state integrity', () {
    test('restored state preserves position, moves, counters, and history', () {
      var original = ChessModel();
      original = _play(original, 'e2', 'e4');
      original = _play(original, 'c7', 'c5');
      original = _play(original, 'g1', 'f3');

      final restored = ChessModel.fromState(
        board: {
          for (var square = 0; square < ChessModel.squareCount; square++)
            if (original.pieceAt(square) case final piece?) square: piece,
        },
        sideToMove: original.sideToMove,
        castlingRights: original.castlingRights,
        enPassantTarget: original.enPassantTarget,
        halfmoveClock: original.halfmoveClock,
        fullmoveNumber: original.fullmoveNumber,
        history: original.history,
        positionOccurrences: original.positionOccurrences,
      );

      expect(restored.positionKey, original.positionKey);
      expect(restored.legalMoves.toSet(), original.legalMoves.toSet());
      expect(restored.halfmoveClock, original.halfmoveClock);
      expect(restored.fullmoveNumber, original.fullmoveNumber);
      expect(restored.history, orderedEquals(original.history));
      expect(restored.positionOccurrences, original.positionOccurrences);
    });

    test(
      'board, history, and repetition data cannot be mutated externally',
      () {
        final model = _play(ChessModel(), 'e2', 'e4');

        expect(() => model.board[_sq('e4')] = null, throwsUnsupportedError);
        expect(() => model.history.clear(), throwsUnsupportedError);
        expect(() => model.positionOccurrences.clear(), throwsUnsupportedError);
      },
    );

    test('accepted and rejected moves leave every prior state unchanged', () {
      final original = ChessModel();
      final originalKey = original.positionKey;
      final accepted = original.play(_move('e2', 'e4'));
      final rejected = original.play(_move('e2', 'e5'));

      expect(original.positionKey, originalKey);
      expect(original.history, isEmpty);
      expect(original.pieceAt(_sq('e2')), _white(ChessPieceType.pawn));
      expect(accepted.model, isNot(same(original)));
      expect(rejected.model, same(original));
    });

    test('checkmate takes precedence over the fifty-move threshold', () {
      final model = _fromFen('7k/6Q1/6K1/8/8/8/8/8 b - - 100 1');

      expect(model.isCheckmate, isTrue);
      expect(model.outcome, ChessOutcome.whiteWin);
      expect(model.drawReason, isNull);
    });

    test('same-color bishops draw but opposite-color bishops continue', () {
      final sameColor = _fromFen('4k3/8/8/8/5b2/8/8/2B1K3 w - - 0 1');
      final oppositeColor = _fromFen('4k3/8/8/8/4b3/8/8/2B1K3 w - - 0 1');

      expect(sameColor.drawReason, ChessDrawReason.insufficientMaterial);
      expect(oppositeColor.isFinished, isFalse);
    });

    test('position identity ignores an unusable en-passant target', () {
      final withoutTarget = _fromFen('4k3/8/8/3p4/8/8/8/R3K3 w - - 0 1');
      final withTarget = _fromFen('4k3/8/8/3p4/8/8/8/R3K3 w - d6 0 1');

      expect(withTarget.positionKey, withoutTarget.positionKey);
    });
  });
}

int _perft(ChessModel model, int depth) {
  if (depth == 0) return 1;
  var nodes = 0;
  for (final move in model.legalMoves) {
    final result = model.play(move);
    expect(result.accepted, isTrue);
    nodes += _perft(result.model, depth - 1);
  }
  return nodes;
}

ChessModel _fromFen(String fen) {
  final fields = fen.split(' ');
  final board = <int, ChessPiece>{};
  final ranks = fields[0].split('/');
  for (var fenRank = 0; fenRank < ranks.length; fenRank++) {
    var file = 0;
    for (final rune in ranks[fenRank].runes) {
      final symbol = String.fromCharCode(rune);
      final empty = int.tryParse(symbol);
      if (empty != null) {
        file += empty;
        continue;
      }
      final color = symbol == symbol.toUpperCase()
          ? ChessColor.white
          : ChessColor.black;
      final type = switch (symbol.toLowerCase()) {
        'k' => ChessPieceType.king,
        'q' => ChessPieceType.queen,
        'r' => ChessPieceType.rook,
        'b' => ChessPieceType.bishop,
        'n' => ChessPieceType.knight,
        'p' => ChessPieceType.pawn,
        _ => throw ArgumentError('Invalid FEN piece: $symbol'),
      };
      board[ChessModel.square(file, 7 - fenRank)] = ChessPiece(color, type);
      file++;
    }
  }
  final rights = fields[2];
  return ChessModel.fromState(
    board: board,
    sideToMove: fields[1] == 'w' ? ChessColor.white : ChessColor.black,
    castlingRights: ChessCastlingRights(
      whiteKingSide: rights.contains('K'),
      whiteQueenSide: rights.contains('Q'),
      blackKingSide: rights.contains('k'),
      blackQueenSide: rights.contains('q'),
    ),
    enPassantTarget: fields[3] == '-' ? null : _sq(fields[3]),
    halfmoveClock: int.parse(fields[4]),
    fullmoveNumber: int.parse(fields[5]),
  );
}

ChessModel _play(ChessModel model, String from, String to) {
  final result = model.play(_move(from, to));
  expect(result.status, ChessMoveStatus.accepted);
  return result.model;
}

ChessMove _move(String from, String to, {ChessPieceType? promotion}) =>
    ChessMove(from: _sq(from), to: _sq(to), promotion: promotion);

int _sq(String name) => ChessModel.parseSquare(name);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
