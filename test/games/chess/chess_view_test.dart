import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/chess/chess_model.dart';
import 'package:tap_tussle/games/chess/chess_view.dart';

void main() {
  Widget game({ChessModel? model, Size size = const Size(390, 844)}) =>
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: MediaQuery(
          data: MediaQueryData(size: size),
          child: Scaffold(
            body: ChessView(key: ValueKey(model), initialModel: model),
          ),
        ),
      );

  testWidgets('renders all pieces, squares, players, and current state', (
    tester,
  ) async {
    await tester.pumpWidget(game());

    expect(find.byKey(ValueKey('chess-square-${_sq('a1')}')), findsOneWidget);
    expect(find.byKey(ValueKey('chess-square-${_sq('h8')}')), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('PLAYER 1 • WHITE TO MOVE'), findsOneWidget);
    expect(find.bySemanticsLabel('e2, white pawn'), findsOneWidget);
    expect(find.bySemanticsLabel('e4, empty'), findsOneWidget);
    expect(find.text('NO MOVES YET'), findsOneWidget);
  });

  testWidgets('selects a piece, marks targets, and records the move', (
    tester,
  ) async {
    await tester.pumpWidget(game());

    await tester.tap(find.byKey(ValueKey('chess-square-${_sq('e2')}')));
    await tester.pump();
    expect(find.bySemanticsLabel('e2, white pawn, selected'), findsOneWidget);
    expect(find.bySemanticsLabel('e4, empty, legal target'), findsOneWidget);

    await tester.tap(find.byKey(ValueKey('chess-square-${_sq('e4')}')));
    await tester.pump();
    expect(find.text('1. e4'), findsOneWidget);
    expect(find.bySemanticsLabel('e4, white pawn, last move'), findsOneWidget);
    expect(find.text('PLAYER 2 • BLACK TO MOVE'), findsOneWidget);
  });

  testWidgets('flips orientation while preserving the position', (
    tester,
  ) async {
    await tester.pumpWidget(game());
    final e8 = find.byKey(ValueKey('chess-square-${_sq('e8')}'));
    final before = tester.getTopLeft(e8);

    await tester.tap(find.byKey(const ValueKey('chess-flip-board')));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(e8);

    expect(after.dy, greaterThan(before.dy));
    expect(find.bySemanticsLabel('e8, black king'), findsOneWidget);
  });

  testWidgets('shows an accessible promotion choice and applies it', (
    tester,
  ) async {
    final model = ChessModel.fromState(
      board: {
        _sq('e1'): _white(ChessPieceType.king),
        _sq('a7'): _white(ChessPieceType.pawn),
        _sq('e8'): _black(ChessPieceType.king),
      },
    );
    await tester.pumpWidget(game(model: model));

    await tester.tap(find.byKey(ValueKey('chess-square-${_sq('a7')}')));
    await tester.tap(find.byKey(ValueKey('chess-square-${_sq('a8')}')));
    await tester.pump();
    expect(find.bySemanticsLabel('Choose promotion piece'), findsOneWidget);
    expect(find.byKey(const ValueKey('chess-promote-queen')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chess-promote-knight')));
    await tester.pump();
    expect(
      find.bySemanticsLabel('a8, white knight, last move'),
      findsOneWidget,
    );
    expect(find.text('1. a8=N'), findsOneWidget);
  });

  testWidgets('announces check, captured pieces, history, and checkmate', (
    tester,
  ) async {
    var capture = ChessModel();
    capture = _play(capture, 'e2', 'e4');
    capture = _play(capture, 'd7', 'd5');
    capture = _play(capture, 'e4', 'd5');
    await tester.pumpWidget(game(model: capture));
    expect(find.bySemanticsLabel('Captured by White: ♟'), findsOneWidget);
    expect(find.textContaining('exd5'), findsOneWidget);

    final check = ChessModel.fromState(
      board: {
        _sq('e1'): _white(ChessPieceType.king),
        _sq('a8'): _black(ChessPieceType.king),
        _sq('e8'): _black(ChessPieceType.rook),
      },
    );
    await tester.pumpWidget(game(model: check));
    expect(find.text('PLAYER 1 • CHECK • WHITE TO MOVE'), findsOneWidget);
    expect(find.bySemanticsLabel('e1, white king, in check'), findsOneWidget);

    final mate = ChessModel.fromState(
      board: {
        _sq('h8'): _black(ChessPieceType.king),
        _sq('g7'): _white(ChessPieceType.queen),
        _sq('g6'): _white(ChessPieceType.king),
      },
      sideToMove: ChessColor.black,
    );
    await tester.pumpWidget(game(model: mate));
    expect(find.text('PLAYER 1 WINS • CHECKMATE'), findsOneWidget);
  });

  testWidgets('fits compact phone and tablet layouts without overflow', (
    tester,
  ) async {
    for (final size in const [Size(320, 568), Size(1024, 1366)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(game(size: size));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: 'Failed at $size');
    }
    await tester.binding.setSurfaceSize(null);
  });
}

ChessModel _play(ChessModel model, String from, String to) =>
    model.play(ChessMove(from: _sq(from), to: _sq(to))).model;

int _sq(String value) => ChessModel.parseSquare(value);
ChessPiece _white(ChessPieceType type) => ChessPiece(ChessColor.white, type);
ChessPiece _black(ChessPieceType type) => ChessPiece(ChessColor.black, type);
