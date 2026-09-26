import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import 'memory_match_controller.dart';
import 'memory_match_model.dart';

class MemoryMatchBoard extends StatelessWidget {
  const MemoryMatchBoard({
    required this.controller,
    required this.playerLabels,
    super.key,
  }) : assert(playerLabels.length > 0 && playerLabels.length <= 2);

  final MemoryMatchController controller;
  final List<String> playerLabels;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final model = controller.model;
      return ColoredBox(
        color: const Color(0xFF101A27),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final spacing = constraints.maxWidth < 360 ? 6.0 : 9.0;
              return Padding(
                padding: EdgeInsets.fromLTRB(spacing, 12, spacing, spacing),
                child: Column(
                  children: [
                    _MemoryStatus(
                      controller: controller,
                      playerLabels: playerLabels,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, gridConstraints) {
                          final columns = model.difficulty.columns;
                          final rows = model.difficulty.rows;
                          final cardWidth =
                              (gridConstraints.maxWidth -
                                  spacing * (columns - 1)) /
                              columns;
                          final cardHeight =
                              (gridConstraints.maxHeight -
                                  spacing * (rows - 1)) /
                              rows;
                          final aspectRatio = (cardWidth / cardHeight).clamp(
                            .62,
                            1.08,
                          );
                          return GridView.builder(
                            key: const ValueKey('memory-card-grid'),
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  mainAxisSpacing: spacing,
                                  crossAxisSpacing: spacing,
                                  childAspectRatio: aspectRatio,
                                ),
                            itemCount: model.cardCount,
                            itemBuilder: (context, index) => _MemoryCard(
                              index: index,
                              card: model.cardAt(index),
                              faceUp: controller.isCardFaceUp(index),
                              enabled: controller.acceptsInput,
                              onTap: () => controller.selectCard(index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

class _MemoryStatus extends StatelessWidget {
  const _MemoryStatus({required this.controller, required this.playerLabels});

  final MemoryMatchController controller;
  final List<String> playerLabels;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final status = controller.isPreviewing
        ? 'MEMORIZE THE CARDS'
        : model.hasPendingMismatch
        ? 'NOT A MATCH'
        : model.isFinished
        ? 'ALL PAIRS FOUND'
        : model.playerCount == 1
        ? 'MOVES ${model.moveCount}'
        : '${playerLabels[model.currentPlayer].toUpperCase()}\'S TURN';
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      borderRadius: 16,
      child: Row(
        children: [
          Expanded(
            child: Text(
              status,
              key: const ValueKey('memory-status'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Lilita One',
                color: Colors.white,
                fontSize: 15,
                letterSpacing: .6,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            model.playerCount == 1
                ? '${model.matchedPairs}/${model.pairCount} PAIRS'
                : '${model.scores[0]}  •  ${model.scores[1]}',
            style: const TextStyle(
              color: TapTussleColors.gold,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.index,
    required this.card,
    required this.faceUp,
    required this.enabled,
    required this.onTap,
  });

  final int index;
  final MemoryMatchCard card;
  final bool faceUp;
  final bool enabled;
  final VoidCallback onTap;

  static const _icons = <IconData>[
    Icons.star_rounded,
    Icons.favorite_rounded,
    Icons.bolt_rounded,
    Icons.pets_rounded,
    Icons.rocket_launch_rounded,
    Icons.sports_esports_rounded,
    Icons.music_note_rounded,
    Icons.icecream_rounded,
    Icons.local_fire_department_rounded,
    Icons.wb_sunny_rounded,
    Icons.emoji_nature_rounded,
    Icons.auto_awesome_rounded,
  ];
  static const _colors = <Color>[
    TapTussleColors.gold,
    TapTussleColors.rivalRed,
    TapTussleColors.electricBlue,
    Color(0xFF9DF5CF),
  ];

  @override
  Widget build(BuildContext context) {
    final matched = card.state == MemoryCardState.matched;
    final symbol = card.pairId + 1;
    final label = !faceUp
        ? 'Hidden card ${index + 1}'
        : matched
        ? 'Matched card $symbol'
        : 'Revealed card $symbol';
    return Semantics(
      label: label,
      button: !faceUp && enabled,
      enabled: !faceUp && enabled,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: matched ? .48 : 1,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('memory-card-$index'),
              borderRadius: BorderRadius.circular(13),
              onTap: !faceUp && enabled ? onTap : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: faceUp
                      ? const Color(0xFFF7F2E8)
                      : TapTussleColors.panel,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: faceUp
                        ? _colors[card.pairId % _colors.length]
                        : TapTussleColors.electricBlue.withValues(alpha: .55),
                    width: faceUp ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (faceUp
                                  ? _colors[card.pairId % _colors.length]
                                  : TapTussleColors.electricBlue)
                              .withValues(alpha: .18),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 150),
                    child: Icon(
                      faceUp
                          ? _icons[card.pairId % _icons.length]
                          : Icons.question_mark_rounded,
                      key: ValueKey(faceUp ? 'face-$symbol' : 'hidden'),
                      color: faceUp
                          ? _colors[card.pairId % _colors.length]
                          : Colors.white70,
                      size: faceUp ? 31 : 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
