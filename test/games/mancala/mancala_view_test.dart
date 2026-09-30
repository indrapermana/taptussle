import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/mancala/mancala_controller.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';
import 'package:tap_tussle/games/mancala/mancala_view.dart';

void main() {
  Widget board(
    MancalaModel model, {
    List<int>? displayedBoard,
    int? activePosition,
    bool isAnimating = false,
    bool enabled = true,
    MancalaTapResult Function(int, int)? onPitTap,
  }) => MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: Scaffold(
      body: MancalaBoard(
        model: model,
        displayedBoard: displayedBoard,
        activePosition: activePosition,
        isAnimating: isAnimating,
        enabled: enabled,
        onPitTap: onPitTap ?? (_, _) => MancalaTapResult.ignored,
      ),
    ),
  );

  testWidgets('shows twelve pits, both stores, ownership, and current turn', (
    tester,
  ) async {
    await tester.pumpWidget(board(MancalaModel()));

    for (var player = 0; player < 2; player++) {
      for (var pit = 0; pit < 6; pit++) {
        expect(
          find.byKey(ValueKey('mancala-pit-$player-$pit')),
          findsOneWidget,
        );
      }
      expect(find.byKey(ValueKey('mancala-store-$player')), findsOneWidget);
    }
    expect(find.text("PLAYER 1'S TURN"), findsOneWidget);
    expect(find.text('0 IN STORE'), findsNWidgets(2));
    expect(
      find.bySemanticsLabel('Player 1 pit 1, 4 stones, legal move'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Player 2 pit 1, 4 stones'), findsOneWidget);
  });

  testWidgets('only legal owned pits are interactive', (tester) async {
    (int, int)? tapped;
    await tester.pumpWidget(
      board(
        MancalaModel(),
        onPitTap: (player, pit) {
          tapped = (player, pit);
          return MancalaTapResult.accepted;
        },
      ),
    );

    await tester.tap(find.byKey(const ValueKey('mancala-pit-1-0')));
    expect(tapped, isNull);
    await tester.tap(find.byKey(const ValueKey('mancala-pit-0-3')));
    expect(tapped, (0, 3));
  });

  testWidgets('shows intermediate stone counts and sowing position', (
    tester,
  ) async {
    final model = MancalaModel();
    model.play(0, 2);
    final intermediate = [4, 4, 0, 5, 4, 4, 0, 4, 4, 4, 4, 4, 4, 0];

    await tester.pumpWidget(
      board(
        model,
        displayedBoard: intermediate,
        activePosition: 3,
        isAnimating: true,
        enabled: false,
      ),
    );

    expect(find.text('PLAYER 1 • SOWING…'), findsOneWidget);
    expect(find.bySemanticsLabel('Player 1 pit 4, 5 stones'), findsOneWidget);
    final pit = tester.widget<Semantics>(
      find.bySemanticsLabel('Player 1 pit 4, 5 stones'),
    );
    expect(pit.properties.enabled, isFalse);
  });

  testWidgets('shows extra-turn, winner, draw, and final store states', (
    tester,
  ) async {
    final extraTurn = MancalaModel();
    extraTurn.play(0, 2);
    await tester.pumpWidget(board(extraTurn));
    expect(find.text('PLAYER 1 • EXTRA TURN'), findsOneWidget);

    final winner = MancalaModel.fromBoard(
      board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
    );
    winner.play(0, 5);
    await tester.pumpWidget(board(winner));
    expect(find.text('PLAYER 2 WINS'), findsOneWidget);
    expect(find.text('21 IN STORE'), findsOneWidget);
    expect(find.text('23 IN STORE'), findsOneWidget);

    final draw = MancalaModel.fromBoard(
      board: const [0, 0, 0, 0, 0, 1, 23, 1, 0, 0, 0, 0, 0, 23],
    );
    draw.play(0, 5);
    await tester.pumpWidget(board(draw));
    expect(find.text('DRAW • STORES ARE EVEN'), findsOneWidget);
    expect(find.text('24 IN STORE'), findsNWidgets(2));
  });

  testWidgets('fits compact phone and large tablet sizes without overflow', (
    tester,
  ) async {
    for (final size in [const Size(320, 568), const Size(1024, 768)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(board(MancalaModel()));
      expect(find.byType(MancalaBoard), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });
}
