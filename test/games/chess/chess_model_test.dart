import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/chess/chess_model.dart';

void main() {
  group('ChessModel', () {
    test('creates the standard immutable opening position', () {
      final model = ChessModel();

      expect(model.board.whereType<ChessPiece>(), hasLength(32));
      expect(model.sideToMove, ChessColor.white);
      expect(model.legalMoves, hasLength(20));
      expect(model.castlingRights, const ChessCastlingRights.initial());
      expect(model.positionOccurrences[model.positionKey], 1);
      expect(model.isFinished, isFalse);
    });

    test('plays legal moves immutably and records notation-ready history', () {
      final original = ChessModel();
      final result = original.play(_move('e2', 'e4'));

      expect(result.status, ChessMoveStatus.accepted);
      expect(original.pieceAt(_sq('e2')), _white(ChessPieceType.pawn));
      expect(result.model.pieceAt(_sq('e2')), isNull);
      expect(result.model.pieceAt(_sq('e4')), _white(ChessPieceType.pawn));
      expect(result.model.sideToMove, ChessColor.black);
      expect(result.model.enPassantTarget, _sq('e3'));
      expect(result.model.history.single.notation, 'e4');
      expect(result.model.history.single.fullmoveNumber, 1);
    });

    test('rejects illegal movement and moving while a match is finished', () {
      final model = ChessModel();
      expect(model.play(_move('e2', 'e5')).status, ChessMoveStatus.illegalMove);
      expect(model.play(_move('a7', 'a6')).status, ChessMoveStatus.illegalMove);

      final draw = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('e8'): _black(ChessPieceType.king),
        },
      );
      expect(draw.drawReason, ChessDrawReason.insufficientMaterial);
      expect(
        draw.play(_move('e1', 'e2')).status,
        ChessMoveStatus.matchFinished,
      );
    });

    test('filters moves that expose the moving king to check', () {
      final model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('e2'): _white(ChessPieceType.rook),
          _sq('a8'): _black(ChessPieceType.king),
          _sq('e8'): _black(ChessPieceType.rook),
        },
      );

      expect(
        model.legalMovesFrom(_sq('e2')),
        isNot(contains(_move('e2', 'f2'))),
      );
      expect(model.legalMovesFrom(_sq('e2')), contains(_move('e2', 'e3')));
    });

    test('detects checkmate and appends mate notation', () {
      var model = ChessModel();
      model = _play(model, 'f2', 'f3');
      model = _play(model, 'e7', 'e5');
      model = _play(model, 'g2', 'g4');
      final result = model.play(_move('d8', 'h4'));

      expect(result.model.outcome, ChessOutcome.blackWin);
      expect(result.model.winner, ChessColor.black);
      expect(result.model.isCheckmate, isTrue);
      expect(result.record!.notation, 'Qh4#');
      expect(result.model.legalMoves, isEmpty);
    });

    test('detects stalemate without declaring a winner', () {
      final model = ChessModel.fromState(
        board: {
          _sq('a8'): _black(ChessPieceType.king),
          _sq('c6'): _white(ChessPieceType.king),
          _sq('b6'): _white(ChessPieceType.queen),
        },
        sideToMove: ChessColor.black,
      );

      expect(model.outcome, ChessOutcome.draw);
      expect(model.drawReason, ChessDrawReason.stalemate);
      expect(model.isCheck, isFalse);
      expect(model.legalMoves, isEmpty);
    });

    test('castles on both sides and moves the rook', () {
      final position = ChessModel.fromState(
        board: {
          _sq('a1'): _white(ChessPieceType.rook),
          _sq('e1'): _white(ChessPieceType.king),
          _sq('h1'): _white(ChessPieceType.rook),
          _sq('e8'): _black(ChessPieceType.king),
        },
        castlingRights: const ChessCastlingRights(
          whiteKingSide: true,
          whiteQueenSide: true,
        ),
      );

      expect(position.legalMoves, contains(_move('e1', 'g1')));
      expect(position.legalMoves, contains(_move('e1', 'c1')));
      final result = position.play(_move('e1', 'g1'));
      expect(result.model.pieceAt(_sq('g1')), _white(ChessPieceType.king));
      expect(result.model.pieceAt(_sq('f1')), _white(ChessPieceType.rook));
      expect(result.model.pieceAt(_sq('h1')), isNull);
      expect(result.model.castlingRights.whiteKingSide, isFalse);
      expect(result.record!.notation, 'O-O');
      expect(result.record!.wasCastling, isTrue);
    });

    test('forbids castling through an attacked square', () {
      final model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('h1'): _white(ChessPieceType.rook),
          _sq('a8'): _black(ChessPieceType.king),
          _sq('f8'): _black(ChessPieceType.rook),
        },
        castlingRights: const ChessCastlingRights(whiteKingSide: true),
      );

      expect(model.legalMoves, isNot(contains(_move('e1', 'g1'))));
    });

    test('en passant is available immediately and removes the passed pawn', () {
      var model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('e5'): _white(ChessPieceType.pawn),
          _sq('e8'): _black(ChessPieceType.king),
          _sq('d7'): _black(ChessPieceType.pawn),
        },
        sideToMove: ChessColor.black,
      );
      model = _play(model, 'd7', 'd5');
      expect(model.enPassantTarget, _sq('d6'));
      expect(model.legalMoves, contains(_move('e5', 'd6')));

      final result = model.play(_move('e5', 'd6'));
      expect(result.model.pieceAt(_sq('d5')), isNull);
      expect(result.model.pieceAt(_sq('d6')), _white(ChessPieceType.pawn));
      expect(result.record!.wasEnPassant, isTrue);
      expect(result.record!.notation, 'exd6');
    });

    test('en passant expires after a different reply', () {
      var model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('e5'): _white(ChessPieceType.pawn),
          _sq('e8'): _black(ChessPieceType.king),
          _sq('d7'): _black(ChessPieceType.pawn),
        },
        sideToMove: ChessColor.black,
      );
      model = _play(model, 'd7', 'd5');
      model = _play(model, 'e1', 'f1');

      expect(model.enPassantTarget, isNull);
    });

    test('offers every legal promotion and records the selected piece', () {
      final model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('a7'): _white(ChessPieceType.pawn),
          _sq('e8'): _black(ChessPieceType.king),
        },
      );
      final promotions = model
          .legalMovesFrom(_sq('a7'))
          .where((move) => move.to == _sq('a8'))
          .toList();
      expect(promotions, hasLength(4));
      expect(promotions.map((move) => move.promotion).toSet(), {
        ChessPieceType.queen,
        ChessPieceType.rook,
        ChessPieceType.bishop,
        ChessPieceType.knight,
      });

      final result = model.play(
        ChessMove(
          from: _sq('a7'),
          to: _sq('a8'),
          promotion: ChessPieceType.knight,
        ),
      );
      expect(result.model.pieceAt(_sq('a8')), _white(ChessPieceType.knight));
      expect(result.record!.notation, 'a8=N');
    });

    test('recognizes standard insufficient-material positions', () {
      ChessModel position(ChessPieceType? minor, int square) =>
          ChessModel.fromState(
            board: {
              _sq('e1'): _white(ChessPieceType.king),
              _sq('e8'): _black(ChessPieceType.king),
              if (minor != null) square: _white(minor),
            },
          );

      expect(
        position(null, 0).drawReason,
        ChessDrawReason.insufficientMaterial,
      );
      expect(
        position(ChessPieceType.bishop, _sq('c1')).drawReason,
        ChessDrawReason.insufficientMaterial,
      );
      expect(
        position(ChessPieceType.knight, _sq('g1')).drawReason,
        ChessDrawReason.insufficientMaterial,
      );
    });

    test('draws after one hundred halfmoves without pawn move or capture', () {
      final model = ChessModel.fromState(
        board: {
          _sq('e1'): _white(ChessPieceType.king),
          _sq('a1'): _white(ChessPieceType.rook),
          _sq('e8'): _black(ChessPieceType.king),
        },
        halfmoveClock: 99,
      );

      final next = model.play(_move('a1', 'a2')).model;
      expect(next.halfmoveClock, 100);
      expect(next.outcome, ChessOutcome.draw);
      expect(next.drawReason, ChessDrawReason.fiftyMoveRule);
    });

    test('draws when the complete position occurs three times', () {
      var model = ChessModel();
      for (var cycle = 0; cycle < 2; cycle++) {
        model = _play(model, 'g1', 'f3');
        model = _play(model, 'g8', 'f6');
        model = _play(model, 'f3', 'g1');
        model = _play(model, 'f6', 'g8');
      }

      expect(model.outcome, ChessOutcome.draw);
      expect(model.drawReason, ChessDrawReason.threefoldRepetition);
      expect(model.positionOccurrences[model.positionKey], 3);
    });

    test('validates square notation and structurally invalid positions', () {
      expect(ChessModel.squareName(_sq('h8')), 'h8');
      expect(() => ChessModel.parseSquare('z9'), throwsArgumentError);
      expect(
        () => ChessModel.fromState(
          board: {_sq('e1'): _white(ChessPieceType.king)},
        ),
        throwsArgumentError,
      );
      expect(
        () => ChessModel.fromState(
          board: {
            _sq('e1'): _white(ChessPieceType.king),
            _sq('e2'): _black(ChessPieceType.king),
          },
        ),
        throwsArgumentError,
      );
    });
  });
}

ChessModel _play(
  ChessModel model,
  String from,
  String to, {
  ChessPieceType? promotion,
}) {
  final result = model.play(_move(from, to, promotion: promotion));
  expect(result.status, ChessMoveStatus.accepted);
  return result.model;
}

ChessMove _move(String from, String to, {ChessPieceType? promotion}) =>
    ChessMove(from: _sq(from), to: _sq(to), promotion: promotion);

int _sq(String name) => ChessModel.parseSquare(name);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
