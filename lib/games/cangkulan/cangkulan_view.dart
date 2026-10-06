import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'cangkulan_controller.dart';
import 'cangkulan_model.dart';

class CangkulanView extends StatefulWidget {
  const CangkulanView({
    required this.session,
    required this.options,
    this.controller,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final CangkulanController? controller;

  @override
  State<CangkulanView> createState() => _CangkulanViewState();
}

class _CangkulanViewState extends State<CangkulanView> {
  late final CangkulanController controller =
      widget.controller ?? CangkulanController(session: widget.session);
  late final bool _ownsController = widget.controller == null;

  @override
  void dispose() {
    if (_ownsController) controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CangkulanBoard(
    controller: controller,
    playerLabels: [
      for (var index = 0; index < widget.options.participants.length; index++)
        widget.options.playerLabel(index),
    ],
  );
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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: controller.phase == CangkulanViewPhase.handoff
              ? _HandoffPanel(
                  key: const ValueKey('cangkulan-handoff'),
                  playerLabel: playerLabels[controller.activePlayer],
                  lastAction: controller.lastAction,
                  playerLabels: playerLabels,
                  onReveal: controller.revealHand,
                )
              : _TurnPanel(
                  key: const ValueKey('cangkulan-turn'),
                  controller: controller,
                  playerLabels: playerLabels,
                ),
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
    super.key,
  });

  final String playerLabel;
  final CangkulanTurnAction? lastAction;
  final List<String> playerLabels;
  final VoidCallback onReveal;

  @override
  Widget build(BuildContext context) => Center(
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
              const Text(
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

class _TurnPanel extends StatelessWidget {
  const _TurnPanel({
    required this.controller,
    required this.playerLabels,
    super.key,
  });

  final CangkulanController controller;
  final List<String> playerLabels;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxHeight < 650;
      return Padding(
        padding: EdgeInsets.fromLTRB(12, compact ? 8 : 14, 12, 10),
        child: Column(
          children: [
            _StatusPanel(controller: controller, labels: playerLabels),
            SizedBox(height: compact ? 7 : 12),
            _PublicTable(controller: controller, labels: playerLabels),
            SizedBox(height: compact ? 7 : 12),
            Expanded(
              child: _HandGrid(
                controller: controller,
                compact: compact,
                maxWidth: constraints.maxWidth,
              ),
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
    return Semantics(
      label:
          'Draw pile, ${model.drawPile.length} cards. Current trick, ${model.trickPlays.length} cards.',
      container: true,
      child: ArcadePanel(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Row(
          children: [
            _PileBack(count: model.drawPile.length),
            const SizedBox(width: 12),
            Expanded(
              child: model.trickPlays.isEmpty
                  ? const Text(
                      'No cards played yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: TapTussleColors.mutedText),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final play in model.trickPlays) ...[
                            _MiniPlayedCard(
                              play: play,
                              label: labels[play.player],
                            ),
                            const SizedBox(width: 7),
                          ],
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
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
                icon: const Icon(Icons.download_rounded),
                label: const Text('CANGKUL'),
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
              return _HandCard(
                key: ValueKey('cangkulan-hand-$index'),
                card: card,
                enabled: legal,
                onTap: () => controller.playCard(card),
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
            padding: const EdgeInsets.all(5),
            backgroundColor: const Color(0xFFFFFCF2),
            foregroundColor: red
                ? const Color(0xFFC62828)
                : const Color(0xFF14213D),
            disabledBackgroundColor: const Color(0xFF697386),
            disabledForegroundColor: const Color(0xFFD2D8E1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(
                color: enabled
                    ? TapTussleColors.gold
                    : TapTussleColors.panelBorder,
                width: enabled ? 2 : 1,
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
    child: Container(
      key: const ValueKey('cangkulan-draw-pile'),
      width: 48,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [TapTussleColors.rivalRed, TapTussleColors.electricBlue],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 2),
      ),
      child: Text(
        '$count',
        style: const TextStyle(
          fontFamily: 'Lilita One',
          fontSize: 18,
          color: Colors.white,
        ),
      ),
    ),
  );
}

class _MiniPlayedCard extends StatelessWidget {
  const _MiniPlayedCard({required this.play, required this.label});

  final CangkulanTrickPlay play;
  final String label;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '$label played ${_rankName(play.card.rank)} of ${_suitName(play.card.suit)}',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 38,
          height: 49,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF2),
            borderRadius: BorderRadius.circular(6),
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
          width: 52,
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
