import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/water_sort/water_sort_model.dart';

void main() {
  group('WaterSortModel', () {
    test('uses four-unit tubes and protects all exposed collections', () {
      final source = [
        [0, 1],
        <int>[],
      ];
      final model = WaterSortModel(tubes: source);
      source[0][0] = 9;

      expect(model.capacity, 4);
      expect(model.tubes, [
        [0, 1],
        <int>[],
      ]);
      expect(() => model.tubes.add([]), throwsUnsupportedError);
      expect(() => model.tubes.first.add(2), throwsUnsupportedError);
      expect(
        () => model.legalMoves.add(model.legalMoves.first),
        throwsUnsupportedError,
      );
    });

    test('pours the complete matching top group into an empty tube', () {
      final model = WaterSortModel(
        tubes: [
          [0, 1, 1],
          <int>[],
          [0],
        ],
      );

      final result = model.pour(0, 1);

      expect(result.status, WaterSortPourStatus.accepted);
      expect(
        result.move,
        const WaterSortMove(source: 0, destination: 1, color: 1, amount: 2),
      );
      expect(result.model.tubes, [
        [0],
        [1, 1],
        [0],
      ]);
      expect(result.model.moveCount, 1);
      expect(model.moveCount, 0);
      expect(model.tubes[0], [0, 1, 1]);
    });

    test('limits a matching pour to the available destination space', () {
      final model = WaterSortModel(
        tubes: [
          [2, 2, 2],
          [1, 1, 2],
          <int>[],
        ],
      );

      final result = model.pour(0, 1);

      expect(result.move?.amount, 1);
      expect(result.model.tubes, [
        [2, 2],
        [1, 1, 2, 2],
        <int>[],
      ]);
    });

    test('reports every invalid pour without changing state or move count', () {
      final model = WaterSortModel(
        tubes: [
          [0, 1],
          [0, 0, 0, 0],
          [2],
          <int>[],
        ],
      );

      final cases = <(int, int, WaterSortPourStatus)>[
        (-1, 0, WaterSortPourStatus.sourceOutOfRange),
        (0, 4, WaterSortPourStatus.destinationOutOfRange),
        (0, 0, WaterSortPourStatus.sameTube),
        (3, 0, WaterSortPourStatus.sourceEmpty),
        (0, 1, WaterSortPourStatus.destinationFull),
        (0, 2, WaterSortPourStatus.colorMismatch),
      ];

      for (final (source, destination, expected) in cases) {
        final result = model.pour(source, destination);
        expect(result.status, expected);
        expect(result.accepted, isFalse);
        expect(identical(result.model, model), isTrue);
        expect(result.move, isNull);
      }
      expect(model.moveCount, 0);
    });

    test('lists only legal pours with their actual amount', () {
      final model = WaterSortModel(
        tubes: [
          [0, 1, 1],
          [2, 1],
          [0, 0, 0, 0],
          <int>[],
        ],
      );

      expect(model.canPour(0, 1), isTrue);
      expect(model.canPour(0, 2), isFalse);
      expect(
        model.legalMoves,
        containsAll([
          const WaterSortMove(source: 0, destination: 1, color: 1, amount: 2),
          const WaterSortMove(source: 0, destination: 3, color: 1, amount: 2),
          const WaterSortMove(source: 1, destination: 0, color: 1, amount: 1),
          const WaterSortMove(source: 1, destination: 3, color: 1, amount: 1),
          const WaterSortMove(source: 2, destination: 3, color: 0, amount: 4),
        ]),
      );
      expect(model.legalMoves, hasLength(5));
    });

    test('completion requires every non-empty tube to be full and uniform', () {
      final incompleteShort = WaterSortModel(
        tubes: [
          [0, 0],
          [1, 1, 1, 1],
          <int>[],
        ],
      );
      final incompleteMixed = WaterSortModel(
        tubes: [
          [0, 0, 0, 1],
          [1, 1, 1, 0],
          <int>[],
        ],
      );
      final complete = WaterSortModel(
        tubes: [
          [0, 0, 0, 0],
          [1, 1, 1, 1],
          <int>[],
        ],
      );

      expect(incompleteShort.isComplete, isFalse);
      expect(incompleteMixed.isComplete, isFalse);
      expect(complete.isComplete, isTrue);
      expect(complete.legalMoves, isEmpty);
      expect(complete.pour(0, 2).status, WaterSortPourStatus.puzzleCompleted);
    });

    test('undo walks back accepted moves and never counts invalid moves', () {
      final initial = WaterSortModel(
        tubes: [
          [0, 1],
          [0, 1],
          <int>[],
        ],
      );
      final first = initial.pour(0, 2).model;
      final invalid = first.pour(0, 1).model;
      final second = invalid.pour(1, 2).model;

      expect(second.moveCount, 2);
      expect(second.canUndo, isTrue);
      final undoneOnce = second.undo();
      expect(undoneOnce.tubes, first.tubes);
      expect(undoneOnce.moveCount, 1);
      final undoneTwice = undoneOnce.undo();
      expect(undoneTwice.tubes, initial.tubes);
      expect(undoneTwice.moveCount, 0);
      expect(undoneTwice.canUndo, isFalse);
      expect(identical(undoneTwice.undo(), undoneTwice), isTrue);
    });

    test('restart restores the exact initial board and clears history', () {
      final initial = WaterSortModel(
        tubes: [
          [0, 1],
          [0, 1],
          <int>[],
        ],
      );
      final moved = initial.pour(0, 2).model.pour(1, 2).model;

      final restarted = moved.restart();

      expect(restarted.tubes, initial.tubes);
      expect(restarted.moveCount, 0);
      expect(restarted.canUndo, isFalse);
      expect(restarted.lastMove, isNull);
      expect(identical(restarted.restart(), restarted), isTrue);
    });

    test('rejects malformed puzzle definitions', () {
      expect(
        () => WaterSortModel(
          capacity: 1,
          tubes: [
            [0],
            [],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => WaterSortModel(
          tubes: [
            [0],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => WaterSortModel(tubes: [<int>[], <int>[]]),
        throwsArgumentError,
      );
      expect(
        () => WaterSortModel(
          tubes: [
            [0, 0, 0, 0, 0],
            <int>[],
          ],
        ),
        throwsArgumentError,
      );
      expect(
        () => WaterSortModel(
          tubes: [
            [-1],
            <int>[],
          ],
        ),
        throwsArgumentError,
      );
    });
  });
}
