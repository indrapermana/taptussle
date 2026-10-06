import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_model.dart';

void main() {
  group('NutsAndBoltsModel', () {
    test('uses four-nut bolts and exposes immutable state', () {
      final source = [
        [0, 1],
        <int>[],
      ];
      final model = NutsAndBoltsModel(bolts: source);
      source[0][0] = 9;

      expect(model.capacity, 4);
      expect(model.bolts, [
        [0, 1],
        <int>[],
      ]);
      expect(() => model.bolts.add([]), throwsUnsupportedError);
      expect(() => model.bolts.first.add(2), throwsUnsupportedError);
      expect(
        () => model.legalMoves.add(model.legalMoves.first),
        throwsUnsupportedError,
      );
    });

    test('moves only the exposed top nut onto an empty bolt', () {
      final model = NutsAndBoltsModel(
        bolts: [
          [0, 1, 1],
          <int>[],
          [0],
        ],
      );

      final result = model.move(0, 1);

      expect(result.status, NutsAndBoltsMoveStatus.accepted);
      expect(
        result.move,
        const NutsAndBoltsMove(source: 0, destination: 1, color: 1),
      );
      expect(result.model.bolts, [
        [0, 1],
        [1],
        [0],
      ]);
      expect(result.model.moveCount, 1);
      expect(model.bolts[0], [0, 1, 1]);
      expect(model.moveCount, 0);
    });

    test('allows a top nut onto the same color and moves one at a time', () {
      final initial = NutsAndBoltsModel(
        bolts: [
          [0, 1, 1],
          [2, 1],
          <int>[],
        ],
      );

      final first = initial.move(0, 1).model;
      final second = first.move(0, 1).model;

      expect(first.bolts, [
        [0, 1],
        [2, 1, 1],
        <int>[],
      ]);
      expect(second.bolts, [
        [0],
        [2, 1, 1, 1],
        <int>[],
      ]);
      expect(second.moveCount, 2);
    });

    test('reports invalid moves without changing the puzzle', () {
      final model = NutsAndBoltsModel(
        bolts: [
          [0, 1],
          [0, 0, 0, 0],
          [2],
          <int>[],
        ],
      );
      final cases = <(int, int, NutsAndBoltsMoveStatus)>[
        (-1, 0, NutsAndBoltsMoveStatus.sourceOutOfRange),
        (0, 4, NutsAndBoltsMoveStatus.destinationOutOfRange),
        (0, 0, NutsAndBoltsMoveStatus.sameBolt),
        (3, 0, NutsAndBoltsMoveStatus.sourceEmpty),
        (0, 1, NutsAndBoltsMoveStatus.destinationFull),
        (0, 2, NutsAndBoltsMoveStatus.colorMismatch),
      ];

      for (final (source, destination, expected) in cases) {
        final result = model.move(source, destination);
        expect(result.status, expected);
        expect(result.accepted, isFalse);
        expect(identical(result.model, model), isTrue);
        expect(result.move, isNull);
      }
      expect(model.moveCount, 0);
    });

    test('lists every legal single-nut move', () {
      final model = NutsAndBoltsModel(
        bolts: [
          [0, 1],
          [2, 1],
          [0, 0, 0, 0],
          <int>[],
        ],
      );

      expect(model.canMove(0, 1), isTrue);
      expect(model.canMove(0, 2), isFalse);
      expect(
        model.legalMoves,
        unorderedEquals(const [
          NutsAndBoltsMove(source: 0, destination: 1, color: 1),
          NutsAndBoltsMove(source: 0, destination: 3, color: 1),
          NutsAndBoltsMove(source: 1, destination: 0, color: 1),
          NutsAndBoltsMove(source: 1, destination: 3, color: 1),
          NutsAndBoltsMove(source: 2, destination: 3, color: 0),
        ]),
      );
    });

    test('completion requires every occupied bolt to be full and uniform', () {
      final incompleteShort = NutsAndBoltsModel(
        bolts: [
          [0, 0],
          [1, 1, 1, 1],
          <int>[],
        ],
      );
      final incompleteMixed = NutsAndBoltsModel(
        bolts: [
          [0, 0, 0, 1],
          [1, 1, 1, 0],
          <int>[],
        ],
      );
      final complete = NutsAndBoltsModel(
        bolts: [
          [0, 0, 0, 0],
          [1, 1, 1, 1],
          <int>[],
        ],
      );

      expect(incompleteShort.isComplete, isFalse);
      expect(incompleteMixed.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
      expect(complete.legalMoves, isEmpty);
      expect(complete.hint, isNull);
      expect(
        complete.move(0, 2).status,
        NutsAndBoltsMoveStatus.puzzleCompleted,
      );
    });

    test('undo walks back accepted moves and ignores invalid moves', () {
      final initial = NutsAndBoltsModel(
        bolts: [
          [0, 1],
          [0, 1],
          <int>[],
        ],
      );
      final first = initial.move(0, 2).model;
      final invalid = first.move(0, 1).model;
      final second = invalid.move(1, 2).model;

      expect(second.moveCount, 2);
      expect(second.canUndo, isTrue);
      final undoneOnce = second.undo();
      expect(undoneOnce.bolts, first.bolts);
      expect(undoneOnce.moveHistory, first.moveHistory);
      final undoneTwice = undoneOnce.undo();
      expect(undoneTwice.bolts, initial.bolts);
      expect(undoneTwice.moveCount, 0);
      expect(undoneTwice.canUndo, isFalse);
      expect(identical(undoneTwice.undo(), undoneTwice), isTrue);
    });

    test('restart restores the exact initial puzzle and clears history', () {
      final initial = NutsAndBoltsModel(
        bolts: [
          [0, 1],
          [0, 1],
          <int>[],
        ],
      );
      final moved = initial.move(0, 2).model.move(1, 2).model;

      final restarted = moved.restart();

      expect(restarted.bolts, initial.bolts);
      expect(restarted.moveCount, 0);
      expect(restarted.moveHistory, isEmpty);
      expect(restarted.canUndo, isFalse);
      expect(restarted.lastMove, isNull);
      expect(identical(restarted.restart(), restarted), isTrue);
    });

    test('hint is stable and prefers completing a matching stack', () {
      final model = NutsAndBoltsModel(
        bolts: [
          [0, 1],
          [1, 1, 1],
          [3],
          <int>[],
        ],
      );

      expect(
        model.hint,
        const NutsAndBoltsMove(source: 0, destination: 1, color: 1),
      );
      expect(model.hint, model.hint);
      expect(model.moveCount, 0);
    });

    test('restores by replaying a validated deterministic move history', () {
      final initial = [
        [0, 1],
        [0, 1],
        <int>[],
      ];
      const moves = [
        NutsAndBoltsMove(source: 0, destination: 2, color: 1),
        NutsAndBoltsMove(source: 1, destination: 2, color: 1),
      ];

      final restored = NutsAndBoltsModel.restore(
        initialBolts: initial,
        moves: moves,
      );

      expect(restored.bolts, [
        [0],
        [0],
        [1, 1],
      ]);
      expect(restored.moveHistory, moves);
      expect(restored.moveCount, 2);
      expect(
        () => NutsAndBoltsModel.restore(
          initialBolts: initial,
          moves: const [NutsAndBoltsMove(source: 0, destination: 1, color: 0)],
        ),
        throwsFormatException,
      );
    });

    test('rejects malformed puzzle definitions', () {
      expect(
        () => NutsAndBoltsModel(
          capacity: 1,
          bolts: [
            [0],
            [],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NutsAndBoltsModel(
          bolts: [
            [0],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NutsAndBoltsModel(bolts: [<int>[], <int>[]]),
        throwsArgumentError,
      );
      expect(
        () => NutsAndBoltsModel(
          bolts: [
            [0, 0, 0, 0, 0],
            <int>[],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => NutsAndBoltsModel(
          bolts: [
            [-1],
            <int>[],
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
