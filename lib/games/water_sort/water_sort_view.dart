import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'water_sort_controller.dart';
import 'water_sort_levels.dart';
import 'water_sort_model.dart';
import 'water_sort_progress_repository.dart';

class WaterSortView extends StatefulWidget {
  const WaterSortView({
    this.session,
    this.options,
    this.repository,
    this.level,
    this.initialModel,
    this.controller,
    super.key,
  }) : assert(
         controller != null ||
             level != null ||
             (session != null && options != null),
       );

  final MatchSession? session;
  final MatchOptions? options;
  final WaterSortProgressRepository? repository;
  final WaterSortLevel? level;
  final WaterSortModel? initialModel;
  final WaterSortController? controller;

  @override
  State<WaterSortView> createState() => _WaterSortViewState();
}

class _WaterSortViewState extends State<WaterSortView> {
  WaterSortController? controller;
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied != null) {
      controller = supplied;
      return;
    }
    final level = widget.level;
    if (level != null) {
      controller = WaterSortController(
        level: level,
        initialModel: widget.initialModel,
        session: widget.session,
        repository: widget.repository,
      );
      return;
    }
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final repository =
        widget.repository ??
        WaterSortProgressRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    final difficulty =
        WaterSortDifficulty.values[widget.options!.difficulty.index];
    final saved = repository.loadActive(difficulty);
    final levelNumber = saved?.level ?? repository.unlockedLevel(difficulty);
    setState(() {
      controller = WaterSortController(
        level: WaterSortLevelCatalog.level(difficulty, levelNumber),
        session: widget.session,
        repository: repository,
        restoredProgress: saved,
      );
    });
  }

  @override
  void dispose() {
    if (_ownsController) controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = controller;
    if (loaded == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('water-sort-loading')),
      );
    }
    return WaterSortBoard(controller: loaded);
  }
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
                    child: _TubeArena(
                      controller: controller,
                      preferredColumns: columns,
                      compact: compact,
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

class _TubeArena extends StatelessWidget {
  const _TubeArena({
    required this.controller,
    required this.preferredColumns,
    required this.compact,
  });

  final WaterSortController controller;
  final int preferredColumns;
  final bool compact;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final count = controller.model.tubeCount;
      final columns = preferredColumns.clamp(1, count);
      final rows = (count / columns).ceil();
      final gap = compact ? 6.0 : 10.0;
      final slotWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
      final slotHeight = (constraints.maxHeight - gap * (rows - 1)) / rows;
      final tubeWidth = (slotWidth * .9).clamp(44.0, 112.0);
      final tubeHeight = min(
        slotHeight,
        max(72.0, tubeWidth / (compact ? .48 : .43)),
      );
      final usedWidth = columns * slotWidth + gap * (columns - 1);
      final usedHeight = rows * slotHeight + gap * (rows - 1);
      final leftInset = (constraints.maxWidth - usedWidth) / 2;
      final topInset = (constraints.maxHeight - usedHeight) / 2;
      final rects = <Rect>[];
      for (var index = 0; index < count; index++) {
        final row = index ~/ columns;
        final column = index % columns;
        final slotLeft = leftInset + column * (slotWidth + gap);
        final slotTop = topInset + row * (slotHeight + gap);
        rects.add(
          Rect.fromLTWH(
            slotLeft + (slotWidth - tubeWidth) / 2,
            slotTop + (slotHeight - tubeHeight) / 2,
            tubeWidth,
            tubeHeight,
          ),
        );
      }
      final move = controller.animatingMove;
      return Stack(
        key: const ValueKey('water-sort-board'),
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < count; index++)
            Positioned.fromRect(
              rect: rects[index],
              child: _Tube(
                index: index,
                controller: controller,
                compact: compact,
                pourDirection: move == null || move.source != index
                    ? 0
                    : rects[move.destination].center.dx < rects[index].center.dx
                    ? -1
                    : 1,
              ),
            ),
          if (move != null)
            Positioned.fill(
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(
                    'water-sort-pour-${controller.model.moveCount}-'
                    '${move.source}-${move.destination}',
                  ),
                  duration: controller.animationDuration,
                  curve: Curves.easeInOutCubic,
                  tween: Tween(begin: 0, end: 1),
                  builder: (context, progress, _) => CustomPaint(
                    key: const ValueKey('water-sort-pour-stream'),
                    painter: _PourStreamPainter(
                      start:
                          rects[move.source].topCenter +
                          Offset(0, rects[move.source].height * .12),
                      end:
                          rects[move.destination].topCenter +
                          Offset(0, rects[move.destination].height * .14),
                      color: _liquidColors[move.color % _liquidColors.length],
                      progress: progress,
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _PourStreamPainter extends CustomPainter {
  const _PourStreamPainter({
    required this.start,
    required this.end,
    required this.color,
    required this.progress,
  });

  final Offset start;
  final Offset end;
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0 || progress >= 1) return;
    final horizontal = end.dx - start.dx;
    final lift = 30.0 + horizontal.abs() * .16;
    final control = Offset(
      (start.dx + end.dx) / 2,
      min(start.dy, end.dy) - lift,
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
    final metric = path.computeMetrics().first;
    final head = Curves.easeOut.transform((progress * 1.8).clamp(0, 1));
    final tail = Curves.easeIn.transform(((progress - .42) * 1.75).clamp(0, 1));
    if (head <= tail) return;
    final visible = metric.extractPath(
      metric.length * tail,
      metric.length * head,
    );
    canvas.drawPath(
      visible,
      Paint()
        ..color = color.withValues(alpha: .28)
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      visible,
      Paint()
        ..shader = LinearGradient(
          colors: [color.withValues(alpha: .75), color, Colors.white],
        ).createShader(Rect.fromPoints(start, end))
        ..strokeWidth = 5.5
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );
    final headTangent = metric.getTangentForOffset(metric.length * head);
    if (headTangent != null) {
      canvas.drawCircle(
        headTangent.position,
        6,
        Paint()..color = Colors.white.withValues(alpha: .9),
      );
    }
  }

  @override
  bool shouldRepaint(_PourStreamPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.start != start ||
      oldDelegate.end != end ||
      oldDelegate.color != color;
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${controller.model.moveCount} MOVES',
                key: const ValueKey('water-sort-moves'),
                semanticsLabel: '${controller.model.moveCount} moves',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                controller.elapsedLabel,
                key: const ValueKey('water-sort-elapsed'),
                semanticsLabel: 'Elapsed ${controller.elapsedLabel}',
                style: const TextStyle(
                  color: TapTussleColors.mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (controller.personalBest case final best?)
                Text(
                  'BEST ${best.moves} • ${_formatMilliseconds(best.elapsedMilliseconds)}',
                  key: const ValueKey('water-sort-personal-best'),
                  style: const TextStyle(
                    color: TapTussleColors.mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
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
    required this.pourDirection,
  });

  final int index;
  final WaterSortController controller;
  final bool compact;
  final int pourDirection;

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
              ? () {
                  final result = controller.tapTube(index);
                  switch (result) {
                    case WaterSortTapResult.poured:
                      SoundEffects.play(SoundEffect.liquidPour);
                      if (controller.model.isComplete) {
                        SoundEffects.play(SoundEffect.puzzleComplete);
                        HapticEffects.paddleHit();
                      } else {
                        HapticEffects.preview();
                      }
                    case WaterSortTapResult.selected ||
                        WaterSortTapResult.selectionCleared ||
                        WaterSortTapResult.selectionChanged:
                      SoundEffects.play(SoundEffect.uiTap);
                    case WaterSortTapResult.invalid:
                      SoundEffects.play(SoundEffect.uiInvalid);
                    case WaterSortTapResult.inputLocked ||
                        WaterSortTapResult.completed:
                      break;
                  }
                }
              : null,
          child: AnimatedRotation(
            turns: sourceAnimating ? .065 * pourDirection : 0,
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
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0x553C78A0), Color(0x8810294A)],
                        ),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                          top: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: _borderColor(
                            selected,
                            hintSource,
                            hintDestination,
                          ),
                          width: selected ? 4 : 2.5,
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
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            _liquidColors[colorId % _liquidColors.length],
            Colors.white,
            .24,
          )!,
          _liquidColors[colorId % _liquidColors.length],
          Color.lerp(
            _liquidColors[colorId % _liquidColors.length],
            Colors.black,
            .18,
          )!,
        ],
      ),
      border: Border.all(color: Colors.white.withValues(alpha: .24), width: .5),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Stack(
      fit: StackFit.expand,
      children: [
        Positioned(
          left: 4,
          top: 3,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .55),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Center(
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
      ],
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
          key: const ValueKey('water-sort-restart'),
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
          key: const ValueKey('water-sort-hint'),
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

String _formatMilliseconds(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
