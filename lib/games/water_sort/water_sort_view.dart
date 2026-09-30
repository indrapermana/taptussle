import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import 'water_sort_controller.dart';
import 'water_sort_levels.dart';
import 'water_sort_model.dart';

class WaterSortView extends StatefulWidget {
  const WaterSortView({
    required this.level,
    this.initialModel,
    this.controller,
    super.key,
  });

  final WaterSortLevel level;
  final WaterSortModel? initialModel;
  final WaterSortController? controller;

  @override
  State<WaterSortView> createState() => _WaterSortViewState();
}

class _WaterSortViewState extends State<WaterSortView> {
  late final WaterSortController controller =
      widget.controller ??
      WaterSortController(
        level: widget.level,
        initialModel: widget.initialModel,
      );
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => WaterSortBoard(controller: controller);
}

class WaterSortBoard extends StatelessWidget {
  const WaterSortBoard({required this.controller, super.key});

  final WaterSortController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => TapTussleBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            final columns = constraints.maxWidth < 370
                ? 4
                : constraints.maxWidth < 650
                ? 5
                : 7;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 8 : 16, 12, 10),
              child: Column(
                children: [
                  _Header(controller: controller, compact: compact),
                  SizedBox(height: compact ? 6 : 12),
                  Expanded(
                    child: GridView.builder(
                      key: const ValueKey('water-sort-board'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: compact ? .48 : .43,
                        crossAxisSpacing: compact ? 6 : 10,
                        mainAxisSpacing: compact ? 8 : 12,
                      ),
                      itemCount: controller.model.tubeCount,
                      itemBuilder: (context, tube) => _Tube(
                        index: tube,
                        controller: controller,
                        compact: compact,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 5 : 10),
                  _Controls(controller: controller, compact: compact),
                ],
              ),
            );
          },
        ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.compact});

  final WaterSortController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final level = controller.level;
    final status = controller.model.isComplete
        ? 'PUZZLE COMPLETE!'
        : controller.isAnimating
        ? 'POURING…'
        : controller.hintMove != null
        ? 'HINT: TUBE ${controller.hintMove!.source + 1} → ${controller.hintMove!.destination + 1}'
        : controller.selectedTube != null
        ? 'CHOOSE A DESTINATION'
        : 'CHOOSE A TUBE';
    return ArcadePanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      accent: controller.model.isComplete
          ? TapTussleColors.gold
          : TapTussleColors.electricBlue,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${level.difficulty.label.toUpperCase()} • LEVEL ${level.number}',
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    color: TapTussleColors.electricBlue,
                    fontSize: 15,
                  ),
                ),
                Text(
                  status,
                  key: const ValueKey('water-sort-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    fontSize: compact ? 17 : 21,
                    color: controller.model.isComplete
                        ? TapTussleColors.gold
                        : TapTussleColors.text,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${controller.model.moveCount} MOVES',
            key: const ValueKey('water-sort-moves'),
            semanticsLabel: '${controller.model.moveCount} moves',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Tube extends StatelessWidget {
  const _Tube({
    required this.index,
    required this.controller,
    required this.compact,
  });

  final int index;
  final WaterSortController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final contents = controller.model.tubes[index];
    final selected = controller.selectedTube == index;
    final animation = controller.animatingMove;
    final sourceAnimating = animation?.source == index;
    final destinationAnimating = animation?.destination == index;
    final hintSource = controller.hintMove?.source == index;
    final hintDestination = controller.hintMove?.destination == index;
    final label = contents.isEmpty
        ? 'Tube ${index + 1}, empty'
        : 'Tube ${index + 1}, bottom to top: ${contents.map(_liquidName).join(', ')}';
    final selectedLabel = selected ? ', selected' : '';
    final hintLabel = hintSource
        ? ', hint source'
        : hintDestination
        ? ', hint destination'
        : '';

    return Semantics(
      label: '$label$selectedLabel$hintLabel',
      button: true,
      selected: selected,
      enabled: controller.acceptsInput,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('water-sort-tube-$index'),
          borderRadius: BorderRadius.circular(22),
          onTap: controller.acceptsInput
              ? () => controller.tapTube(index)
              : null,
          child: AnimatedRotation(
            turns: sourceAnimating ? .045 : 0,
            duration: controller.animationDuration,
            curve: Curves.easeInOut,
            child: AnimatedScale(
              scale: destinationAnimating ? 1.08 : 1,
              duration: controller.animationDuration,
              curve: Curves.easeOutBack,
              child: Column(
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: hintSource || hintDestination
                          ? TapTussleColors.gold
                          : TapTussleColors.mutedText,
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.fromLTRB(5, 10, 5, 5),
                      decoration: BoxDecoration(
                        color: const Color(0x6610294A),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                          top: Radius.circular(8),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: _borderColor(
                              selected,
                              hintSource,
                              hintDestination,
                            ),
                            width: selected ? 4 : 2.5,
                          ),
                          right: BorderSide(
                            color: _borderColor(
                              selected,
                              hintSource,
                              hintDestination,
                            ),
                            width: selected ? 4 : 2.5,
                          ),
                          bottom: BorderSide(
                            color: _borderColor(
                              selected,
                              hintSource,
                              hintDestination,
                            ),
                            width: selected ? 4 : 2.5,
                          ),
                        ),
                        boxShadow: selected || hintSource || hintDestination
                            ? [
                                BoxShadow(
                                  color: _borderColor(
                                    selected,
                                    hintSource,
                                    hintDestination,
                                  ).withValues(alpha: .4),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        children: [
                          for (
                            var slot = controller.model.capacity - 1;
                            slot >= 0;
                            slot--
                          )
                            Expanded(
                              child: slot < contents.length
                                  ? _LiquidLayer(colorId: contents[slot])
                                  : const SizedBox.expand(),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Color _borderColor(bool selected, bool hintSource, bool hintDestination) {
    if (selected) return TapTussleColors.electricBlue;
    if (hintSource || hintDestination) return TapTussleColors.gold;
    return const Color(0xFF7FA6C8);
  }
}

class _LiquidLayer extends StatelessWidget {
  const _LiquidLayer({required this.colorId});

  final int colorId;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: _liquidColors[colorId % _liquidColors.length],
      border: Border.all(color: Colors.white.withValues(alpha: .24), width: .5),
    ),
    child: Center(
      child: FittedBox(
        child: Text(
          _liquidSymbols[colorId % _liquidSymbols.length],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
          ),
        ),
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.compact});

  final WaterSortController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('water-sort-undo'),
          onPressed: !controller.isAnimating && controller.model.canUndo
              ? controller.undo
              : null,
          icon: const Icon(Icons.undo_rounded),
          label: Text(compact ? 'UNDO' : 'UNDO MOVE'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('water-sort-restart'),
          onPressed: !controller.isAnimating && controller.model.moveCount > 0
              ? controller.restart
              : null,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('RESTART'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton.icon(
          key: const ValueKey('water-sort-hint'),
          onPressed: controller.acceptsInput ? controller.requestHint : null,
          icon: const Icon(Icons.lightbulb_rounded),
          label: const Text('HINT'),
        ),
      ),
    ],
  );
}

const _liquidColors = [
  Color(0xFFFF4F59),
  Color(0xFF27C7FF),
  Color(0xFFFFD338),
  Color(0xFF55D98B),
  Color(0xFFA970FF),
  Color(0xFFFF8C42),
  Color(0xFFFF67C4),
  Color(0xFF43E6D0),
  Color(0xFF8EA7FF),
  Color(0xFFB7E33D),
  Color(0xFFFF9DB0),
  Color(0xFF9A6B4F),
];

const _liquidNames = [
  'red circle',
  'blue triangle',
  'yellow diamond',
  'green star',
  'purple plus',
  'orange cross',
  'pink bars',
  'cyan waves',
  'indigo hollow diamond',
  'lime square',
  'rose heart',
  'brown sun',
];

const _liquidSymbols = [
  '●',
  '▲',
  '◆',
  '★',
  '+',
  '×',
  '=',
  '≋',
  '◇',
  '■',
  '♥',
  '☀',
];

String _liquidName(int color) => _liquidNames[color % _liquidNames.length];
