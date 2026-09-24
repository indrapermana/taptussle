import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/app/game_catalog.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/core/mini_game.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_model.dart';
import 'package:tap_tussle/games/tic_tac_toe/tic_tac_toe_view.dart';

void main() {
  Widget board(TicTacToeModel model, {ValueChanged<int>? onCellTap}) =>
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: TicTacToeBoard(model: model, onCellTap: onCellTap ?? (_) {}),
        ),
      );

  testWidgets('shows participants, current turn, and reports empty-cell taps', (
    tester,
  ) async {
    final model = TicTacToeModel();
    int? tappedCell;
    await tester.pumpWidget(
      board(model, onCellTap: (cell) => tappedCell = cell),
    );

    expect(find.text('Player 1'), findsOneWidget);
    expect(find.text('Player 2'), findsOneWidget);
    expect(find.text("PLAYER 1'S TURN • X"), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('tic-tac-toe-cell-4')));
    expect(tappedCell, 4);
  });

  testWidgets('shows occupied cells and the next participant', (tester) async {
    final model = TicTacToeModel();
    expect(model.play(0, 0), TicTacToeMoveResult.accepted);
    await tester.pumpWidget(board(model));

    expect(find.text('X'), findsNWidgets(2));
    expect(find.text("PLAYER 2'S TURN • O"), findsOneWidget);
    expect(find.bySemanticsLabel('Cell 1, X'), findsOneWidget);
  });

  testWidgets('emphasizes the winning line and winner', (tester) async {
    final model = TicTacToeModel();
    for (final move in const [(0, 0), (1, 3), (0, 1), (1, 4), (0, 2)]) {
      expect(model.play(move.$1, move.$2), TicTacToeMoveResult.accepted);
    }
    await tester.pumpWidget(board(model));

    expect(find.text('PLAYER 1 WINS'), findsOneWidget);
    expect(find.text('Player 1 wins'), findsOneWidget);
    for (final cell in const [1, 2, 3]) {
      expect(
        find.bySemanticsLabel('Cell $cell, X, winning cell'),
        findsOneWidget,
      );
    }
  });

  testWidgets('shows a distinct full-board draw state', (tester) async {
    final model = TicTacToeModel();
    const cells = [0, 1, 2, 4, 3, 5, 7, 6, 8];
    for (var turn = 0; turn < cells.length; turn++) {
      expect(
        model.play(turn.isEven ? 0 : 1, cells[turn]),
        TicTacToeMoveResult.accepted,
      );
    }
    await tester.pumpWidget(board(model));

    expect(find.text('DRAW • BOARD FULL'), findsOneWidget);
    expect(find.bySemanticsLabel('Cell 1, X, draw'), findsOneWidget);
  });

  testWidgets('fits a compact portrait phone without layout overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(board(TicTacToeModel()));

    expect(find.byType(TicTacToeBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('friend match reports a result and rematch alternates starter', (
    tester,
  ) async {
    final session = MatchSession(options: const MatchOptions.friend())..start();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: TicTacToeView(session: session, options: session.options),
        ),
      ),
    );

    for (final cell in const [0, 3, 1, 4, 2]) {
      await tester.tap(find.byKey(ValueKey('tic-tac-toe-cell-$cell')));
      await tester.pump();
    }
    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 0);
    expect(find.text('PLAYER 1 WINS'), findsOneWidget);

    session.start();
    await tester.pump();
    expect(find.text("PLAYER 2'S TURN • O"), findsOneWidget);
    expect(find.bySemanticsLabel('Cell 1, empty'), findsOneWidget);
  });

  testWidgets('bot turn is visibly delayed and blocks additional human taps', (
    tester,
  ) async {
    final session = MatchSession(
      options: const MatchOptions.bot(difficulty: BotDifficulty.easy),
    )..start();
    addTearDown(session.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: TicTacToeView(session: session, options: session.options),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('tic-tac-toe-cell-0')));
    await tester.pump();
    expect(find.text('BOT IS THINKING… • O'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('tic-tac-toe-cell-1')),
      warnIfMissed: false,
    );
    await tester.pump();
    expect(find.bySemanticsLabel('Cell 2, empty'), findsOneWidget);
  });

  test('catalog registers Tic-Tac-Toe and favourites can move it first', () {
    final game = gameCatalog.singleWhere((item) => item.id == 'tic-tac-toe');

    expect(game.supportedModes, {PlayMode.friend, PlayMode.bot});
    expect(game.matchLabel!(const MatchOptions.friend()), 'THREE IN A ROW');
    expect(favouritesFirst(gameCatalog, {game.id}).first, same(game));
  });
}
