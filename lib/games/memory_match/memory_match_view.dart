import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/haptic_service.dart';
import '../../core/sound_service.dart';
import 'memory_match_assets.dart';
import 'memory_match_controller.dart';
import 'memory_match_model.dart';

class MemoryMatchView extends StatefulWidget {
  const MemoryMatchView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<MemoryMatchView> createState() => _MemoryMatchViewState();
}

class _MemoryMatchViewState extends State<MemoryMatchView> {
  late final MemoryMatchController controller;
  late int _observedRound;
  Set<int> _matchedFeedback = const {};
  Set<int> _mismatchFeedback = const {};
  Timer? _feedbackTimer;

  @override
  void initState() {
    super.initState();
    controller = MemoryMatchController(
      session: widget.session,
      difficulty: MemoryMatchDifficulty.values[widget.options.difficulty.index],
      resultRevealDelay: const Duration(milliseconds: 1300),
      onSelection: _handleSelection,
    );
    _observedRound = widget.session.round;
    widget.session.addListener(_handleSessionChange);
    SoundEffects.play(SoundEffect.cardShuffle);
  }

  void _handleSessionChange() {
    if (widget.session.round == _observedRound) return;
    _observedRound = widget.session.round;
    _clearFeedback();
    SoundEffects.play(SoundEffect.cardShuffle);
  }

  void _showFeedback({required bool matched}) {
    _feedbackTimer?.cancel();
    final cards = controller.lastSelectedCards.toSet();
    if (cards.isEmpty || !mounted) return;
    setState(() {
      _matchedFeedback = matched ? cards : const {};
      _mismatchFeedback = matched ? const {} : cards;
    });
    _feedbackTimer = Timer(const Duration(milliseconds: 620), _clearFeedback);
  }

  void _clearFeedback() {
    _feedbackTimer?.cancel();
    _feedbackTimer = null;
    if (!mounted || (_matchedFeedback.isEmpty && _mismatchFeedback.isEmpty)) {
      return;
    }
    setState(() {
      _matchedFeedback = const {};
      _mismatchFeedback = const {};
    });
  }

  void _handleSelection(MemorySelectionResult result) {
    switch (result) {
      case MemorySelectionResult.firstCard:
        SoundEffects.play(SoundEffect.cardFlip);
        HapticEffects.preview();
      case MemorySelectionResult.matched:
      case MemorySelectionResult.completed:
        _showFeedback(matched: true);
        SoundEffects.play(SoundEffect.cardFlip);
        SoundEffects.play(SoundEffect.matchPair);
        HapticEffects.paddleHit();
      case MemorySelectionResult.mismatch:
        _showFeedback(matched: false);
        SoundEffects.play(SoundEffect.cardFlip);
        SoundEffects.play(SoundEffect.uiInvalid);
        HapticEffects.preview();
      case MemorySelectionResult.invalidPlayer:
      case MemorySelectionResult.outOfBounds:
      case MemorySelectionResult.wrongTurn:
      case MemorySelectionResult.unavailable:
      case MemorySelectionResult.awaitingMismatchResolution:
      case MemorySelectionResult.matchFinished:
        break;
    }
  }

  @override
  void dispose() {
    _feedbackTimer?.cancel();
    widget.session.removeListener(_handleSessionChange);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MemoryMatchBoard(
    controller: controller,
    playerLabels: widget.options.participants
        .map((participant) => participant.displayName)
        .toList(growable: false),
    matchedFeedback: _matchedFeedback,
    mismatchFeedback: _mismatchFeedback,
  );
}

class MemoryMatchBoard extends StatelessWidget {
  const MemoryMatchBoard({
    required this.controller,
    required this.playerLabels,
    this.onSelection,
    this.matchedFeedback = const {},
    this.mismatchFeedback = const {},
    super.key,
  }) : assert(playerLabels.length > 0 && playerLabels.length <= 2);

  final MemoryMatchController controller;
  final List<String> playerLabels;
  final ValueChanged<MemorySelectionResult>? onSelection;
  final Set<int> matchedFeedback;
  final Set<int> mismatchFeedback;

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
                      showMatchFeedback: matchedFeedback.isNotEmpty,
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
                          // Use the exact available cell ratio so every row is
                          // reachable even after the shared match HUD reduces
                          // the board height on compact screens.
                          final aspectRatio = cardWidth / cardHeight;
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
                              matchedFeedback: matchedFeedback.contains(index),
                              mismatchFeedback: mismatchFeedback.contains(
                                index,
                              ),
                              onTap: () {
                                final result = controller.selectCard(index);
                                onSelection?.call(result);
                              },
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
  const _MemoryStatus({
    required this.controller,
    required this.playerLabels,
    required this.showMatchFeedback,
  });

