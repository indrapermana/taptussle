import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'solitaire_controller.dart';
import 'solitaire_model.dart';
import 'solitaire_progress_repository.dart';

class SolitaireView extends StatefulWidget {
  const SolitaireView({
    this.session,
    this.options,
    this.controller,
    this.repository,
    super.key,
  }) : assert(controller != null || (session != null && options != null));

  final MatchSession? session;
  final MatchOptions? options;
  final SolitaireController? controller;
  final SolitaireProgressRepository? repository;

  @override
  State<SolitaireView> createState() => _SolitaireViewState();
}

class _SolitaireViewState extends State<SolitaireView> {
  SolitaireController? controller;
  late final bool _ownsController = widget.controller == null;

  @override
  void initState() {
    super.initState();
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    controller = widget.controller;
    if (controller == null) _loadProgress();
  }

  Future<void> _loadProgress() async {
    final repository =
        widget.repository ??
        SolitaireProgressRepository(await SharedPreferences.getInstance());
    if (!mounted) return;
    final difficulty =
        SolitaireDifficulty.values[widget.options!.difficulty.index];
    // A Solitaire deal belongs to one visit to the match screen. Clear any
    // legacy snapshot so returning from the catalog always starts fresh.
    await repository.clearActive(difficulty);
    if (!mounted) return;
    setState(() {
      controller = SolitaireController(
        session: widget.session,
        difficulty: difficulty,
        repository: repository,
      );
    });
  }

  @override
  void dispose() {
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
    if (_ownsController) controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loaded = controller;
    if (loaded == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('solitaire-loading')),
      );
    }
    return SolitaireBoard(controller: loaded);
  }
}

class SolitaireBoard extends StatelessWidget {
  const SolitaireBoard({required this.controller, super.key});

