import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/ludo/ludo_controller.dart';
import 'package:tap_tussle/games/ludo/ludo_model.dart';

void main() {
  testWidgets('animates a chosen token one board space at a time', (
    tester,
  ) async {
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 3,
      tokenProgress: const [
        [0, -1, -1, -1],
        [-1, -1, -1, -1],
      ],
    );
    final controller = LudoController(
      playerCount: 2,
      model: model,
      movementStepDuration: const Duration(milliseconds: 100),
    );
    addTearDown(controller.dispose);

    expect(controller.roll()?.legalTokenIndexes, [0]);
    expect(controller.chooseToken(0), LudoMoveResult.accepted);
    expect(controller.isAnimating, isTrue);
    expect(controller.displayProgress[0][0], 0);
    expect(model.progressFor(0, 0), 3);

    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 1);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 2);
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayProgress[0][0], 3);
    expect(controller.isAnimating, isFalse);
    expect(controller.canRoll, isTrue);
  });

  test('locks rolling during token choice and rejects unavailable tokens', () {
    final controller = LudoController(
      playerCount: 2,
      diceRoller: () => 6,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.roll();

    expect(controller.canRoll, isFalse);
    expect(controller.canChooseToken, isTrue);
    expect(controller.legalTokenIndexes, [0, 1, 2, 3]);
    expect(controller.chooseToken(4), LudoMoveResult.invalidToken);
    expect(controller.chooseToken(2), LudoMoveResult.accepted);
    expect(controller.displayProgress[0][2], 0);
    expect(controller.canRoll, isTrue);
  });

  test('synchronizes captured tokens after movement completes', () {
    final model = LudoModel.fromState(
      playerCount: 2,
      diceRoller: () => 1,
      tokenProgress: const [
        [4, -1, -1, -1],
        [44, -1, -1, -1],
      ],
    );
    final controller = LudoController(
      playerCount: 2,
      model: model,
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);

    controller.roll();
    controller.chooseToken(0);

    expect(controller.displayProgress[0][0], 5);
    expect(controller.displayProgress[1][0], LudoModel.boxProgress);
    expect(controller.model.lastMove?.wasCapture, isTrue);
  });

  test('validates a supplied model participant count', () {
    final model = LudoModel(playerCount: 2, diceRoller: () => 1);
    expect(
      () => LudoController(playerCount: 3, model: model),
      throwsArgumentError,
    );
  });
}
