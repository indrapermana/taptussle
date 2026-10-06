import 'dart:math' as math;

import 'package:flutter/material.dart';
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
    final saved = repository.loadActive(difficulty);
    setState(() {
      controller = SolitaireController(
        session: widget.session,
        difficulty: difficulty,
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
            : LayoutBuilder(
                builder: (context, constraints) {
                  final compact = constraints.maxHeight < 650;
                  final horizontalPadding = compact ? 6.0 : 12.0;
                  final gap = constraints.maxWidth < 430 ? 3.0 : 7.0;
                  final usableWidth = math.min(
                    constraints.maxWidth - horizontalPadding * 2,
                    820,
                  );
                  final cardWidth = ((usableWidth - gap * 6) / 7).clamp(
                    39.0,
                    96.0,
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
                        SizedBox(height: compact ? 4 : 8),
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

  final SolitaireController controller;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final status = controller.model.isComplete
        ? 'SOLITAIRE COMPLETE!'
        : controller.isAnimating
        ? 'MOVING CARD…'
        : controller.shownHint != null
        ? _hintLabel(controller.shownHint!)
        : controller.selection != null
        ? 'CHOOSE A DESTINATION'
        : 'BUILD THE FOUNDATIONS';
    return ArcadePanel(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 7 : 10,
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
                  controller.model.drawMode == SolitaireDrawMode.drawThree
                      ? 'DRAW THREE'
                      : 'DRAW ONE',
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    color: TapTussleColors.electricBlue,
                    fontSize: 14,
                  ),
                ),
                Text(
                  status,
                  key: const ValueKey('solitaire-status'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    fontSize: compact ? 16 : 20,
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
                '${controller.model.score} PTS',
                key: const ValueKey('solitaire-score'),
                semanticsLabel: '${controller.model.score} points',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              Text(
                '${controller.model.moveCount} MOVES • ${controller.elapsedLabel}',
                key: const ValueKey('solitaire-stats'),
                semanticsLabel:
                    '${controller.model.moveCount} moves, elapsed ${controller.elapsedLabel}',
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
        child: empty
            ? _EmptySlot(width: width, height: height, symbol: '↻')
            : _CardBack(width: width, height: height),
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
      return _EmptySlot(width: width, height: height, symbol: 'W');
    }
    final selected = controller.selection?.type == SolitaireSelectionType.waste;
    final child = _PlayingCard(
      card: card,
      width: width,
      height: height,
      selected: selected,
      onTap: controller.tapWaste,
      key: ValueKey('solitaire-waste-${card.suit.name}-${card.rank.name}'),
    );
    return _DraggableCard(
      data: const _CardDrag.waste(),
      card: card,
      width: width,
      height: height,
      enabled: controller.acceptsInput,
      child: child,
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
    final highlighted =
        hint?.type == SolitaireHintType.wasteToFoundation ||
        (hint?.type == SolitaireHintType.tableauToFoundation);
    Widget child = card == null
        ? _EmptySlot(
            width: width,
            height: height,
            symbol: _suitSymbol(suit),
            highlighted: highlighted,
          )
        : _PlayingCard(
            card: card,
            width: width,
            height: height,
            selected: selected,
            highlighted: highlighted,
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
        label: '${_suitName(suit)} foundation, ${pile.length} cards',
        button: true,
        child: GestureDetector(
          onTap: controller.acceptsInput
              ? () => controller.tapFoundation(suit)
              : null,
          child: AnimatedScale(
            scale: candidates.isEmpty ? 1 : 1.07,
            duration: const Duration(milliseconds: 120),
            child: child,
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
                : 'Tableau ${pile + 1}, ${cards.length} cards, '
                      '${cards.where((entry) => !entry.isFaceUp).length} face down',
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
                      : Colors.transparent,
                  width: 2,
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
    if (!entry.isFaceUp) {
      return Semantics(
        label: 'Tableau ${pile + 1}, face-down card ${index + 1}',
        child: _CardBack(width: width, height: height),
      );
    }
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
    return _DraggableCard(
      data: _CardDrag.tableau(pile, index),
      card: entry.card,
      width: width,
      height: height,
      enabled: controller.acceptsInput,
      child: card,
    );
  }
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
    this.onTap,
    super.key,
  });

  final SolitaireCard card;
  final double width;
  final double height;
  final bool selected;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final red = card.color == SolitaireCardColor.red;
    final color = red ? const Color(0xFFC62828) : const Color(0xFF14213D);
    final label = '${_rankName(card.rank)} of ${_suitName(card.suit)}';
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
                      : const Color(0xFFCBD5E1),
                  width: selected || highlighted ? 2.5 : 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: FittedBox(
                alignment: Alignment.topLeft,
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
                      style: TextStyle(color: color, fontSize: 22, height: 1),
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
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(math.max(5, width * .11)),
      border: Border.all(color: const Color(0xFFBDEBFF), width: 1.5),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFEB3349), Color(0xFF102A70), Color(0xFF27C7FF)],
      ),
      boxShadow: const [
        BoxShadow(
          color: Color(0x55000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: Icon(Icons.bolt_rounded, color: Colors.white, size: width * .45),
    ),
  );
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({
    required this.width,
    required this.height,
    required this.symbol,
    this.highlighted = false,
  });

  final double width;
  final double height;
  final String symbol;
  final bool highlighted;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 140),
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .16),
      borderRadius: BorderRadius.circular(math.max(5, width * .11)),
      border: Border.all(
        color: highlighted ? TapTussleColors.gold : TapTussleColors.panelBorder,
        width: highlighted ? 2.5 : 1.2,
      ),
    ),
    child: Center(
      child: Text(
        symbol,
        style: TextStyle(
          fontFamily: 'Lilita One',
          color: highlighted
              ? TapTussleColors.gold
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
        onPressed: controller.acceptsInput && controller.model.canUndo
            ? controller.undo
            : null,
        icon: const Icon(Icons.undo_rounded),
        label: Text(compact ? 'UNDO' : 'UNDO MOVE'),
      ),
      const SizedBox(width: 10),
      FilledButton.icon(
        key: const ValueKey('solitaire-hint'),
        onPressed: controller.acceptsInput ? controller.requestHint : null,
        icon: const Icon(Icons.lightbulb_rounded),
        label: const Text('HINT'),
      ),
    ],
  );
}

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
  SolitaireHintType.drawOrRecycle => 'HINT: DRAW FROM STOCK',
  SolitaireHintType.wasteToTableau =>
    'HINT: WASTE → TABLEAU ${hint.destination! + 1}',
  SolitaireHintType.wasteToFoundation => 'HINT: WASTE → FOUNDATION',
  SolitaireHintType.tableauToTableau =>
    'HINT: TABLEAU ${hint.source! + 1} → ${hint.destination! + 1}',
  SolitaireHintType.tableauToFoundation =>
    'HINT: TABLEAU ${hint.source! + 1} → FOUNDATION',
  SolitaireHintType.foundationToTableau =>
    'HINT: FOUNDATION → TABLEAU ${hint.destination! + 1}',
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
