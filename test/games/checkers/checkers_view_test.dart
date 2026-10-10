import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/checkers/checkers_model.dart';
import 'package:tap_tussle/games/checkers/checkers_view.dart';

void main() {
  Widget board(
    CheckersModel model, {
    int? selectedSquare,
    ValueChanged<int>? onSquareTap,
  }) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: CheckersBoard(
        model: model,
        selectedSquare: selectedSquare,
        onSquareTap: onSquareTap ?? (_) {},
      ),
    ),
  );

  testWidgets('shows all squares, pieces, counts, and current player', (
    tester,
  ) async {
    await tester.pumpWidget(board(CheckersModel()));

    expect(find.byKey(const ValueKey('checkers-square-0')), findsOneWidget);
    expect(find.byKey(const ValueKey('checkers-square-63')), findsOneWidget);
    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text('12 LEFT'), findsNWidgets(2));
    expect(find.text('PLAYER 1: PICK A PIECE'), findsOneWidget);
    expect(find.byIcon(Icons.local_fire_department_rounded), findsWidgets);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsWidgets);
    expect(
      find.bySemanticsLabel('Row 6, column 1, Player 1, piece, movable'),
      findsOneWidget,
    );
  });

  testWidgets('emphasizes selection and reports legal-target taps', (
    tester,
  ) async {
    int? tapped;
    await tester.pumpWidget(
      board(
        CheckersModel(),
        selectedSquare: 40,
        onSquareTap: (square) => tapped = square,
      ),
    );

    expect(
      find.bySemanticsLabel('Row 6, column 1, Player 1, piece, selected'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Row 5, column 2, empty, legal target'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.arrow_forward_rounded), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('checkers-square-33')));
    expect(tapped, 33);
  });

  testWidgets('legal-target arrows point toward their destination', (
    tester,
  ) async {
    final model = CheckersModel.fromBoard(
      board: {
        39: const CheckersPiece(player: 0),
        1: const CheckersPiece(player: 1),
      },
    );
    await tester.pumpWidget(board(model, selectedSquare: 39));

    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
  });

  testWidgets('shows mandatory capture and capture-chain states', (
    tester,
  ) async {
    final model = CheckersModel.fromBoard(
      board: {
        56: const CheckersPiece(player: 0),
        49: const CheckersPiece(player: 1),
        35: const CheckersPiece(player: 1),
        1: const CheckersPiece(player: 1),
      },
    );
    await tester.pumpWidget(board(model, selectedSquare: 56));

    expect(find.text('PLAYER 1: JUMP A PIECE!'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Row 6, column 3, empty, capture target'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

    model.play(0, const CheckersMove(from: 56, to: 42));
    await tester.pumpWidget(board(model, selectedSquare: 42));
    expect(find.text('PLAYER 1: KEEP JUMPING!'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Row 4, column 5, empty, capture target'),
      findsOneWidget,
    );
  });

  testWidgets('announces kings and terminal winner and draw states', (
    tester,
  ) async {
    final winning = CheckersModel.fromBoard(
      board: {
        40: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
        33: const CheckersPiece(player: 1),
      },
    );
    winning.play(0, const CheckersMove(from: 40, to: 26));
    await tester.pumpWidget(board(winning));
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
    expect(find.text('Player 1 wins'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Row 4, column 3, Player 1, king'),
      findsOneWidget,
    );

    final draw = CheckersModel.fromBoard(
      board: {
        40: const CheckersPiece(player: 0, kind: CheckersPieceKind.king),
        23: const CheckersPiece(player: 1, kind: CheckersPieceKind.king),
      },
      maximumNonProgressPlies: 1,
    );
    draw.play(0, const CheckersMove(from: 40, to: 33));
    await tester.pumpWidget(board(draw));
    expect(find.text('DRAW • NO PROGRESS'), findsOneWidget);
  });

  testWidgets('fits a compact portrait phone without overflow', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(board(CheckersModel()));

    expect(find.byType(CheckersBoard), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('checkers-board'))).width,
      greaterThanOrEqualTo(300),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('supports enlarged text without shrinking the board away', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(board(CheckersModel()));

    expect(
      tester.getSize(find.byKey(const ValueKey('checkers-board'))).width,
      greaterThanOrEqualTo(360),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows the supplied bot thinking status and disables targets', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: CheckersBoard(
            model: CheckersModel(),
            selectedSquare: 40,
            enabled: false,
            statusOverride: 'BOT IS THINKING…',
            onSquareTap: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('BOT IS THINKING…'), findsOneWidget);
    expect(
      tester
          .widget<Semantics>(
            find.bySemanticsLabel('Row 5, column 2, empty, legal target'),
          )
          .properties
          .enabled,
      isFalse,
    );
  });
}
