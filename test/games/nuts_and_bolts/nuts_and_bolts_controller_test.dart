import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_controller.dart';
import 'package:tap_tussle/games/nuts_and_bolts/nuts_and_bolts_levels.dart';

void main() {
  group('NutsAndBoltsController', () {
    test(
      'selects sources, exposes legal targets, and locks during movement',
      () {
        final controller = NutsAndBoltsController(
          level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
          animationDuration: const Duration(days: 1),
        );
        addTearDown(controller.dispose);
        final hint = controller.model.hint!;

        expect(controller.tapBolt(hint.source), NutsAndBoltsTapResult.selected);
        expect(controller.selectedBolt, hint.source);
        expect(controller.isLegalDestination(hint.destination), isTrue);

        expect(
          controller.tapBolt(hint.destination),
          NutsAndBoltsTapResult.moved,
        );
        expect(controller.model.moveCount, 1);
        expect(controller.isAnimating, isTrue);
        expect(
          controller.tapBolt(hint.source),
          NutsAndBoltsTapResult.inputLocked,
        );
        expect(controller.undo(), isFalse);
      },
    );

    test('invalid target selects another non-empty source', () {
      final controller = NutsAndBoltsController(
        level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
      );
      addTearDown(controller.dispose);
      final source = controller.model.bolts.indexWhere(
        (bolt) => bolt.isNotEmpty,
      );
      final target = List.generate(controller.model.boltCount, (index) => index)
          .firstWhere(
            (index) =>
                index != source &&
                controller.model.bolts[index].isNotEmpty &&
                !controller.model.canMove(source, index),
          );

      controller.tapBolt(source);
      expect(
        controller.tapBolt(target),
        NutsAndBoltsTapResult.selectionChanged,
      );
      expect(controller.selectedBolt, target);
    });

    test('hint, undo, and restart keep state coherent', () {
      final controller = NutsAndBoltsController(
        level: NutsAndBoltsLevelCatalog.level(NutsAndBoltsDifficulty.easy, 1),
        animationDuration: Duration.zero,
      );
      addTearDown(controller.dispose);

      final hint = controller.requestHint()!;
      expect(controller.hintMove, hint);
      controller.tapBolt(hint.source);
      controller.tapBolt(hint.destination);
      expect(controller.model.moveCount, 1);
      expect(controller.hintMove, isNull);
      expect(controller.undo(), isTrue);
      expect(controller.model.moveCount, 0);

      final secondHint = controller.requestHint()!;
      controller.tapBolt(secondHint.source);
      controller.tapBolt(secondHint.destination);
      expect(controller.restart(), isTrue);
      expect(controller.model.moveCount, 0);
      expect(controller.model.bolts, controller.level.bolts);
    });
  });
}
