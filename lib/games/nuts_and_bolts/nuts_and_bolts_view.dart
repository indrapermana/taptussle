import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'nuts_and_bolts_controller.dart';
import 'nuts_and_bolts_levels.dart';
import 'nuts_and_bolts_model.dart';
import 'nuts_and_bolts_progress_repository.dart';

class NutsAndBoltsView extends StatefulWidget {
  const NutsAndBoltsView({
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
  final NutsAndBoltsProgressRepository? repository;
  final NutsAndBoltsLevel? level;
  final NutsAndBoltsModel? initialModel;
  final NutsAndBoltsController? controller;

  @override
  State<NutsAndBoltsView> createState() => _NutsAndBoltsViewState();
}

class _NutsAndBoltsViewState extends State<NutsAndBoltsView> {
  NutsAndBoltsController? controller;
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
      controller = NutsAndBoltsController(
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
        NutsAndBoltsProgressRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    final difficulty =
        NutsAndBoltsDifficulty.values[widget.options!.difficulty.index];
    final saved = repository.loadActive(difficulty);
    final levelNumber = saved?.level ?? repository.unlockedLevel(difficulty);
    setState(() {
      controller = NutsAndBoltsController(
        level: NutsAndBoltsLevelCatalog.level(difficulty, levelNumber),
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
        child: CircularProgressIndicator(key: ValueKey('nuts-bolts-loading')),
      );
    }
    return NutsAndBoltsBoard(controller: loaded);
  }
}

class NutsAndBoltsBoard extends StatefulWidget {
  const NutsAndBoltsBoard({required this.controller, super.key});

  final NutsAndBoltsController controller;

  @override
  State<NutsAndBoltsBoard> createState() => _NutsAndBoltsBoardState();
}

class _NutsAndBoltsBoardState extends State<NutsAndBoltsBoard> {
  final _boardKey = GlobalKey();
  final _boltKeys = <int, GlobalKey>{};
  NutsAndBoltsMove? _scheduledMove;
  _NutFlight? _flight;
  Timer? _feedbackTimer;
  String? _feedback;
  int? _invalidBolt;

  NutsAndBoltsController get controller => widget.controller;

  GlobalKey _boltKey(int index) => _boltKeys.putIfAbsent(
    index,
    () => GlobalKey(debugLabel: 'nuts-bolts-layout-$index'),
  );

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    super.dispose();
  }

  void _handleBoltTap(int bolt) {
    final result = controller.tapBolt(bolt);
    switch (result) {
      case NutsAndBoltsTapResult.moved:
        _showFeedback('NICE MOVE!');
      case NutsAndBoltsTapResult.selected:
        SoundEffects.play(SoundEffect.uiTap);
        _showFeedback('PUT IT ON A GLOWING BOLT');
      case NutsAndBoltsTapResult.selectionCleared:
        SoundEffects.play(SoundEffect.uiTap);
        _showFeedback('PICK A TOP NUT');
      case NutsAndBoltsTapResult.selectionChanged:
        SoundEffects.play(SoundEffect.uiTap);
        _showFeedback('NEW NUT PICKED');
      case NutsAndBoltsTapResult.invalid:
        SoundEffects.play(SoundEffect.uiInvalid);
        HapticEffects.paddleHit();
        _showFeedback("THAT NUT DOESN'T FIT", invalidBolt: bolt);
      case NutsAndBoltsTapResult.inputLocked || NutsAndBoltsTapResult.completed:
        break;
    }
  }

  void _showFeedback(String message, {int? invalidBolt}) {
    _feedbackTimer?.cancel();
    setState(() {
      _feedback = message;
      _invalidBolt = invalidBolt;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 850), () {
      if (!mounted) return;
      setState(() {
        _feedback = null;
        _invalidBolt = null;
      });
    });
  }

  void _scheduleFlight(NutsAndBoltsMove move) {
    if (_scheduledMove == move) return;
    _scheduledMove = move;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || controller.animatingMove != move) return;
      final board = _boardKey.currentContext?.findRenderObject() as RenderBox?;
      final source =
          _boltKeys[move.source]?.currentContext?.findRenderObject()
              as RenderBox?;
      final destination =
          _boltKeys[move.destination]?.currentContext?.findRenderObject()
              as RenderBox?;
      if (board == null || source == null || destination == null) return;
      final sourceCount = controller.model.bolts[move.source].length;
      final destinationCount = controller.model.bolts[move.destination].length;
      setState(() {
        _flight = _NutFlight(
          move: move,
          start: _nutSlotRect(board: board, bolt: source, slot: sourceCount),
          end: _nutSlotRect(
            board: board,
            bolt: destination,
            slot: destinationCount - 1,
          ),
        );
      });
    });
  }

  Rect _nutSlotRect({
    required RenderBox board,
    required RenderBox bolt,
    required int slot,
  }) {
    final origin = board.globalToLocal(bolt.localToGlobal(Offset.zero));
    final nutHeight = bolt.size.height * .30;
    final stackStep = bolt.size.height * .13;
    final base = bolt.size.height * .035;
    return Rect.fromCenter(
      center: Offset(
        origin.dx + bolt.size.width / 2,
        origin.dy + bolt.size.height - base - stackStep * slot - nutHeight / 2,
      ),
      width: bolt.size.width - 10,
      height: nutHeight,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final move = controller.animatingMove;
      if (move != null) {
        _scheduleFlight(move);
      } else if (_scheduledMove != null) {
        _scheduledMove = null;
        _flight = null;
      }
      return TapTussleBackdrop(
        child: SafeArea(
          child: Stack(
            key: _boardKey,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxHeight < 650;
                    final columns = constraints.maxWidth < 500
                        ? 3
                        : constraints.maxWidth < 700
                        ? 4
                        : 6;
                    return Padding(
                      padding: EdgeInsets.fromLTRB(8, compact ? 8 : 12, 8, 8),
                      child: Column(
                        children: [
                          _Header(
                            controller: controller,
                            compact: compact,
                            feedback: _feedback,
                          ),
                          SizedBox(height: compact ? 6 : 12),
                          Expanded(
                            child: Container(
                              key: const ValueKey('nuts-bolts-workshop'),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF5C321F),
                                    Color(0xFF301B18),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: const Color(0xFFFFC45C),
                                  width: 2,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black45,
                                    blurRadius: 16,
                                    offset: Offset(0, 7),
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(22),
                                child: Stack(
                                  children: [
                                    const Positioned.fill(
                                      child: CustomPaint(
                                        painter: _WorkshopSurfacePainter(),
                                      ),
                                    ),
                                    Positioned.fill(
                                      child: LayoutBuilder(
                                        builder: (context, boardConstraints) {
                                          final spacing = compact ? 5.0 : 8.0;
                                          final spec = _fittedGridSpec(
                                            size: boardConstraints.biggest,
                                            itemCount:
                                                controller.model.boltCount,
                                            preferredColumns: columns,
                                            padding: const EdgeInsets.fromLTRB(
                                              8,
                                              8,
                                              8,
                                              10,
                                            ),
                                            spacing: spacing,
                                          );
                                          return GridView.builder(
                                            key: const ValueKey(
                                              'nuts-bolts-board',
                                            ),
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            padding: spec.padding,
                                            gridDelegate:
                                                SliverGridDelegateWithFixedCrossAxisCount(
                                                  crossAxisCount: spec.columns,
                                                  childAspectRatio:
                                                      spec.childAspectRatio,
                                                  crossAxisSpacing: spacing,
                                                  mainAxisSpacing: spacing,
                                                ),
                                            itemCount:
                                                controller.model.boltCount,
                                            itemBuilder: (context, bolt) =>
                                                _Bolt(
                                                  index: bolt,
                                                  controller: controller,
                                                  compact: compact,
                                                  layoutKey: _boltKey(bolt),
                                                  invalid: _invalidBolt == bolt,
                                                  onTap: () =>
                                                      _handleBoltTap(bolt),
                                                ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
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
              if (_flight != null)
                _FlyingNut(
                  key: ValueKey(
                    'nuts-bolts-flying-${_flight!.move.source}-${_flight!.move.destination}',
                  ),
                  flight: _flight!,
                  duration: controller.animationDuration,
                ),
              if (controller.model.isComplete && !controller.isAnimating)
                const Positioned.fill(child: _PuzzleCompleteCelebration()),
            ],
          ),
        ),
      );
    },
  );
}

class _FittedGridSpec {
  const _FittedGridSpec({
    required this.columns,
    required this.childAspectRatio,
    required this.padding,
  });

  final int columns;
  final double childAspectRatio;
  final EdgeInsets padding;
}

_FittedGridSpec _fittedGridSpec({
  required Size size,
  required int itemCount,
  required int preferredColumns,
  required EdgeInsets padding,
  required double spacing,
}) {
  var bestColumns = preferredColumns.clamp(2, itemCount);
  var bestRatio = .55;
  var bestScore = -1.0;
  final maxColumns = itemCount.clamp(2, 6);
  for (var columns = 2; columns <= maxColumns; columns++) {
    final rows = (itemCount / columns).ceil();
    final width =
        (size.width - padding.horizontal - spacing * (columns - 1)) / columns;
    final height =
        (size.height - padding.vertical - spacing * (rows - 1)) / rows;
    if (width <= 0 || height <= 0) continue;
    const targetAspect = .56;
    final usableWidth = width < height * targetAspect
        ? width
        : height * targetAspect;
    final preferredBonus = columns == preferredColumns ? 1.01 : 1.0;
    final score = usableWidth * preferredBonus;
    if (score > bestScore) {
      bestScore = score;
      bestColumns = columns;
      bestRatio = width / height;
    }
  }
  return _FittedGridSpec(
    columns: bestColumns,
    childAspectRatio: bestRatio,
    padding: padding,
  );
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.compact,
    this.feedback,
  });

  final NutsAndBoltsController controller;
  final bool compact;
  final String? feedback;

  @override
  Widget build(BuildContext context) {
    final hint = controller.hintMove;
    final status = controller.model.isComplete
        ? 'ALL COLORS SORTED!'
        : controller.isAnimating
        ? 'NUT ON THE MOVE!'
        : feedback != null
        ? feedback!
        : hint != null
        ? 'TRY ${hint.source + 1} → ${hint.destination + 1}'
        : controller.selectedBolt != null
        ? 'PUT IT ON A GLOWING BOLT'
        : 'PICK A TOP NUT';
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'LEVEL ${controller.level.number} • ${controller.level.difficulty.label.toUpperCase()}',
          style: const TextStyle(
            fontFamily: 'Lilita One',
            color: TapTussleColors.electricBlue,
            fontSize: 15,
          ),
        ),
        Semantics(
          liveRegion: true,
          child: Text(
            status,
            key: const ValueKey('nuts-bolts-status'),
            maxLines: enlargedText ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Lilita One',
              fontSize: compact ? 17 : 21,
              color: controller.model.isComplete
                  ? TapTussleColors.gold
                  : TapTussleColors.text,
            ),
          ),
        ),
      ],
    );
    final metrics = Wrap(
      spacing: 10,
      runSpacing: 2,
      alignment: enlargedText ? WrapAlignment.start : WrapAlignment.end,
      children: [
        Text(
          '${controller.model.moveCount} MOVES',
          key: const ValueKey('nuts-bolts-moves'),
          semanticsLabel: '${controller.model.moveCount} moves',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        Text(
          controller.elapsedLabel,
          key: const ValueKey('nuts-bolts-elapsed'),
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
            key: const ValueKey('nuts-bolts-personal-best'),
            semanticsLabel:
                'Personal best ${best.moves} moves, ${_formatMilliseconds(best.elapsedMilliseconds)}',
            style: const TextStyle(
              color: TapTussleColors.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
    return ArcadePanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 8 : 12,
      ),
      accent: controller.model.isComplete
          ? TapTussleColors.gold
          : TapTussleColors.electricBlue,
      child: enlargedText
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 4), metrics],
            )
          : Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                Flexible(child: metrics),
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
    required this.layoutKey,
    required this.invalid,
    required this.onTap,
  });

  final int index;
  final NutsAndBoltsController controller;
  final bool compact;
  final GlobalKey layoutKey;
  final bool invalid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final contents = controller.model.bolts[index];
    final selected = controller.selectedBolt == index;
    final legalTarget = controller.isLegalDestination(index);
    final animation = controller.animatingMove;
    final sourceAnimating = animation?.source == index;
    final destinationAnimating = animation?.destination == index;
    final sorted =
        contents.length == controller.model.capacity &&
        contents.every((color) => color == contents.first);
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
      if (sorted) 'sorted',
      if (invalid) 'does not fit',
    ];
    final stateLabel = states.isEmpty ? '' : ', ${states.join(', ')}';

    return Semantics(
      label: 'Bolt ${index + 1}, $accessibleContents$stateLabel',
      button: true,
      selected: selected,
      enabled: controller.acceptsInput,
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: ExcludeSemantics(
          child: InkWell(
            key: ValueKey('nuts-bolts-bolt-$index'),
            borderRadius: BorderRadius.circular(22),
            onTap: controller.acceptsInput ? onTap : null,
            child: AnimatedScale(
              scale: invalid
                  ? .94
                  : destinationAnimating
                  ? 1.08
                  : selected || hintSource || hintDestination
                  ? 1.04
                  : 1,
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
                        color: invalid
                            ? const Color(0xFFFF6B6B)
                            : hintSource || hintDestination
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
                        key: layoutKey,
                        duration: const Duration(milliseconds: 160),
                        decoration: BoxDecoration(
                          color: const Color(0x5510294A),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: invalid
                                ? const Color(0xFFFF6B6B)
                                : sorted
                                ? const Color(0xFF55D98B)
                                : _borderColor(
                                    selected: selected,
                                    legalTarget: legalTarget,
                                    hinted: hintSource || hintDestination,
                                  ),
                            width: selected || legalTarget || sorted ? 3 : 1.5,
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
                            Positioned.fill(
                              child: Stack(
                                key: ValueKey('nuts-bolts-sprite-$index'),
                                children: [
                                  Align(
                                    alignment: Alignment.topCenter,
                                    child: FractionallySizedBox(
                                      widthFactor: .28,
                                      heightFactor: .91,
                                      child: Image.asset(
                                        'assets/games/nuts_and_bolts/bolt_shaft.png',
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      widthFactor: .90,
                                      heightFactor: .18,
                                      child: Image.asset(
                                        'assets/games/nuts_and_bolts/bolt_base.png',
                                        fit: BoxFit.fill,
                                        filterQuality: FilterQuality.medium,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned.fill(
                              child: _NutStack(
                                contents: contents,
                                hideTop: destinationAnimating,
                              ),
                            ),
                            if (hintSource || hintDestination)
                              Positioned(
                                top: 7,
                                child: _BoltCue(
                                  icon: hintSource
                                      ? Icons.arrow_upward_rounded
                                      : Icons.arrow_downward_rounded,
                                  label: hintSource ? 'PICK' : 'PUT',
                                ),
                              ),
                            if (sorted)
                              const Positioned(
                                top: 7,
                                right: 7,
                                child: _SortedBadge(),
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
      ),
    );
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

class _BoltCue extends StatelessWidget {
  const _BoltCue({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: TapTussleColors.gold,
      borderRadius: BorderRadius.circular(12),
      boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 5)],
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: TapTussleColors.midnight),
        Text(
          label,
          style: const TextStyle(
            color: TapTussleColors.midnight,
            fontSize: 10,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

class _SortedBadge extends StatelessWidget {
  const _SortedBadge();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('nuts-bolts-sorted-badge'),
    width: 25,
    height: 25,
    decoration: const BoxDecoration(
      color: Color(0xFF55D98B),
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 5)],
    ),
    child: const Icon(Icons.check_rounded, size: 18, color: Color(0xFF082D22)),
  );
}

class _Nut extends StatelessWidget {
  const _Nut({required this.colorId, this.hidden = false});

  final int colorId;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: hidden ? 0 : 1,
      child: Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          Image.asset(
            _nutAssets[colorId % _nutAssets.length],
            key: ValueKey('nuts-bolts-nut-sprite-$colorId'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          Align(
            alignment: const Alignment(0, .28),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _nutSymbols[colorId % _nutSymbols.length],
                style: const TextStyle(
                  color: Color(0xAA30152E),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  shadows: [
                    Shadow(color: Colors.white38, offset: Offset(0, 1)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutStack extends StatelessWidget {
  const _NutStack({required this.contents, required this.hideTop});

  final List<int> contents;
  final bool hideTop;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final nutHeight = constraints.maxHeight * .30;
      final stackStep = constraints.maxHeight * .13;
      final base = constraints.maxHeight * .035;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          for (var index = 0; index < contents.length; index++)
            Positioned(
              left: 5,
              right: 5,
              bottom: base + stackStep * index,
              height: nutHeight,
              child: _Nut(
                colorId: contents[index],
                hidden: hideTop && index == contents.length - 1,
              ),
            ),
        ],
      );
    },
  );
}

class _NutFlight {
  const _NutFlight({
    required this.move,
    required this.start,
    required this.end,
  });

  final NutsAndBoltsMove move;
  final Rect start;
  final Rect end;
}

class _FlyingNut extends StatelessWidget {
  const _FlyingNut({required this.flight, required this.duration, super.key});

  final _NutFlight flight;
  final Duration duration;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: duration,
    curve: Curves.easeInOutCubic,
    builder: (context, progress, child) {
      final base = Rect.lerp(flight.start, flight.end, progress)!;
      final lift = 34 * 4 * progress * (1 - progress);
      return Positioned.fromRect(
        rect: base.shift(Offset(0, -lift)),
        child: Transform.rotate(
          angle: progress * .35,
          child: Transform.scale(
            scale: 1 + .12 * 4 * progress * (1 - progress),
            child: child,
          ),
        ),
      );
    },
    child: _Nut(colorId: flight.move.color),
  );
}

class _PuzzleCompleteCelebration extends StatelessWidget {
  const _PuzzleCompleteCelebration();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: ColoredBox(
      color: TapTussleColors.midnight.withValues(alpha: .72),
      child: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: .65, end: 1),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutBack,
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Semantics(
            liveRegion: true,
            label: 'Great job! All colors sorted!',
            child: Container(
              key: const ValueKey('nuts-bolts-complete-celebration'),
              margin: const EdgeInsets.all(28),
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD338), Color(0xFFFF9F1C)],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0x99FFD338), blurRadius: 28),
                ],
              ),
              child: const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    size: 52,
                    color: TapTussleColors.midnight,
                  ),
                  SizedBox(height: 6),
                  Text(
                    'GREAT JOB!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Lilita One',
                      fontSize: 32,
                      color: TapTussleColors.midnight,
                    ),
                  ),
                  Text(
                    'ALL COLORS SORTED!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TapTussleColors.midnight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _WorkshopSurfacePainter extends CustomPainter {
  const _WorkshopSurfacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final grain = Paint()
      ..color = const Color(0x1AFFF0D0)
      ..strokeWidth = 1.2;
    for (var y = 24.0; y < size.height; y += 42) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y + 8), grain);
    }
    final screw = Paint()..color = const Color(0x6689A8C2);
    for (final point in [
      const Offset(13, 13),
      Offset(size.width - 13, 13),
      Offset(13, size.height - 13),
      Offset(size.width - 13, size.height - 13),
    ]) {
      canvas.drawCircle(point, 4, screw);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.compact});

  final NutsAndBoltsController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enlargedText = MediaQuery.textScalerOf(context).scale(1) >= 1.4;
    final undo = OutlinedButton.icon(
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
      label: Text(compact || enlargedText ? 'UNDO' : 'UNDO MOVE'),
    );
    final restart = OutlinedButton.icon(
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
    );
    final hint = FilledButton.icon(
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
    );
    if (enlargedText) {
      return Column(
        key: const ValueKey('nuts-bolts-controls-stacked'),
        children: [
          SizedBox(
            height: 52,
            child: Row(
              children: [
                Expanded(child: undo),
                const SizedBox(width: 8),
                Expanded(child: restart),
              ],
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(width: double.infinity, height: 52, child: hint),
        ],
      );
    }
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(child: undo),
          const SizedBox(width: 8),
          Expanded(child: restart),
          const SizedBox(width: 8),
          Expanded(child: hint),
        ],
      ),
    );
  }
}

const _nutAssets = [
  'assets/games/nuts_and_bolts/nut_red.png',
  'assets/games/nuts_and_bolts/nut_blue.png',
  'assets/games/nuts_and_bolts/nut_yellow.png',
  'assets/games/nuts_and_bolts/nut_green.png',
  'assets/games/nuts_and_bolts/nut_purple.png',
  'assets/games/nuts_and_bolts/nut_orange.png',
  'assets/games/nuts_and_bolts/nut_pink.png',
  'assets/games/nuts_and_bolts/nut_cyan.png',
  'assets/games/nuts_and_bolts/nut_indigo.png',
  'assets/games/nuts_and_bolts/nut_lime.png',
  'assets/games/nuts_and_bolts/nut_rose.png',
  'assets/games/nuts_and_bolts/nut_brown.png',
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

String _formatMilliseconds(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final minutes = duration.inMinutes;
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}