  final MemoryMatchController controller;
  final List<String> playerLabels;
  final bool showMatchFeedback;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final isMultiplayer = model.playerCount == 2;
    final status = controller.isPreviewing
        ? 'MEMORIZE!'
        : showMatchFeedback
        ? 'MATCH!'
        : model.hasPendingMismatch
        ? 'TRY AGAIN'
        : model.isFinished
        ? 'ALL PAIRS FOUND!'
        : controller.isBotTurn
        ? 'BOT THINKING…'
        : model.playerCount == 1
        ? 'YOUR TURN'
        : '${playerLabels[model.currentPlayer].toUpperCase()} TURN';
    final statusColor = controller.isPreviewing
        ? TapTussleColors.gold
        : showMatchFeedback
        ? const Color(0xFF9DF5CF)
        : model.hasPendingMismatch
        ? const Color(0xFFFF7C72)
        : controller.isBotTurn
        ? TapTussleColors.electricBlue
        : Colors.white;
    final statusIcon = controller.isPreviewing
        ? Icons.visibility_rounded
        : showMatchFeedback
        ? Icons.auto_awesome_rounded
        : model.hasPendingMismatch
        ? Icons.refresh_rounded
        : controller.isBotTurn
        ? Icons.smart_toy_rounded
        : model.isFinished
        ? Icons.emoji_events_rounded
        : Icons.touch_app_rounded;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMultiplayer) ...[
          Row(
            children: [
              for (var player = 0; player < 2; player++) ...[
                if (player > 0) const SizedBox(width: 8),
                Expanded(
                  child: _MemoryPlayerBadge(
                    label: playerLabels[player],
                    score: model.scores[player],
                    player: player,
                    isBot:
                        controller.session.options.participants[player].isBot,
                    active:
                        !controller.isPreviewing &&
                        !model.isFinished &&
                        model.currentPlayer == player,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 7),
        ],
        ArcadePanel(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          borderRadius: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  if (controller.isBotThinking)
                    const SizedBox.square(
                      dimension: 19,
                      child: CircularProgressIndicator(
                        key: ValueKey('memory-bot-thinking'),
                        strokeWidth: 2.5,
                        color: TapTussleColors.electricBlue,
                      ),
                    )
                  else
                    Icon(statusIcon, color: statusColor, size: 21),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        status,
                        key: const ValueKey('memory-status'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Lilita One',
                          color: statusColor,
                          fontSize: 17,
                          letterSpacing: .7,
                        ),
                      ),
                    ),
                  ),
                  if (!isMultiplayer) ...[
                    _MemoryStatChip(
                      key: const ValueKey('memory-moves'),
                      label: 'MOVES',
                      value: '${model.moveCount}',
                    ),
                    const SizedBox(width: 6),
                    _MemoryStatChip(
                      key: const ValueKey('memory-pairs'),
                      label: 'PAIRS',
                      value: '${model.matchedPairs}/${model.pairCount}',
                    ),
                  ],
                ],
              ),
              if (controller.isPreviewing) ...[
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: TweenAnimationBuilder<double>(
                    key: ValueKey('memory-preview-${controller.session.round}'),
                    tween: Tween(begin: 1, end: 0),
                    duration: controller.previewDuration,
                    builder: (context, value, _) => LinearProgressIndicator(
                      key: const ValueKey('memory-preview-progress'),
                      minHeight: 6,
                      value: value,
                      backgroundColor: Colors.white12,
                      color: TapTussleColors.gold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MemoryPlayerBadge extends StatelessWidget {
  const _MemoryPlayerBadge({
    required this.label,
    required this.score,
    required this.player,
    required this.isBot,
    required this.active,
  });

  final String label;
  final int score;
  final int player;
  final bool isBot;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = player == 0
        ? const Color(0xFF9DF5CF)
        : const Color(0xFFFF968A);
    return Semantics(
      label: '$label, $score pairs${active ? ', current turn' : ''}',
      container: true,
      excludeSemantics: true,
      child: AnimatedContainer(
        key: ValueKey('memory-player-$player'),
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: .18) : TapTussleColors.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: active ? color : Colors.white24,
            width: active ? 2.5 : 1,
          ),
          boxShadow: active
              ? [BoxShadow(color: color.withValues(alpha: .24), blurRadius: 10)]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: active ? Colors.white : Colors.white70,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '$score',
              key: ValueKey('memory-player-score-$player'),
              style: TextStyle(
                color: color,
                fontFamily: 'Lilita One',
                fontSize: 19,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoryStatChip extends StatelessWidget {
  const _MemoryStatChip({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: TapTussleColors.gold,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              height: 1,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontWeight: FontWeight.w700,
              fontSize: 8,
              height: 1.15,
            ),
          ),
        ],
      ),
    ),
  );
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({
    required this.index,
    required this.card,
    required this.faceUp,
    required this.enabled,
    required this.matchedFeedback,
    required this.mismatchFeedback,
    required this.onTap,
  });

  final int index;
  final MemoryMatchCard card;
  final bool faceUp;
  final bool enabled;
  final bool matchedFeedback;
  final bool mismatchFeedback;
  final VoidCallback onTap;

  static const _colors = <Color>[
    TapTussleColors.gold,
    TapTussleColors.rivalRed,
    TapTussleColors.electricBlue,
    Color(0xFF9DF5CF),
  ];

  @override
  Widget build(BuildContext context) {
    final matched = card.state == MemoryCardState.matched;
    final symbol = MemoryMatchAssets.symbols[card.pairId];
    final label = !faceUp
        ? 'Hidden card ${index + 1}'
        : matched
        ? 'Matched ${symbol.name}, card ${index + 1}'
        : 'Revealed ${symbol.name}, card ${index + 1}';
    final accent = matched
        ? TapTussleColors.gold
        : faceUp
        ? _colors[card.pairId % _colors.length]
        : TapTussleColors.electricBlue;
    final cardWidget = Semantics(
      label: label,
      button: !faceUp && enabled,
      enabled: !faceUp && enabled,
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 180),
          opacity: matched ? .88 : 1,
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
                  color: faceUp ? const Color(0xFFFFFBF1) : Colors.transparent,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: mismatchFeedback
                        ? const Color(0xFFFF4D55)
                        : accent.withValues(alpha: faceUp ? 1 : .55),
                    width: matched || mismatchFeedback
                        ? 3
                        : (faceUp ? 2.5 : 1.5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (mismatchFeedback ? const Color(0xFFFF4D55) : accent)
                              .withValues(
                                alpha: matched || mismatchFeedback ? .34 : .18,
                              ),
                      blurRadius: matched || mismatchFeedback ? 12 : 8,
                    ),
                  ],
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: faceUp ? 1 : 0),
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeInOutCubic,
                  builder: (context, progress, _) {
                    final showFront = progress >= .5;
                    final perspective = Matrix4.identity()
                      ..setEntry(3, 2, .0015)
                      ..rotateY(math.pi * progress);
                    return Transform(
                      alignment: Alignment.center,
                      transform: perspective,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(showFront ? math.pi : 0),
                        child: showFront
                            ? _MemoryCardFace(
                                index: index,
                                pairId: card.pairId,
                                matched: matched,
                                showMatchFeedback: matchedFeedback,
                                showMismatchFeedback: mismatchFeedback,
                              )
                            : _MemoryCardBack(index: index),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!matchedFeedback && !mismatchFeedback) return cardWidget;
    return TweenAnimationBuilder<double>(
      key: ValueKey(
        'memory-feedback-$index-${matchedFeedback ? 'match' : 'mismatch'}',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOut,
      child: cardWidget,
      builder: (context, progress, child) {
        final offset = mismatchFeedback
            ? math.sin(progress * math.pi * 8) * (1 - progress) * 7
            : 0.0;
        final scale = matchedFeedback
            ? 1 + math.sin(progress * math.pi) * .1
            : 1.0;
        return Transform.translate(
          offset: Offset(offset, 0),
          child: Transform.scale(scale: scale, child: child),
        );
      },
    );
  }
}

class _MemoryCardBack extends StatelessWidget {
  const _MemoryCardBack({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(3),
    child: Image.asset(
      MemoryMatchAssets.cardBack,
      key: ValueKey('memory-card-back-$index'),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    ),
  );
}

class _MemoryCardFace extends StatelessWidget {
  const _MemoryCardFace({
    required this.index,
    required this.pairId,
    required this.matched,
    required this.showMatchFeedback,
    required this.showMismatchFeedback,
  });

  final int index;
  final int pairId;
  final bool matched;
  final bool showMatchFeedback;
  final bool showMismatchFeedback;

  @override
  Widget build(BuildContext context) {
    final symbol = MemoryMatchAssets.symbols[pairId];
    return Stack(
      fit: StackFit.expand,
      children: [
        FractionallySizedBox(
          widthFactor: .82,
          heightFactor: .82,
          child: Image.asset(
            symbol.path,
            key: ValueKey('memory-card-front-$index'),
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
        ),
        if (matched)
          const Positioned(
            right: 3,
            top: 3,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: TapTussleColors.gold,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x66000000), blurRadius: 4)],
              ),
              child: Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.check_rounded,
                  color: Color(0xFF342300),
                  size: 15,
                ),
              ),
            ),
          ),
        if (showMatchFeedback || showMismatchFeedback)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Icon(
                  showMatchFeedback
                      ? Icons.auto_awesome_rounded
                      : Icons.close_rounded,
                  key: ValueKey(
                    'memory-card-feedback-$index-${showMatchFeedback ? 'match' : 'mismatch'}',
                  ),
                  color: showMatchFeedback
                      ? TapTussleColors.gold
                      : const Color(0xFFFF4D55),
                  size: showMatchFeedback ? 28 : 30,
                  shadows: const [
                    Shadow(color: Color(0xCC101A27), blurRadius: 6),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