  final SolitaireController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => TapTussleBackdrop(
      child: SafeArea(
        child: controller.isPaused
            ? const Center(
                child: Text(
                  'SOLITAIRE PAUSED',
                  key: ValueKey('solitaire-paused'),
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    fontSize: 26,
                    color: TapTussleColors.mutedText,
                  ),
                ),
              )
            : Stack(
                children: [
                  Positioned.fill(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final compact = constraints.maxHeight < 650;
                        final portraitPhone = constraints.maxWidth < 430;
                        final horizontalPadding = portraitPhone
                            ? 4.0
                            : compact
                            ? 6.0
                            : 12.0;
                        final gap = portraitPhone ? 2.0 : 7.0;
                        final usableWidth = math.min(
                          constraints.maxWidth - horizontalPadding * 2,
                          980,
                        );
                        final cardWidth = ((usableWidth - gap * 6) / 7).clamp(
                          39.0,
                          124.0,
                        );
                        final cardHeight = cardWidth * 1.38;
                        return Padding(
                          padding: EdgeInsets.fromLTRB(
                            horizontalPadding,
                            compact ? 6 : 12,
                            horizontalPadding,
                            8,
                          ),
                          child: Column(
                            children: [
                              _Header(controller: controller, compact: compact),
                              SizedBox(height: compact ? 5 : 10),
                              Expanded(
                                child: Center(
                                  child: SizedBox(
                                    width: cardWidth * 7 + gap * 6,
                                    child: Column(
                                      children: [
                                        _TopRow(
                                          controller: controller,
                                          cardWidth: cardWidth,
                                          cardHeight: cardHeight,
                                          gap: gap,
                                        ),
                                        SizedBox(height: compact ? 8 : 14),
                                        Expanded(
                                          child: _Tableau(
                                            controller: controller,
                                            cardWidth: cardWidth,
                                            cardHeight: cardHeight,
                                            gap: gap,
                                            compact: compact,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (controller.model.isComplete)
                    const Positioned.fill(child: _CompletionCelebration()),
                ],
              ),
      ),
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.compact});

  final SolitaireController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = controller.model.isComplete
        ? 'SOLITAIRE COMPLETE!'
        : controller.isAnimating
        ? 'MOVING CARD…'
        : controller.showInvalidGuidance
        ? 'TRY A GLOWING SPOT'
        : controller.shownHint != null
        ? _hintLabel(controller.shownHint!)
        : controller.selection != null
        ? 'PICK A GLOWING SPOT'
        : 'PUT ACES UP TOP';
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 610;
        final information = Expanded(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: TapTussleColors.electricBlue.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  controller.model.drawMode == SolitaireDrawMode.drawThree
                      ? 'DRAW 3'
                      : 'DRAW 1',
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    color: TapTussleColors.electricBlue,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: animation, child: child),
                  ),
                  child: Text(
                    status,
                    key: ValueKey('solitaire-status-$status'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Lilita One',
                      fontSize: compact ? 16 : 20,
                      color: controller.showInvalidGuidance
                          ? const Color(0xFFFFA36C)
                          : controller.model.isComplete
                          ? TapTussleColors.gold
                          : TapTussleColors.text,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${controller.model.score} PTS',
                        key: const ValueKey('solitaire-score'),
                        semanticsLabel: '${controller.model.score} points',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const Text(
                        '  •  ',
                        style: TextStyle(color: TapTussleColors.mutedText),
                      ),
                      Text(
                        '${controller.model.moveCount} MOVES • ${controller.elapsedLabel}',
                        key: const ValueKey('solitaire-stats'),
                        semanticsLabel:
                            '${controller.model.moveCount} moves, elapsed ${controller.elapsedLabel}',
                        style: const TextStyle(
                          color: TapTussleColors.mutedText,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
        final controls = FittedBox(
          fit: BoxFit.scaleDown,
          child: _Controls(controller: controller, compact: true),
        );
        return ArcadePanel(
          key: const ValueKey('solitaire-compact-hud'),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 3 : 8,
          ),
          accent: controller.model.isComplete
              ? TapTussleColors.gold
              : TapTussleColors.electricBlue,
          child: narrow
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(children: [information]),
                    const SizedBox(height: 4),
                    controls,
                  ],
                )
              : Row(
                  children: [information, const SizedBox(width: 10), controls],
                ),
        );
      },
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow({
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
  });

  final SolitaireController controller;
  final double cardWidth;
  final double cardHeight;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      _Stock(controller: controller, width: cardWidth, height: cardHeight),
      SizedBox(width: gap),
      _Waste(controller: controller, width: cardWidth, height: cardHeight),
      SizedBox(width: gap),
      SizedBox(width: cardWidth),
      SizedBox(width: gap),
      for (var index = 0; index < SolitaireSuit.values.length; index++) ...[
        _Foundation(
          suit: SolitaireSuit.values[index],
          controller: controller,
          width: cardWidth,
          height: cardHeight,
        ),
        if (index != SolitaireSuit.values.length - 1) SizedBox(width: gap),
      ],
    ],
  );
}

class _Stock extends StatelessWidget {
  const _Stock({
    required this.controller,
    required this.width,
    required this.height,
  });

  final SolitaireController controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final empty = controller.model.stock.isEmpty;
    final hinted =
        controller.shownHint?.type == SolitaireHintType.drawOrRecycle;
    final label = empty
        ? controller.model.waste.isEmpty
              ? 'Stock empty'
              : 'Stock empty, tap to recycle waste'
        : 'Stock, ${controller.model.stock.length} cards, tap to draw '
              '${controller.model.drawMode.count}';
    return Semantics(
      label: label,
      button: true,
      enabled:
          controller.acceptsInput &&
          (!empty || controller.model.waste.isNotEmpty),
      child: GestureDetector(
        key: const ValueKey('solitaire-stock'),
        onTap: controller.acceptsInput
            ? () => controller.drawOrRecycle()
            : null,
        child: AnimatedScale(
          scale: hinted ? 1.06 : 1,
          duration: const Duration(milliseconds: 180),
          child: empty
              ? _EmptySlot(
                  width: width,
                  height: height,
                  symbol: '↻',
                  highlighted: hinted,
                )
              : _CardBack(width: width, height: height, highlighted: hinted),
        ),
      ),
    );
  }
}

class _Waste extends StatelessWidget {
  const _Waste({
    required this.controller,
    required this.width,
    required this.height,
  });

  final SolitaireController controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final card = controller.model.wasteTop;
    if (card == null) {
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 240),
        transitionBuilder: (child, animation) => _cardArrivalTransition(
          child,
          animation,
          begin: const Offset(-.32, 0),
        ),
        child: _EmptySlot(
          key: const ValueKey('solitaire-waste-empty'),
          width: width,
          height: height,
          symbol: 'W',
        ),
      );
    }
    final selected = controller.selection?.type == SolitaireSelectionType.waste;
    final hint = controller.shownHint;
    final hinted =
        hint?.type == SolitaireHintType.wasteToFoundation ||
        hint?.type == SolitaireHintType.wasteToTableau;
    final child = _PlayingCard(
      card: card,
      width: width,
      height: height,
      selected: selected,
      highlighted: hinted,
      onTap: controller.tapWaste,
      key: ValueKey('solitaire-waste-${card.suit.name}-${card.rank.name}'),
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      transitionBuilder: (child, animation) => _cardArrivalTransition(
        child,
        animation,
        begin: const Offset(-.32, 0),
      ),
      child: KeyedSubtree(
        key: ValueKey(
          'solitaire-waste-card-${card.suit.name}-${card.rank.name}',
        ),
        child: _DraggableCard(
          data: const _CardDrag.waste(),
          card: card,
          width: width,
          height: height,
          enabled: controller.acceptsInput,
          child: child,
        ),
      ),
    );
  }
}

class _Foundation extends StatelessWidget {
  const _Foundation({
    required this.suit,
    required this.controller,
    required this.width,
    required this.height,
  });

  final SolitaireSuit suit;
  final SolitaireController controller;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final pile = controller.model.foundations[suit]!;
    final card = pile.lastOrNull;
    final selected =
        controller.selection?.type == SolitaireSelectionType.foundation &&
        controller.selection?.suit == suit;
    final hint = controller.shownHint;
    final hintDestination =
        hint?.type == SolitaireHintType.wasteToFoundation ||
        (hint?.type == SolitaireHintType.tableauToFoundation);
    final hintSource =
        hint?.type == SolitaireHintType.foundationToTableau &&
        hint?.suit == suit;
    final legalDestination = controller.isLegalFoundationDestination(suit);
    Widget child = card == null
        ? _EmptySlot(
            width: width,
            height: height,
            symbol: _suitSymbol(suit),
            highlighted: hintDestination,
            legalDestination: legalDestination,
          )
        : _PlayingCard(
            card: card,
            width: width,
            height: height,
            selected: selected,
            highlighted: hintDestination || hintSource,
            legalDestination: legalDestination,
            onTap: () => controller.tapFoundation(suit),
            key: ValueKey('solitaire-foundation-${suit.name}'),
          );
    if (card != null) {
      child = _DraggableCard(
        data: _CardDrag.foundation(suit),
        card: card,
        width: width,
        height: height,
        enabled: controller.acceptsInput,
        child: child,
      );
    }
    return DragTarget<_CardDrag>(
      onWillAcceptWithDetails: (details) =>
          controller.acceptsInput &&
          details.data.type != SolitaireSelectionType.foundation,
      onAcceptWithDetails: (details) {
        final data = details.data;
        if (data.type == SolitaireSelectionType.waste) {
          controller.dragWasteToFoundation();
        } else if (data.type == SolitaireSelectionType.tableau) {
          controller.dragTableauToFoundation(data.pile!);
        }
      },
      builder: (context, candidates, _) => Semantics(
        label:
            '${_suitName(suit)} foundation, ${pile.length} cards'
            '${legalDestination ? ', legal destination' : ''}',
        button: true,
        child: GestureDetector(
          onTap: controller.acceptsInput
              ? () => controller.tapFoundation(suit)
              : null,
          child: AnimatedScale(
            scale: candidates.isEmpty ? 1 : 1.07,
            duration: const Duration(milliseconds: 120),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              transitionBuilder: (child, animation) => _cardArrivalTransition(
                child,
                animation,
                begin: const Offset(0, .2),
                celebrate: true,
              ),
              child: KeyedSubtree(
                key: ValueKey(
                  card == null
                      ? 'solitaire-foundation-${suit.name}-empty'
                      : 'solitaire-foundation-${suit.name}-${card.rank.name}',
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tableau extends StatelessWidget {
  const _Tableau({
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
    required this.gap,
    required this.compact,
  });

  final SolitaireController controller;
  final double cardWidth;
  final double cardHeight;
  final double gap;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    key: const ValueKey('solitaire-tableau'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (var pile = 0; pile < SolitaireModel.tableauPileCount; pile++) ...[
        Expanded(
          child: _TableauPile(
            pile: pile,
            controller: controller,
            cardWidth: cardWidth,
            cardHeight: cardHeight,
            compact: compact,
          ),
        ),
        if (pile != SolitaireModel.tableauPileCount - 1) SizedBox(width: gap),
      ],
    ],
  );
}

class _TableauPile extends StatelessWidget {
  const _TableauPile({
    required this.pile,
    required this.controller,
    required this.cardWidth,
    required this.cardHeight,
    required this.compact,
  });

  final int pile;
  final SolitaireController controller;
  final double cardWidth;
  final double cardHeight;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final cards = controller.model.tableau[pile];
    final hint = controller.shownHint;
    final hintSource =
        hint?.type == SolitaireHintType.tableauToTableau &&
        hint?.source == pile;
    final hintDestination =
        (hint?.type == SolitaireHintType.tableauToTableau ||
            hint?.type == SolitaireHintType.wasteToTableau ||
            hint?.type == SolitaireHintType.foundationToTableau) &&
        hint?.destination == pile;
    final legalDestination = controller.isLegalTableauDestination(pile);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxHeight;
        final offset = cards.length <= 1
            ? 0.0
            : math.min(
                compact ? 21.0 : 29.0,
                math.max(13.0, (available - cardHeight) / (cards.length - 1)),
              );
        return DragTarget<_CardDrag>(
          onWillAcceptWithDetails: (_) => controller.acceptsInput,
          onAcceptWithDetails: (details) {
            final data = details.data;
            switch (data.type) {
              case SolitaireSelectionType.waste:
                controller.dragWasteToTableau(pile);
              case SolitaireSelectionType.tableau:
                controller.dragTableauToTableau(
                  source: data.pile!,
                  cardIndex: data.cardIndex!,
                  destination: pile,
                );
              case SolitaireSelectionType.foundation:
                controller.dragFoundationToTableau(data.suit!, pile);
            }
          },
          builder: (context, candidates, _) => Semantics(
            label: cards.isEmpty
                ? 'Tableau ${pile + 1}, empty'
                      '${legalDestination ? ', legal destination' : ''}'
                : 'Tableau ${pile + 1}, ${cards.length} cards, '
                      '${cards.where((entry) => !entry.isFaceUp).length} face down'
                      '${legalDestination ? ', legal destination' : ''}',
            container: true,
            explicitChildNodes: true,
            child: AnimatedContainer(
              key: ValueKey('solitaire-tableau-$pile'),
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: candidates.isNotEmpty || hintDestination
                      ? TapTussleColors.gold
                      : legalDestination
                      ? TapTussleColors.electricBlue
                      : Colors.transparent,
                  width:
                      candidates.isNotEmpty ||
                          hintDestination ||
                          legalDestination
                      ? 2.5
                      : 1,
                ),
              ),
              child: cards.isEmpty
                  ? GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: controller.acceptsInput
                          ? () => controller.tapTableau(pile)
                          : null,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: _EmptySlot(
                          width: cardWidth,
                          height: cardHeight,
                          symbol: 'K',
                          highlighted: hintDestination,
                          legalDestination: legalDestination,
                        ),
                      ),
                    )
                  : GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: controller.acceptsInput
                          ? () => controller.tapTableau(pile)
                          : null,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var index = 0; index < cards.length; index++)
                            Positioned(
                              top: offset * index,
                              left: 0,
                              right: 0,
                              child: _CardEntrance(
                                key: ValueKey(
                                  'solitaire-arrival-$pile-${cards[index].card.suit.name}-${cards[index].card.rank.name}',
                                ),
                                delay: controller.model.moveCount == 0
                                    ? Duration(
                                        milliseconds: pile * 42 + index * 24,
                                      )
                                    : Duration.zero,
                                child: _TableauCard(
                                  pile: pile,
                                  index: index,
                                  entry: cards[index],
                                  controller: controller,
                                  width: cardWidth,
                                  height: cardHeight,
                                  highlighted:
                                      hintSource &&
                                      (hint?.cardIndex == null ||
                                          index >= hint!.cardIndex!),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }
}

class _TableauCard extends StatelessWidget {
  const _TableauCard({
    required this.pile,
    required this.index,
    required this.entry,
    required this.controller,
    required this.width,
    required this.height,
    required this.highlighted,
  });

  final int pile;
  final int index;
  final SolitaireTableauCard entry;
  final SolitaireController controller;
  final double width;
  final double height;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    late final Widget face;
    if (!entry.isFaceUp) {
      face = Semantics(
        key: const ValueKey('solitaire-card-face-down'),
        label: 'Tableau ${pile + 1}, face-down card ${index + 1}',
        child: _CardBack(width: width, height: height),
      );
    } else {
      final selection = controller.selection;
      final selected =
          selection?.type == SolitaireSelectionType.tableau &&
          selection?.pile == pile &&
          index >= selection!.cardIndex!;
      final card = _PlayingCard(
        key: ValueKey('solitaire-tableau-$pile-card-$index'),
        card: entry.card,
        width: width,
        height: height,
        selected: selected,
        highlighted: highlighted,
        onTap: () => controller.tapTableau(pile, cardIndex: index),
      );
      face = KeyedSubtree(
        key: const ValueKey('solitaire-card-face-up'),
        child: _DraggableCard(
          data: _CardDrag.tableau(pile, index),
          card: entry.card,
          width: width,
          height: height,
          enabled: controller.acceptsInput,
          child: card,
        ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      transitionBuilder: _flipCardTransition,
      layoutBuilder: (currentChild, previousChildren) => Stack(
        alignment: Alignment.topCenter,
        children: [...previousChildren, if (currentChild != null) currentChild],
      ),
      child: face,
    );
  }
}

class _CardEntrance extends StatefulWidget {
  const _CardEntrance({required this.delay, required this.child, super.key});

  final Duration delay;
  final Widget child;

  @override
  State<_CardEntrance> createState() => _CardEntranceState();
}

class _CardEntranceState extends State<_CardEntrance> {
  Timer? _timer;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(widget.delay, () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedSlide(
    offset: _visible ? Offset.zero : const Offset(0, -.18),
    curve: Curves.easeOutBack,
    duration: const Duration(milliseconds: 240),
    child: AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: widget.child,
    ),
  );
}

class _DraggableCard extends StatelessWidget {
  const _DraggableCard({
    required this.data,
    required this.card,
    required this.width,
    required this.height,
    required this.enabled,
    required this.child,
  });

  final _CardDrag data;
  final SolitaireCard card;
  final double width;
  final double height;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return LongPressDraggable<_CardDrag>(
      data: data,
      feedback: Material(
        color: Colors.transparent,
        child: _PlayingCard(card: card, width: width, height: height),
      ),
      childWhenDragging: Opacity(opacity: .25, child: child),
      child: child,
    );
  }
}

class _PlayingCard extends StatelessWidget {
  const _PlayingCard({
    required this.card,
    required this.width,
    required this.height,
    this.selected = false,
    this.highlighted = false,
    this.legalDestination = false,
    this.onTap,
    super.key,
  });

  final SolitaireCard card;
  final double width;
  final double height;
  final bool selected;
  final bool highlighted;
  final bool legalDestination;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final red = card.color == SolitaireCardColor.red;
    final color = red ? const Color(0xFFC62828) : const Color(0xFF14213D);
    final label = '${_rankName(card.rank)} of ${_suitName(card.suit)}';
    final courtAsset = _courtAsset(card.rank);
    return Semantics(
      label: '$label${selected ? ', selected' : ''}',
      button: onTap != null,
      selected: selected,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? 1.06 : 1,
            duration: const Duration(milliseconds: 140),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: width,
              height: height,
              padding: EdgeInsets.all(math.max(3, width * .07)),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFCF2),
                borderRadius: BorderRadius.circular(math.max(5, width * .11)),
                border: Border.all(
                  color: selected || highlighted
                      ? TapTussleColors.gold
                      : legalDestination
                      ? TapTussleColors.electricBlue
                      : const Color(0xFFCBD5E1),
                  width: selected || highlighted || legalDestination ? 2.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  if (courtAsset != null)
                    Positioned.fill(
                      top: height * .18,
                      left: width * .12,
                      right: width * .05,
                      bottom: height * .05,
                      child: Image.asset(
                        courtAsset,
                        key: ValueKey('solitaire-court-${card.rank.name}'),
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    )
                  else
                    Positioned.fill(
                      top: height * .23,
                      child: Center(
                        child: Text(
                          _suitSymbol(card.suit),
                          key: ValueKey(
                            'solitaire-center-suit-${card.suit.name}',
                          ),
                          style: TextStyle(
                            color: color.withValues(alpha: .2),
                            fontSize: width * .63,
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  Align(
                    alignment: Alignment.topLeft,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _rankSymbol(card.rank),
                            style: TextStyle(
                              fontFamily: 'Lilita One',
                              color: color,
                              fontSize: 25,
                              height: .9,
                            ),
                          ),
                          Text(
                            _suitSymbol(card.suit),
                            style: TextStyle(
                              color: color,
                              fontSize: 22,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (courtAsset != null)
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _suitSymbol(card.suit),
                        style: TextStyle(
                          color: color,
                          fontSize: width * .3,
                          height: 1,
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
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.width,
    required this.height,
    this.highlighted = false,
  });

  final double width;
  final double height;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(math.max(5, width * .11)),
      border: Border.all(
        color: highlighted ? TapTussleColors.gold : const Color(0xFFFFD15A),
        width: highlighted ? 3 : 1.5,
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(math.max(4, width * .09)),
      child: Image.asset(
        'assets/games/solitaire/card_back.png',
        key: const ValueKey('solitaire-card-back-art'),
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    ),
  );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.width,
    required this.height,
    required this.symbol,
    this.highlighted = false,
    this.legalDestination = false,
    super.key,
  });

  final double width;
  final double height;
  final String symbol;
  final bool highlighted;
  final bool legalDestination;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(math.max(5, width * .11)),
      border: Border.all(
        color: highlighted
            ? TapTussleColors.gold
            : legalDestination
            ? TapTussleColors.electricBlue
            : TapTussleColors.panelBorder,
        width: highlighted || legalDestination ? 2.5 : 1.2,
      ),
    ),
    child: Center(
      child: Text(
        symbol,
        style: TextStyle(
          fontFamily: 'Lilita One',
          color: highlighted
              ? TapTussleColors.gold
              : legalDestination
              ? TapTussleColors.electricBlue
              : TapTussleColors.mutedText.withValues(alpha: .55),
          fontSize: width * .42,
        ),
      ),
    ),
  );
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller, required this.compact});

  final SolitaireController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      OutlinedButton.icon(
        key: const ValueKey('solitaire-undo'),
        style: compact
            ? OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.standard,
              )
            : null,
        onPressed: controller.acceptsInput && controller.model.canUndo
            ? controller.undo
            : null,
        icon: const Icon(Icons.undo_rounded),
        label: Text(compact ? 'BACK' : 'UNDO MOVE'),
      ),
      const SizedBox(width: 10),
      FilledButton.icon(
        key: const ValueKey('solitaire-hint'),
        style: compact
            ? FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                visualDensity: VisualDensity.standard,
              )
            : null,
        onPressed: controller.acceptsInput ? controller.requestHint : null,
        icon: const Icon(Icons.lightbulb_rounded),
        label: const Text('HINT'),
      ),
    ],
  );
}

class _CompletionCelebration extends StatelessWidget {
  const _CompletionCelebration();

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Solitaire complete celebration',
    child: IgnorePointer(
      child: TweenAnimationBuilder<double>(
        key: const ValueKey('solitaire-completion-celebration'),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeOutCubic,
        builder: (context, progress, _) => Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _CelebrationPainter(progress)),
            ),
            Center(
              child: Transform.scale(
                scale: .65 + progress * .35,
                child: Opacity(
                  opacity: progress.clamp(0, 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xE6112A42),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: TapTussleColors.gold, width: 3),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x99FFD15A),
                          blurRadius: 28,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            color: TapTussleColors.gold,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'YOU DID IT!',
                            style: TextStyle(
                              fontFamily: 'Lilita One',
                              color: Colors.white,
                              fontSize: 28,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CelebrationPainter extends CustomPainter {
  const _CelebrationPainter(this.progress);

  final double progress;

  static const _colors = [
    TapTussleColors.gold,
    TapTussleColors.electricBlue,
    Color(0xFFFF6B6B),
    Color(0xFF78E08F),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint();
    for (var index = 0; index < 28; index++) {
      final angle = index * math.pi * 2 / 28 + .17;
      final distance = math.min(size.width, size.height) * .48 * progress;
      final wobble = math.sin(index * 1.7) * 18 * progress;
      final position =
          center +
          Offset(
            math.cos(angle) * distance + math.cos(angle + math.pi / 2) * wobble,
            math.sin(angle) * distance + math.sin(angle + math.pi / 2) * wobble,
          );
      paint.color = _colors[index % _colors.length].withValues(
        alpha: (1 - progress * .35).clamp(0, 1),
      );
      canvas.save();
      canvas.translate(position.dx, position.dy);
      canvas.rotate(angle + progress * 2);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 5 + index % 3 * 2,
            height: 11 + index % 4 * 2,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_CelebrationPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

Widget _cardArrivalTransition(
  Widget child,
  Animation<double> animation, {
  required Offset begin,
  bool celebrate = false,
}) {
  final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutBack);
  final scale = Tween<double>(
    begin: celebrate ? .72 : .9,
    end: 1,
  ).animate(curved);
  return FadeTransition(
    opacity: animation,
    child: SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: ScaleTransition(scale: scale, child: child),
    ),
  );
}

Widget _flipCardTransition(Widget child, Animation<double> animation) =>
    AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final angle = (1 - animation.value) * math.pi / 2;
        return Opacity(
          opacity: animation.value.clamp(0, 1),
          child: Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, .001)
              ..rotateY(angle),
            child: child,
          ),
        );
      },
    );

class _CardDrag {
  const _CardDrag.waste()
    : type = SolitaireSelectionType.waste,
      pile = null,
      cardIndex = null,
      suit = null;

  const _CardDrag.tableau(this.pile, this.cardIndex)
    : type = SolitaireSelectionType.tableau,
      suit = null;

  const _CardDrag.foundation(this.suit)
    : type = SolitaireSelectionType.foundation,
      pile = null,
      cardIndex = null;

  final SolitaireSelectionType type;
  final int? pile;
  final int? cardIndex;
  final SolitaireSuit? suit;
}

String _hintLabel(SolitaireHint hint) => switch (hint.type) {
  SolitaireHintType.drawOrRecycle => 'TRY THIS: TAP THE DECK',
  SolitaireHintType.wasteToTableau => 'TRY THIS: MOVE THE OPEN CARD',
  SolitaireHintType.wasteToFoundation => 'TRY THIS: MOVE THE OPEN CARD UP',
  SolitaireHintType.tableauToTableau => 'TRY THIS: FOLLOW THE GOLD GLOW',
  SolitaireHintType.tableauToFoundation => 'TRY THIS: MOVE THE GOLD CARD UP',
  SolitaireHintType.foundationToTableau => 'TRY THIS: MOVE THE TOP CARD DOWN',
};

String _suitSymbol(SolitaireSuit suit) => switch (suit) {
  SolitaireSuit.clubs => '♣',
  SolitaireSuit.diamonds => '♦',
  SolitaireSuit.hearts => '♥',
  SolitaireSuit.spades => '♠',
};

String _suitName(SolitaireSuit suit) => switch (suit) {
  SolitaireSuit.clubs => 'clubs',
  SolitaireSuit.diamonds => 'diamonds',
  SolitaireSuit.hearts => 'hearts',
  SolitaireSuit.spades => 'spades',
};

String _rankSymbol(SolitaireRank rank) => switch (rank) {
  SolitaireRank.ace => 'A',
  SolitaireRank.jack => 'J',
  SolitaireRank.queen => 'Q',
  SolitaireRank.king => 'K',
  _ => '${rank.value}',
};

String _rankName(SolitaireRank rank) => switch (rank) {
  SolitaireRank.ace => 'Ace',
  SolitaireRank.jack => 'Jack',
  SolitaireRank.queen => 'Queen',
  SolitaireRank.king => 'King',
  _ => '${rank.value}',
};

String? _courtAsset(SolitaireRank rank) => switch (rank) {
  SolitaireRank.jack => 'assets/games/solitaire/jack.png',
  SolitaireRank.queen => 'assets/games/solitaire/queen.png',
  SolitaireRank.king => 'assets/games/solitaire/king.png',
  _ => null,
};
