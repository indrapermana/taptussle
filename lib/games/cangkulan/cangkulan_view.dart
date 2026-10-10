import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'cangkulan_controller.dart';
import 'cangkulan_model.dart';
import 'cangkulan_progress_repository.dart';

class CangkulanView extends StatefulWidget {
  const CangkulanView({
    required this.session,
    required this.options,
    this.controller,
    this.repository,
    this.botThinkDelay,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final CangkulanController? controller;
  final CangkulanProgressRepository? repository;
  final Duration? botThinkDelay;

  @override
  State<CangkulanView> createState() => _CangkulanViewState();
}

class _CangkulanViewState extends State<CangkulanView> {
  CangkulanController? controller;
  late final bool _ownsController = widget.controller == null;
  CangkulanTurnAction? _observedAction;
  var _observedRound = 0;

  @override
  void initState() {
    super.initState();
    final supplied = widget.controller;
    if (supplied != null) {
      _attach(supplied);
    } else if (widget.repository case final repository?) {
      _createController(repository);
    } else {
      _loadController();
    }
  }

  Future<void> _loadController() async {
    final repository = CangkulanProgressRepository(
      await SharedPreferences.getInstance(),
    );
    if (!mounted) return;
    setState(() => _createController(repository));
  }

  void _createController(CangkulanProgressRepository repository) {
    _attach(
      CangkulanController(
        session: widget.session,
        initialModel: repository.load(widget.options),
        repository: repository,
        botThinkDelay: widget.botThinkDelay,
      ),
    );
  }

  void _attach(CangkulanController next) {
    controller = next..addListener(_playEffects);
    _observedAction = next.lastAction;
    _observedRound = widget.session.round;
    SoundEffects.play(SoundEffect.cardShuffle);
  }

  void _playEffects() {
    final active = controller!;
    if (_observedRound != widget.session.round) {
      _observedRound = widget.session.round;
      SoundEffects.play(SoundEffect.cardShuffle);
    }
    final action = active.lastAction;
    if (identical(action, _observedAction) || action == null) return;
    _observedAction = action;
    SoundEffects.play(
      action.drawnCards.isNotEmpty
          ? SoundEffect.cardDraw
          : SoundEffect.cardPlace,
    );
    HapticEffects.preview();
  }

  @override
  void dispose() {
    controller?.removeListener(_playEffects);
    if (_ownsController) controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = controller;
    if (active == null) {
      return const Center(
        child: CircularProgressIndicator(key: ValueKey('cangkulan-loading')),
      );
    }
    return CangkulanBoard(
      controller: active,
      playerLabels: [
        for (var index = 0; index < widget.options.participants.length; index++)
          widget.options.playerLabel(index),
      ],
    );
  }
}

class CangkulanBoard extends StatelessWidget {
  const CangkulanBoard({
    required this.controller,
    required this.playerLabels,
    super.key,
  }) : assert(playerLabels.length >= 2 && playerLabels.length <= 4);

  final CangkulanController controller;
  final List<String> playerLabels;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => TapTussleBackdrop(
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            _TurnPanel(
              controller: controller,
              playerLabels: playerLabels,
              showHand: controller.phase == CangkulanViewPhase.turn,
            ),
            if (controller.phase == CangkulanViewPhase.handoff &&
                !controller.isBotTurn)
              ColoredBox(
                key: const ValueKey('cangkulan-handoff'),
                color: const Color(0xC2071324),
                child: _HandoffPanel(
                  playerLabel: playerLabels[controller.activePlayer],
                  lastAction: controller.lastAction,
                  playerLabels: playerLabels,
                  onReveal: controller.revealHand,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _HandoffPanel extends StatelessWidget {
  const _HandoffPanel({
    required this.playerLabel,
    required this.lastAction,
    required this.playerLabels,
    required this.onReveal,
  });

  final String playerLabel;
  final CangkulanTurnAction? lastAction;
  final List<String> playerLabels;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: ArcadePanel(
            accent: TapTussleColors.gold,
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.visibility_off_rounded,
                  color: TapTussleColors.gold,
                  size: 48,
                ),
                const SizedBox(height: 12),
                Text(
                  'HAND HIDDEN',
                  style: TextStyle(
                    fontFamily: 'Lilita One',
                    fontSize: 29,
                    color: TapTussleColors.text,
                  ),
                ),
                if (lastAction != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _safeActionSummary(lastAction!, playerLabels),
                    key: const ValueKey('cangkulan-last-action'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: TapTussleColors.mutedText),
                  ),
                ],
                const SizedBox(height: 20),
                Text(
                  'Pass the device to $playerLabel. Keep the screen hidden until they are ready.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: TapTussleColors.mutedText,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('cangkulan-reveal-hand'),
                    onPressed: onReveal,
                    icon: const Icon(Icons.visibility_rounded),
                    label: Text("I'M ${playerLabel.toUpperCase()}"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TurnPanel extends StatelessWidget {
  const _TurnPanel({
    required this.controller,
    required this.playerLabels,
    required this.showHand,
  });

  final CangkulanController controller;
  final List<String> playerLabels;
  final bool showHand;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 650;
      return Padding(
        key: const ValueKey('cangkulan-turn'),
        padding: EdgeInsets.fromLTRB(8, compact ? 5 : 8, 8, 7),
        child: Column(
          children: [
            _StatusPanel(controller: controller, labels: playerLabels),
            SizedBox(height: compact ? 5 : 8),
            Expanded(
              flex: 7,
              child: _PublicTable(controller: controller, labels: playerLabels),
            ),
            SizedBox(height: compact ? 5 : 8),
            Expanded(
              flex: 5,
              child: showHand
                  ? _HandGrid(
                      controller: controller,
                      compact: compact,
                      maxWidth: constraints.maxWidth,
                    )
                  : const SizedBox.expand(),
            ),
          ],
        ),
      );
    },
  );
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.controller, required this.labels});

  final CangkulanController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final suit = model.requiredSuit;
    return ArcadePanel(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
      accent: TapTussleColors.electricBlue,
      child: Column(
        children: [
          Text(
            '${labels[controller.activePlayer].toUpperCase()} • ${suit == null ? 'LEAD ANY SUIT' : 'FOLLOW ${_suitName(suit).toUpperCase()}'}',
            key: const ValueKey('cangkulan-status'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Lilita One',
              fontSize: 19,
              color: TapTussleColors.text,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 4,
            children: [
              for (var player = 0; player < model.participantCount; player++)
                Text(
                  '${labels[player]}: ${model.hands[player].length}',
                  key: ValueKey('cangkulan-hand-count-$player'),
                  style: TextStyle(
                    color: player == controller.activePlayer
                        ? TapTussleColors.gold
                        : TapTussleColors.mutedText,
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

class _PublicTable extends StatelessWidget {
  const _PublicTable({required this.controller, required this.labels});

  final CangkulanController controller;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    final model = controller.model;
    final completedTrick = controller.lastAction?.completedTrick;
    final displayedPlays = model.trickPlays.isNotEmpty
        ? model.trickPlays
        : completedTrick?.plays ?? const <CangkulanTrickPlay>[];
    return Semantics(
      label:
          'Draw pile, ${model.drawPile.length} cards. Current trick, ${displayedPlays.length} cards.',
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const ValueKey('cangkulan-card-table'),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        decoration: BoxDecoration(
          gradient: const RadialGradient(
            colors: [Color(0xFF19755F), Color(0xFF0B463E)],
            radius: 1.15,
          ),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: const Color(0xFFC58B42), width: 5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            if (controller.isBotTurn)
              _BotThinkingSeat(
                label: labels[controller.activePlayer],
                count: model.hands[controller.activePlayer].length,
                thinking: controller.isBotThinking,
              ),
            _OpponentSeats(
              model: model,
              labels: labels,
              activePlayer: controller.activePlayer,
            ),
            const SizedBox(height: 5),
            Expanded(
              child: Stack(
                children: [
                  Row(
                    children: [
                      _PileBack(count: model.drawPile.length),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          key: const ValueKey('cangkulan-trick-area'),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: .22),
                            ),
                          ),
                          child: displayedPlays.isEmpty
                              ? const Text(
                                  'PLAY A CARD HERE',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: .7,
                                  ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (completedTrick != null) ...[
                                      Text(
                                        '${labels[completedTrick.winner].toUpperCase()} WINS THE TRICK!',
                                        key: const ValueKey(
                                          'cangkulan-trick-winner',
                                        ),
                                        style: const TextStyle(
                                          color: TapTussleColors.gold,
                                          fontFamily: 'Lilita One',
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                    ],
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (final play
                                                in displayedPlays) ...[
                                              _MiniPlayedCard(
                                                play: play,
                                                label: labels[play.player],
                                                fromTop: controller
                                                    .session
                                                    .options
                                                    .participants[play.player]
                                                    .isBot,
                                                winner:
                                                    completedTrick?.winner ==
                                                    play.player,
                                              ),
                                              const SizedBox(width: 5),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                  if (controller.lastAction?.drawnCards.isNotEmpty ?? false)
                    Positioned.fill(
                      child: _DrawFlight(
                        key: ObjectKey(controller.lastAction),
                        count: controller.lastAction!.drawnCards.length,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotThinkingSeat extends StatelessWidget {
  const _BotThinkingSeat({
    required this.label,
    required this.count,
    required this.thinking,
  });

  final String label;
  final int count;
  final bool thinking;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('cangkulan-bot-thinking'),
    label: '$label is choosing a card',
    liveRegion: true,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CardBack(count: count, width: 38, height: 51),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              thinking ? 'CHOOSING A CARD…' : 'READY',
              style: const TextStyle(
                color: TapTussleColors.gold,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _DrawFlight extends StatelessWidget {
  const _DrawFlight({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: const ValueKey('cangkulan-draw-flight'),
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 420 + (count.clamp(1, 4) * 80)),
    curve: Curves.easeInOutCubic,
    builder: (context, value, child) => IgnorePointer(
      child: Align(
        alignment: Alignment.lerp(
          const Alignment(-.92, -.45),
          const Alignment(.15, .92),
          value,
        )!,
        child: Opacity(
          opacity: value > .92 ? (1 - value) / .08 : 1,
          child: Transform.rotate(
            angle: value * .18,
            child: Transform.scale(scale: .82 + value * .18, child: child),
          ),
        ),
      ),
    ),
    child: _CardBack(count: count, width: 48, height: 64),
  );
}

class _OpponentSeats extends StatelessWidget {
  const _OpponentSeats({
    required this.model,
    required this.labels,
    required this.activePlayer,
  });

  final CangkulanModel model;
  final List<String> labels;
  final int activePlayer;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
    children: [
      for (var offset = 1; offset < model.participantCount; offset++)
        Flexible(
          child: _OpponentSeat(
            player: (activePlayer + offset) % model.participantCount,
            label: labels[(activePlayer + offset) % model.participantCount],
            count: model
                .hands[(activePlayer + offset) % model.participantCount]
                .length,
          ),
        ),
    ],
  );
}

class _OpponentSeat extends StatelessWidget {
  const _OpponentSeat({
    required this.player,
    required this.label,
    required this.count,
  });

  final int player;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label has $count cards face down',
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _CardBack(count: count, width: 38, height: 51),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    ),
  );
}

class _HandGrid extends StatelessWidget {
  const _HandGrid({
    required this.controller,
    required this.compact,
    required this.maxWidth,
  });

  final CangkulanController controller;
  final bool compact;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final hand = controller.visibleHand;
    final legalCards = controller.model.legalCards;
    final columns = maxWidth >= 700
        ? 7
        : maxWidth >= 430
        ? 5
        : 4;
    return Column(
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR HAND',
                style: TextStyle(
                  fontFamily: 'Lilita One',
                  fontSize: 18,
                  color: TapTussleColors.gold,
                ),
              ),
            ),
            if (controller.model.mustCangkul)
              FilledButton.icon(
                key: const ValueKey('cangkulan-cangkul'),
                onPressed: controller.cangkul,
                style: FilledButton.styleFrom(
                  backgroundColor: TapTussleColors.gold,
                  foregroundColor: const Color(0xFF14213D),
                ),
                icon: const Icon(Icons.front_hand_rounded),
                label: const Text('CANGKUL • DRAW'),
              ),
          ],
        ),
        SizedBox(height: compact ? 5 : 9),
        Expanded(
          child: GridView.builder(
            key: const ValueKey('cangkulan-hand-grid'),
            itemCount: hand.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              childAspectRatio: compact ? .78 : .69,
              crossAxisSpacing: 7,
              mainAxisSpacing: 7,
            ),
            itemBuilder: (context, index) {
              final card = hand[index];
              final legal = legalCards.contains(card);
              return AnimatedScale(
                scale: legal ? 1 : .93,
                duration: const Duration(milliseconds: 180),
                child: _HandCard(
                  key: ValueKey('cangkulan-hand-$index'),
                  card: card,
                  enabled: legal,
                  onTap: () => controller.playCard(card),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _HandCard extends StatelessWidget {
  const _HandCard({
    required this.card,
    required this.enabled,
    required this.onTap,
    super.key,
  });

  final CangkulanCard card;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final red =
        card.suit == CangkulanSuit.hearts ||
        card.suit == CangkulanSuit.diamonds;
    final label = '${_rankName(card.rank)} of ${_suitName(card.suit)}';
    return Semantics(
      label: '$label${enabled ? ', playable' : ', must follow suit'}',
      button: true,
      enabled: enabled,
      child: ExcludeSemantics(
        child: FilledButton(
          onPressed: enabled ? onTap : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.all(4),
            backgroundColor: const Color(0xFFFFFCF2),
            foregroundColor: red
                ? const Color(0xFFC62828)
                : const Color(0xFF14213D),
            disabledBackgroundColor: const Color(0xFFEEE8D8),
            disabledForegroundColor: const Color(0xFF8B8B8B),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: enabled
                    ? TapTussleColors.gold
                    : TapTussleColors.panelBorder,
                width: enabled ? 3 : 1,
              ),
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _rankSymbol(card.rank),
                  style: const TextStyle(
                    fontFamily: 'Lilita One',
                    fontSize: 27,
                  ),
                ),
                Text(
                  _suitSymbol(card.suit),
                  style: const TextStyle(fontSize: 25),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PileBack extends StatelessWidget {
  const _PileBack({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Draw pile, $count cards',
    child: SizedBox(
      key: const ValueKey('cangkulan-draw-pile'),
      width: 56,
      height: 78,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CardBack(count: count, width: 48, height: 64),
            const SizedBox(height: 2),
            const Text(
              'DRAW',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _CardBack extends StatelessWidget {
  const _CardBack({
    required this.count,
    required this.width,
    required this.height,
  });

  final int count;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width + 8,
    height: height + 4,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        if (count > 1)
          Positioned(left: 5, top: 2, child: _cardBackImage(width, height)),
        _cardBackImage(width, height),
        Positioned(
          right: -2,
          bottom: -2,
          child: Container(
            constraints: const BoxConstraints(minWidth: 23, minHeight: 23),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              color: TapTussleColors.gold,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Color(0xFF14213D),
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _cardBackImage(double width, double height) => ClipRRect(
    borderRadius: BorderRadius.circular(7),
    child: Image.asset(
      'assets/games/cangkulan/card_back.png',
      width: width,
      height: height,
      fit: BoxFit.cover,
      alignment: Alignment.center,
    ),
  );
}

class _MiniPlayedCard extends StatelessWidget {
  const _MiniPlayedCard({
    required this.play,
    required this.label,
    required this.fromTop,
    required this.winner,
  });

  final CangkulanTrickPlay play;
  final String label;
  final bool fromTop;
  final bool winner;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label played ${_rankName(play.card.rank)} of ${_suitName(play.card.suit)}',
    child: TweenAnimationBuilder<double>(
      key: ValueKey('cangkulan-played-card-${play.player}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.translate(
        offset: Offset(0, (1 - value) * (fromTop ? -42 : 42)),
        child: Transform.scale(
          scale: (.75 + value * .25) * (winner ? 1.08 : 1),
          child: child,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFFFCF2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: winner ? TapTussleColors.gold : Colors.white,
                width: winner ? 4 : 2,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4),
              ],
            ),
            child: Text(
              '${_rankSymbol(play.card.rank)}${_suitSymbol(play.card.suit)}',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color:
                    play.card.suit == CangkulanSuit.hearts ||
                        play.card.suit == CangkulanSuit.diamonds
                    ? const Color(0xFFC62828)
                    : const Color(0xFF14213D),
              ),
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 9),
            ),
          ),
        ],
      ),
    ),
  );
}

String _safeActionSummary(CangkulanTurnAction action, List<String> labels) {
  final label = labels[action.player];
  if (action.wonMatch) return '$label emptied their hand.';
  final trick = action.completedTrick;
  if (trick != null) return '${labels[trick.winner]} won the trick.';
  if (action.skipped) return '$label could not follow suit and was skipped.';
  if (action.drawnCards.isNotEmpty) {
    return '$label drew ${action.drawnCards.length} card${action.drawnCards.length == 1 ? '' : 's'}.';
  }
  return '$label played a card.';
}

String _suitSymbol(CangkulanSuit suit) => switch (suit) {
  CangkulanSuit.clubs => '♣',
  CangkulanSuit.diamonds => '♦',
  CangkulanSuit.hearts => '♥',
  CangkulanSuit.spades => '♠',
};

String _suitName(CangkulanSuit suit) => suit.name;

String _rankSymbol(CangkulanRank rank) => switch (rank) {
  CangkulanRank.jack => 'J',
  CangkulanRank.queen => 'Q',
  CangkulanRank.king => 'K',
  CangkulanRank.ace => 'A',
  _ => '${rank.strength}',
};

String _rankName(CangkulanRank rank) => switch (rank) {
  CangkulanRank.jack => 'Jack',
  CangkulanRank.queen => 'Queen',
  CangkulanRank.king => 'King',
  CangkulanRank.ace => 'Ace',
  _ => '${rank.strength}',
};
