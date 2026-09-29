import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/snakes_and_ladders/snakes_and_ladders_controller.dart';

MatchOptions _options(int count) => MatchOptions.custom(
  mode: PlayMode.friend,
  participants: [
    const MatchParticipant.human(
      displayName: 'One',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    const MatchParticipant.human(
      displayName: 'Two',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
    ),
    if (count > 2)
      const MatchParticipant.human(
        displayName: 'Three',
        color: ParticipantColor.gold,
        token: ParticipantToken.triangle,
      ),
    if (count > 3)
      const MatchParticipant.human(
        displayName: 'Four',
        color: ParticipantColor.violet,
        token: ParticipantToken.star,
      ),
  ],
);

class _Dice {
  _Dice(this.values);
  final List<int> values;
  var index = 0;
  int roll() => values[index++];
}

void main() {
  testWidgets('animates each square and locks rolling until movement ends', (
    tester,
  ) async {
    final session = MatchSession(options: _options(2))..start();
    final dice = _Dice([3]);
    final controller = SnakesAndLaddersController(
      session: session,
      diceRoller: dice.roll,
      movementStepDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.roll();
    expect(controller.canRoll, isFalse);
    expect(controller.highlightedPlayer, 0);
    expect(controller.displayPositions, [0, 0]);

    await tester.pump(const Duration(milliseconds: 11));
    expect(controller.displayPositions, [1, 0]);
    await tester.pumpAndSettle();

    expect(controller.displayPositions, [16, 0]);
    expect(controller.canRoll, isTrue);
    expect(controller.highlightedPlayer, 1);
  });

  testWidgets('pause freezes an animation and resume continues its path', (
    tester,
  ) async {
    final session = MatchSession(options: _options(2))..start();
    final controller = SnakesAndLaddersController(
      session: session,
      diceRoller: () => 3,
      movementStepDuration: const Duration(milliseconds: 10),
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    controller.roll();
    await tester.pump(const Duration(milliseconds: 11));
    session.pause();
    await tester.pump(const Duration(milliseconds: 100));
    expect(controller.displayPositions, [1, 0]);

    session.resume();
    await tester.pumpAndSettle();
    expect(controller.displayPositions, [16, 0]);
    expect(controller.canRoll, isTrue);
  });

  testWidgets('four-player finish publishes ordered standings and rematches', (
    tester,
  ) async {
    final rolls = <int>[
      for (var round = 0; round < 10; round++) ...[6, 5, 4, 3],
      4,
    ];
    final dice = _Dice(rolls);
    final session = MatchSession(options: _options(4))..start();
    final controller = SnakesAndLaddersController(
      session: session,
      diceRoller: dice.roll,
      transitions: const {},
      movementStepDuration: Duration.zero,
    );
    addTearDown(controller.dispose);
    addTearDown(session.dispose);

    for (var turn = 0; turn < rolls.length; turn++) {
      controller.roll();
      await tester.pumpAndSettle();
    }

    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 0);
    expect(session.scores, [64, 50, 40, 30]);
    expect(session.standings, [0, 1, 2, 3]);
    expect(session.resultDetails, 'One reached square 64. • Another race?');

    session.start();
    expect(controller.displayPositions, [0, 0, 0, 0]);
    expect(controller.model.positions, [0, 0, 0, 0]);
    expect(controller.lastRoll, isNull);
    expect(controller.canRoll, isTrue);
  });

  testWidgets('dispose cancels pending movement', (tester) async {
    final session = MatchSession(options: _options(2))..start();
    final controller = SnakesAndLaddersController(
      session: session,
      diceRoller: () => 6,
      movementStepDuration: const Duration(milliseconds: 10),
    );
    controller.roll();
    controller.dispose();

    await tester.pump(const Duration(seconds: 1));
    expect(controller.displayPositions, [0, 0]);
    session.dispose();
  });
}
