import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/sound_service.dart';
import 'nuts_and_bolts_controller.dart';
import 'nuts_and_bolts_levels.dart';
import 'nuts_and_bolts_model.dart';

class NutsAndBoltsView extends StatefulWidget {
  const NutsAndBoltsView({
    required this.level,
    this.initialModel,
    this.controller,
    super.key,
  });

  final NutsAndBoltsLevel level;
  final NutsAndBoltsModel? initialModel;
  final NutsAndBoltsController? controller;

  @override
  State<NutsAndBoltsView> createState() => _NutsAndBoltsViewState();
}

class _NutsAndBoltsViewState extends State<NutsAndBoltsView> {
  late final NutsAndBoltsController controller =
      widget.controller ??
      NutsAndBoltsController(
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
  Widget build(BuildContext context) =>
      NutsAndBoltsBoard(controller: controller);
}

class NutsAndBoltsBoard extends StatelessWidget {
  const NutsAndBoltsBoard({required this.controller, super.key});

  final NutsAndBoltsController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => TapTussleBackdrop(
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 650;
            final columns = constraints.maxWidth < 370
                ? 3
                : constraints.maxWidth < 700
                ? 4
                : 6;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 8 : 16, 12, 10),
              child: Column(
                children: [
                  _Header(controller: controller, compact: compact),
                  SizedBox(height: compact ? 6 : 12),
                  Expanded(
                    child: GridView.builder(
                      key: const ValueKey('nuts-bolts-board'),
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        childAspectRatio: compact ? .62 : .58,
                        crossAxisSpacing: compact ? 7 : 11,
                        mainAxisSpacing: compact ? 8 : 12,
                      ),
                      itemCount: controller.model.boltCount,
                      itemBuilder: (context, bolt) => _Bolt(
                        index: bolt,
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

  final NutsAndBoltsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final hint = controller.hintMove;
    final status = controller.model.isComplete
        ? 'ALL COLORS SORTED!'
        : controller.isAnimating
        ? 'MOVING NUT…'
        : hint != null
        ? 'HINT: BOLT ${hint.source + 1} → ${hint.destination + 1}'
        : controller.selectedBolt != null
        ? 'CHOOSE A GLOWING BOLT'
        : 'CHOOSE A TOP NUT';
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
                  '${controller.level.difficulty.label.toUpperCase()} • LEVEL ${controller.level.number}',
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    color: TapTussleColors.electricBlue,
                    fontSize: 15,
                  ),
                ),
                Text(
                  status,
                  key: const ValueKey('nuts-bolts-status'),
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
            key: const ValueKey('nuts-bolts-moves'),
            semanticsLabel: '${controller.model.moveCount} moves',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _Bolt extends StatelessWidget {
  const _Bolt({
    required this.index,
    required this.controller,
    required this.compact,
  });

  final int index;
  final NutsAndBoltsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final contents = controller.model.bolts[index];
    final selected = controller.selectedBolt == index;
    final legalTarget = controller.isLegalDestination(index);
    final animation = controller.animatingMove;
    final sourceAnimating = animation?.source == index;
    final destinationAnimating = animation?.destination == index;
    final hintSource = controller.hintMove?.source == index;
    final hintDestination = controller.hintMove?.destination == index;
    final accessibleContents = contents.isEmpty
        ? 'empty'
        : 'bottom to top: ${contents.map(_nutName).join(', ')}';
    final states = [
      if (selected) 'selected',
      if (legalTarget) 'legal destination',
      if (hintSource) 'hint source',
      if (hintDestination) 'hint destination',
    ];
    final stateLabel = states.isEmpty ? '' : ', ${states.join(', ')}';

    return Semantics(
      label: 'Bolt ${index + 1}, $accessibleContents$stateLabel',
      button: true,
      selected: selected,
      enabled: controller.acceptsInput,
      child: ExcludeSemantics(
        child: InkWell(
          key: ValueKey('nuts-bolts-bolt-$index'),
          borderRadius: BorderRadius.circular(22),
          onTap: controller.acceptsInput
              ? () => _handleTap(controller.tapBolt(index), controller)
              : null,
          child: AnimatedScale(
            scale: destinationAnimating ? 1.08 : 1,
            duration: controller.animationDuration,
            curve: Curves.easeOutBack,
            child: AnimatedSlide(
              offset: sourceAnimating ? const Offset(0, -.08) : Offset.zero,
              duration: controller.animationDuration,
              curve: Curves.easeInOut,
              child: Column(
                children: [
                  Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: hintSource || hintDestination
                          ? TapTussleColors.gold
                          : legalTarget
                          ? const Color(0xFF55D98B)
                          : TapTussleColors.mutedText,
                      fontSize: compact ? 11 : 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      decoration: BoxDecoration(
                        color: const Color(0x5510294A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: _borderColor(
                            selected: selected,
                            legalTarget: legalTarget,
                            hinted: hintSource || hintDestination,
                          ),
                          width: selected || legalTarget ? 3 : 1.5,
                        ),
                        boxShadow:
                            selected ||
                                legalTarget ||
                                hintSource ||
                                hintDestination
                            ? [
                                BoxShadow(
                                  color: _borderColor(
                                    selected: selected,
                                    legalTarget: legalTarget,
                                    hinted: hintSource || hintDestination,
                                  ).withValues(alpha: .42),
                                  blurRadius: 12,
                                ),
                              ]
                            : null,
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          Positioned(
                            top: 8,
                            bottom: 8,
                            child: Container(
                              width: compact ? 12 : 15,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFEAF6FF),
                                    Color(0xFF7897B5),
                                    Color(0xFFD9EEFF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white54),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 5,
                            child: Container(
                              width: compact ? 54 : 66,
                              height: 9,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7897B5),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white54),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(5, 5, 5, 11),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                for (
                                  var empty = contents.length;
                                  empty < controller.model.capacity;
                                  empty++
                                )
                                  const Expanded(child: SizedBox()),
                                for (final color in contents.reversed)
                                  Expanded(child: _Nut(colorId: color)),
                              ],
                            ),
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

  void _handleTap(
    NutsAndBoltsTapResult result,
    NutsAndBoltsController controller,
  ) {
    switch (result) {
      case NutsAndBoltsTapResult.moved:
        SoundEffects.play(SoundEffect.metalSlide);
        if (controller.model.isComplete) {
          SoundEffects.play(SoundEffect.puzzleComplete);
          HapticEffects.paddleHit();
        } else {
          HapticEffects.preview();
        }
      case NutsAndBoltsTapResult.selected ||
          NutsAndBoltsTapResult.selectionCleared ||
          NutsAndBoltsTapResult.selectionChanged:
        SoundEffects.play(SoundEffect.uiTap);
      case NutsAndBoltsTapResult.invalid:
        SoundEffects.play(SoundEffect.uiInvalid);
      case NutsAndBoltsTapResult.inputLocked || NutsAndBoltsTapResult.completed:
        break;
    }
  }

  Color _borderColor({
    required bool selected,
    required bool legalTarget,
    required bool hinted,
  }) {
    if (selected) return TapTussleColors.electricBlue;
    if (legalTarget) return const Color(0xFF55D98B);
    if (hinted) return TapTussleColors.gold;
    return TapTussleColors.panelBorder;
  }
}

class _Nut extends StatelessWidget {
  const _Nut({required this.colorId});

  final int colorId;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 1),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _nutColors[colorId % _nutColors.length],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: .65)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 3, offset: Offset(0, 2)),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 6,
            child: Text(
              _nutSymbols[colorId % _nutSymbols.length],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          ),
          Positioned(
            right: 6,
            child: Text(
              _nutSymbols[colorId % _nutSymbols.length],
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                shadows: [Shadow(color: Colors.black87, blurRadius: 3)],
              ),
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: TapTussleColors.midnight,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white54),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.compact});

  final NutsAndBoltsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('nuts-bolts-undo'),
          onPressed: controller.acceptsInput && controller.model.canUndo
              ? () {
                  if (controller.undo()) {
                    SoundEffects.play(SoundEffect.uiBack);
                    HapticEffects.preview();
                  }
                }
              : null,
          icon: const Icon(Icons.undo_rounded),
          label: Text(compact ? 'UNDO' : 'UNDO MOVE'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: OutlinedButton.icon(
          key: const ValueKey('nuts-bolts-restart'),
          onPressed: controller.acceptsInput && controller.model.moveCount > 0
              ? () {
                  if (controller.restart()) {
                    SoundEffects.play(SoundEffect.uiConfirm);
                    HapticEffects.preview();
                  }
                }
              : null,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('RESTART'),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton.icon(
          key: const ValueKey('nuts-bolts-hint'),
          onPressed: controller.acceptsInput
              ? () {
                  if (controller.requestHint() != null) {
                    SoundEffects.play(SoundEffect.collect);
                    HapticEffects.preview();
                  } else {
                    SoundEffects.play(SoundEffect.uiInvalid);
                  }
                }
              : null,
          icon: const Icon(Icons.lightbulb_rounded),
          label: const Text('HINT'),
        ),
      ),
    ],
  );
}

const _nutColors = [
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

const _nutNames = [
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

const _nutSymbols = [
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

String _nutName(int color) => _nutNames[color % _nutNames.length];
