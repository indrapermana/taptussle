import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/mancala/mancala_controller.dart';
import 'package:tap_tussle/games/mancala/mancala_model.dart';

void main() {
  testWidgets('animates each sown stone and locks input until settled', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      sowingStepDuration: const Duration(milliseconds: 10),
      settleDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    expect(controller.tapPit(0, 2), MancalaTapResult.accepted);
    expect(controller.displayBoard.take(7), [4, 4, 0, 4, 4, 4, 0]);
    expect(controller.activePosition, 2);
    expect(controller.acceptsInput, isFalse);
    expect(controller.tapPit(0, 0), MancalaTapResult.ignored);

    for (final position in [3, 4, 5, 6]) {
      await tester.pump(const Duration(milliseconds: 10));
      expect(controller.activePosition, position);
    }
    expect(controller.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 10));

    expect(controller.isAnimating, isFalse);
    expect(controller.activePosition, isNull);
    expect(controller.displayBoard, controller.model.board);
    expect(controller.acceptsInput, isTrue);
  });

  test('ignores wrong-side and empty-pit input without mutation', () {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final model = MancalaModel.fromBoard(
      board: const [1, 0, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 1, 0],
    );
    final controller = MancalaController(session: session, model: model);
    addTearDown(controller.dispose);
    addTearDown(session.dispose);
    final before = model.board;

    expect(controller.tapPit(1, 0), MancalaTapResult.ignored);
    expect(controller.tapPit(0, 1), MancalaTapResult.ignored);
    expect(model.board, before);
    expect(controller.isAnimating, isFalse);
  });

  testWidgets('publishes final store scores after the animation settles', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      model: MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
      ),
      sowingStepDuration: const Duration(milliseconds: 10),
      settleDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.tapPit(0, 5);
    expect(controller.model.isFinished, isTrue);
    expect(session.phase, MatchPhase.playing);
    await tester.pump(const Duration(milliseconds: 20));

    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 1);
    expect(session.scores, [21, 23]);
    expect(session.resultDetails, contains('Player 2'));
  });

  testWidgets('pause settles safely and rematch alternates the starter', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    final controller = MancalaController(
      session: session,
      sowingStepDuration: const Duration(milliseconds: 20),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.tapPit(0, 2);
    session.pause();
    expect(controller.isAnimating, isFalse);
    expect(controller.displayBoard, controller.model.board);
    expect(controller.tapPit(0, 0), MancalaTapResult.ignored);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    session.resume();
    expect(controller.acceptsInput, isTrue);

    final finishingSession = MatchSession(options: MatchOptions.friend())
      ..start();
    final finishingController = MancalaController(
      session: finishingSession,
      model: MancalaModel.fromBoard(
        board: const [0, 0, 0, 0, 0, 1, 20, 3, 0, 0, 0, 0, 0, 20],
      ),
      sowingStepDuration: Duration.zero,
      settleDuration: Duration.zero,
    );
    addTearDown(finishingController.dispose);
    addTearDown(finishingSession.dispose);
    finishingController.tapPit(0, 5);
    await tester.pumpAndSettle();
    expect(finishingSession.phase, MatchPhase.finished);

    finishingSession.start();
    expect(finishingController.model.startingPlayer, 1);
    expect(finishingController.model.currentPlayer, 1);
    expect(finishingController.model.board.fold(0, (a, b) => a + b), 48);
  });
}
