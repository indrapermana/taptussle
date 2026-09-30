import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/haptic_service.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../core/sound_service.dart';
import 'mancala_controller.dart';
import 'mancala_model.dart';

class MancalaView extends StatefulWidget {
  const MancalaView({
    required this.session,
    required this.options,
    this.initialModel,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final MancalaModel? initialModel;

  @override
  State<MancalaView> createState() => _MancalaViewState();
}

class _MancalaViewState extends State<MancalaView> {
  late final MancalaController controller;
  late MancalaModel _observedModel;
  MancalaTurn? _observedTurn;
  var _wasAnimating = false;

  @override
  void initState() {
    super.initState();
    controller = MancalaController(
      session: widget.session,
      model: widget.initialModel,
    )..addListener(_playEffects);
    _observedModel = controller.model;
    _observedTurn = controller.model.lastTurn;
  }

  void _playEffects() {
    if (!identical(_observedModel, controller.model)) {
      _observedModel = controller.model;
      _observedTurn = controller.model.lastTurn;
      _wasAnimating = controller.isAnimating;
      return;
    }

    final turn = controller.model.lastTurn;
    if (!identical(turn, _observedTurn) && controller.isAnimating) {
      _observedTurn = turn;
      SoundEffects.play(SoundEffect.collect);
      HapticEffects.preview();
    }
    if (_wasAnimating && !controller.isAnimating && turn != null) {
      if (turn.wasCapture) {
        SoundEffects.play(SoundEffect.boardCapture);
        HapticEffects.paddleHit();
      } else if (turn.extraTurn) {
        SoundEffects.play(SoundEffect.uiConfirm);
        HapticEffects.paddleHit();
      }
    }
    _wasAnimating = controller.isAnimating;
  }

  @override
  void dispose() {
    controller.removeListener(_playEffects);
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => MancalaBoard(
      model: controller.model,
      displayedBoard: controller.displayBoard,
      activePosition: controller.activePosition,
      isAnimating: controller.isAnimating,
      enabled: controller.acceptsInput,
      statusOverride: controller.isBotThinking ? 'BOT IS THINKING…' : null,
      playerLabels: [
        widget.options.playerLabel(0),
        widget.options.playerLabel(1),
      ],
      controller: controller,
      onPitTap: controller.tapPit,
    ),
  );
}

/// Responsive and accessible presentation for a two-player Kalah position.
class MancalaBoard extends StatelessWidget {
  const MancalaBoard({
    required this.model,
    required this.onPitTap,
    this.displayedBoard,
    this.activePosition,
    this.isAnimating = false,
    this.enabled = true,
    this.statusOverride,
    this.playerLabels = const ['Player 1', 'Player 2'],
    this.controller,
    super.key,
  }) : assert(playerLabels.length == 2);

  final MancalaModel model;
  final List<int>? displayedBoard;
  final int? activePosition;
  final bool isAnimating;
  final bool enabled;
  final String? statusOverride;
  final List<String> playerLabels;
  final MancalaController? controller;
  final MancalaTapResult Function(int player, int pit) onPitTap;

  static const playerOneColor = Color(0xFFFF7043);
  static const playerTwoColor = Color(0xFF36C5F0);
  static const _woodDark = Color(0xFF4A2515);
  static const _wood = Color(0xFF9A552F);
  static const _pit = Color(0xFF24150F);
  static const _legal = Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    final board = displayedBoard ?? model.board;
    final legalPits = enabled
        ? model.legalPitsFor(model.currentPlayer).toSet()
        : const <int>{};
    final status = statusOverride ?? _statusText();

    return ColoredBox(
      color: const Color(0xFF0C1724),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 610;
            return Padding(
              padding: EdgeInsets.fromLTRB(12, compact ? 8 : 18, 12, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlayerStoreBadge(
                          label: playerLabels[0],
                          stones: board[MancalaModel.playerOneStore],
                          color: playerOneColor,
                          active: !model.isFinished && model.currentPlayer == 0,
                          winner: model.winner == 0,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PlayerStoreBadge(
                          label: playerLabels[1],
                          stones: board[MancalaModel.playerTwoStore],
                          color: playerTwoColor,
                          active: !model.isFinished && model.currentPlayer == 1,
                          winner: model.winner == 1,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      status,
                      key: ValueKey(status),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        color: _statusColor(),
                        fontSize: compact ? 15 : 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: .8,
                      ),
                    ),
                  ),
                  SizedBox(height: compact ? 8 : 14),
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: AspectRatio(
                          aspectRatio: 1.75,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [Color(0xFFB96A3B), _wood],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(color: _woodDark, width: 5),
                              boxShadow: const [
                                BoxShadow(
                                  color: Colors.black54,
                                  blurRadius: 20,
                                  offset: Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(compact ? 7 : 11),
                              child: Row(
                                children: [
                                  _Store(
                                    key: const ValueKey('mancala-store-1'),
                                    label: playerLabels[1],
                                    stones: board[MancalaModel.playerTwoStore],
                                    color: playerTwoColor,
                                    active:
                                        activePosition ==
                                        MancalaModel.playerTwoStore,
                                  ),
                                  const SizedBox(width: 7),
                                  Expanded(
                                    flex: 6,
                                    child: Column(
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              for (var pit = 5; pit >= 0; pit--)
                                                Expanded(
                                                  child: _Pit(
                                                    key: ValueKey(
                                                      'mancala-pit-1-$pit',
                                                    ),
                                                    pit: pit,
                                                    label: playerLabels[1],
                                                    stones:
                                                        board[model
                                                            .boardPositionForPit(
                                                              1,
                                                              pit,
                                                            )],
                                                    color: playerTwoColor,
                                                    legal:
                                                        model.currentPlayer ==
                                                            1 &&
                                                        legalPits.contains(pit),
                                                    active:
                                                        activePosition ==
                                                        model
                                                            .boardPositionForPit(
                                                              1,
                                                              pit,
                                                            ),
                                                    onTap: () =>
                                                        onPitTap(1, pit),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 7),
                                        Expanded(
                                          child: Row(
                                            children: [
                                              for (var pit = 0; pit < 6; pit++)
                                                Expanded(
                                                  child: _Pit(
                                                    key: ValueKey(
                                                      'mancala-pit-0-$pit',
                                                    ),
                                                    pit: pit,
                                                    label: playerLabels[0],
                                                    stones:
                                                        board[model
                                                            .boardPositionForPit(
                                                              0,
                                                              pit,
                                                            )],
                                                    color: playerOneColor,
                                                    legal:
                                                        model.currentPlayer ==
                                                            0 &&
                                                        legalPits.contains(pit),
                                                    active:
                                                        activePosition ==
                                                        model
                                                            .boardPositionForPit(
                                                              0,
                                                              pit,
                                                            ),
                                                    onTap: () =>
                                                        onPitTap(0, pit),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 7),
                                  _Store(
                                    key: const ValueKey('mancala-store-0'),
                                    label: playerLabels[0],
                                    stones: board[MancalaModel.playerOneStore],
                                    color: playerOneColor,
                                    active:
                                        activePosition ==
                                        MancalaModel.playerOneStore,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Choose a glowing pit on your side',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _statusText() {
    if (model.isDraw) return 'DRAW • STORES ARE EVEN';
    if (model.winner case final winner?) {
      return '${playerLabels[winner].toUpperCase()} WINS';
    }
    if (isAnimating) {
      final player = model.lastTurn?.player ?? model.currentPlayer;
      return '${playerLabels[player].toUpperCase()} • SOWING…';
    }
    if (model.lastTurn?.extraTurn ?? false) {
      return '${playerLabels[model.currentPlayer].toUpperCase()} • EXTRA TURN';
    }
    return '${playerLabels[model.currentPlayer].toUpperCase()}\'S TURN';
  }

  Color _statusColor() {
    if (model.isDraw) return Colors.white;
    final player =
        model.winner ??
        (isAnimating ? model.lastTurn?.player : null) ??
        model.currentPlayer;
    return player == 0 ? playerOneColor : playerTwoColor;
  }
}

class _PlayerStoreBadge extends StatelessWidget {
  const _PlayerStoreBadge({
    required this.label,
    required this.stones,
    required this.color,
    required this.active,
    required this.winner,
  });

  final String label;
  final int stones;
  final Color color;
  final bool active;
  final bool winner;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(
      color: active || winner
          ? color.withValues(alpha: .16)
          : const Color(0xFF182A3A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: active || winner ? color : const Color(0xFF304253),
        width: active || winner ? 2 : 1,
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(width: 7),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '$stones IN STORE',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _Pit extends StatelessWidget {
  const _Pit({
    required this.pit,
    required this.label,
    required this.stones,
    required this.color,
    required this.legal,
    required this.active,
    required this.onTap,
    super.key,
  });

  final int pit;
  final String label;
  final int stones;
  final Color color;
  final bool legal;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final semantics =
        '$label pit ${pit + 1}, $stones '
        '${stones == 1 ? 'stone' : 'stones'}${legal ? ', legal move' : ''}';
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Semantics(
        label: semantics,
        button: true,
        enabled: legal,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: legal ? onTap : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                color: MancalaBoard._pit,
                shape: BoxShape.circle,
                border: Border.all(
                  color: active
                      ? Colors.white
                      : legal
                      ? MancalaBoard._legal
                      : color.withValues(alpha: .45),
                  width: active
                      ? 4
                      : legal
                      ? 3
                      : 1.5,
                ),
                boxShadow: legal
                    ? [
                        BoxShadow(
                          color: MancalaBoard._legal.withValues(alpha: .35),
                          blurRadius: 9,
                        ),
                      ]
                    : null,
              ),
              child: _StoneContents(stones: stones, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

class _Store extends StatelessWidget {
  const _Store({
    required this.label,
    required this.stones,
    required this.color,
    required this.active,
    super.key,
  });

  final String label;
  final int stones;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label store, $stones ${stones == 1 ? 'stone' : 'stones'}',
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          decoration: BoxDecoration(
            color: MancalaBoard._pit,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: active ? Colors.white : color.withValues(alpha: .75),
              width: active ? 4 : 2,
            ),
          ),
          child: _StoneContents(stones: stones, color: color),
        ),
      ),
    ),
  );
}

class _StoneContents extends StatelessWidget {
  const _StoneContents({required this.stones, required this.color});

  final int stones;
  final Color color;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      for (var index = 0; index < math.min(stones, 7); index++)
        Align(
          alignment: Alignment(
            math.cos(index * 2.4) * .48,
            math.sin(index * 2.4) * .48,
          ),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: index.isEven ? color : const Color(0xFFFFD54F),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white70, width: .7),
            ),
          ),
        ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .72),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$stones',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    ],
  );
}
