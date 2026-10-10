import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  Timer? _captureEffectTimer;
  var _wasAnimating = false;
  late MatchPhase _observedPhase;

  @override
  void initState() {
    super.initState();
    _setGameOrientation(MatchPhase.playing);
    controller = MancalaController(
      session: widget.session,
      model: widget.initialModel,
    )..addListener(_playEffects);
    _observedModel = controller.model;
    _observedTurn = controller.model.lastTurn;
    _observedPhase = widget.session.phase;
    widget.session.addListener(_syncOrientation);
  }

  void _syncOrientation() {
    if (_observedPhase == widget.session.phase) return;
    _observedPhase = widget.session.phase;
    _setGameOrientation(_observedPhase);
  }

  void _setGameOrientation(MatchPhase phase) {
    final orientations = phase == MatchPhase.finished
        ? const [DeviceOrientation.portraitUp]
        : const [
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ];
    unawaited(SystemChrome.setPreferredOrientations(orientations));
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
      _captureEffectTimer?.cancel();
      _observedTurn = turn;
      SoundEffects.play(SoundEffect.collect);
      HapticEffects.preview();
    }
    if (_wasAnimating && !controller.isAnimating && turn != null) {
      if (turn.wasCapture) {
        _captureEffectTimer = Timer(const Duration(milliseconds: 250), () {
          if (!mounted) return;
          SoundEffects.play(SoundEffect.boardCapture);
          HapticEffects.paddleHit();
        });
      } else if (turn.extraTurn) {
        SoundEffects.play(SoundEffect.uiConfirm);
        HapticEffects.paddleHit();
      }
    }
    _wasAnimating = controller.isAnimating;
  }

  @override
  void dispose() {
    _captureEffectTimer?.cancel();
    widget.session.removeListener(_syncOrientation);
    unawaited(
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.portraitUp,
      ]),
    );
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
  static const _wood = Color(0xFF9A552F);
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
              padding: EdgeInsets.fromLTRB(6, compact ? 4 : 8, 6, 6),
              child: Column(
                children: [
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
                  SizedBox(height: compact ? 3 : 6),
                  Expanded(
                    child: DecoratedBox(
                      key: const ValueKey('mancala-play-board'),
                      decoration: BoxDecoration(
                        color: _wood,
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFD7904E), Color(0xFF8A4728)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: const Color(0xFF5D2D1C),
                          width: 5,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black54,
                            blurRadius: 20,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                compact ? 12 : 20,
                                compact ? 20 : 28,
                                compact ? 12 : 20,
                                compact ? 16 : 24,
                              ),
                              child: Row(
                                children: [
                                  _Store(
                                    key: const ValueKey('mancala-store-1'),
                                    label: playerLabels[1],
                                    player: 1,
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
                                                    player: 1,
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
                                                    player: 0,
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
                                    player: 0,
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
                          if (isAnimating && activePosition != null)
                            _MovingStone(position: activePosition!),
                        ],
                      ),
                    ),
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 7),
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

class _Pit extends StatelessWidget {
  const _Pit({
    required this.pit,
    required this.player,
    required this.label,
    required this.stones,
    required this.color,
    required this.legal,
    required this.active,
    required this.onTap,
    super.key,
  });

  final int pit;
  final int player;
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
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Semantics(
        label: semantics,
        button: true,
        enabled: legal,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: legal ? onTap : null,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: player == 1 ? 18 : 0,
                    bottom: player == 0 ? 18 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: legal ? .16 : .07),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: active
                            ? Colors.white
                            : legal
                            ? MancalaBoard._legal
                            : color.withValues(alpha: .72),
                        width: active
                            ? 4
                            : legal
                            ? 3
                            : 2,
                      ),
                      boxShadow: legal
                          ? [
                              BoxShadow(
                                color: MancalaBoard._legal.withValues(
                                  alpha: .42,
                                ),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: _StoneContents(stones: stones),
                  ),
                ),
                Positioned(
                  top: player == 1 ? 0 : null,
                  bottom: player == 0 ? 0 : null,
                  child: _StoneCount(stones: stones, color: color),
                ),
              ],
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
    required this.player,
    required this.stones,
    required this.color,
    required this.active,
    super.key,
  });

  final String label;
  final int player;
  final int stones;
  final Color color;
  final bool active;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      label: '$label store, $stones ${stones == 1 ? 'stone' : 'stones'}',
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: player == 1 ? 18 : 0,
                bottom: player == 0 ? 18 : 0,
              ),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(
                    color: active ? Colors.white : color,
                    width: active ? 4 : 3,
                  ),
                ),
                child: _StoneContents(stones: stones),
              ),
            ),
            Positioned(
              top: player == 1 ? 0 : null,
              bottom: player == 0 ? 0 : null,
              child: _StoneCount(stones: stones, color: color),
            ),
          ],
        ),
      ),
    ),
  );
}

class _StoneContents extends StatelessWidget {
  const _StoneContents({required this.stones});

  final int stones;

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
          child: const _MancalaStone(size: 15),
        ),
    ],
  );
}

class _StoneCount extends StatelessWidget {
  const _StoneCount({required this.stones, required this.color});

  final int stones;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    key: ValueKey('mancala-count-$stones'),
    constraints: const BoxConstraints(minWidth: 24, minHeight: 20),
    alignment: Alignment.center,
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    decoration: BoxDecoration(
      color: const Color(0xFF0C1724),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color, width: 2),
    ),
    child: Text(
      '$stones',
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w900,
        fontSize: 13,
      ),
    ),
  );
}

class _MovingStone extends StatelessWidget {
  const _MovingStone({required this.position});

  final int position;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedAlign(
      key: const ValueKey('mancala-moving-stone'),
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeInOutCubic,
      alignment: _alignmentForPosition(position),
      child: const _MancalaStone(size: 24, moving: true),
    ),
  );

  static Alignment _alignmentForPosition(int position) {
    if (position == MancalaModel.playerOneStore) {
      return const Alignment(.91, 0);
    }
    if (position == MancalaModel.playerTwoStore) {
      return const Alignment(-.91, 0);
    }
    if (position < MancalaModel.playerOneStore) {
      return Alignment(-.65 + position * .26, .43);
    }
    return Alignment(.65 - (position - 7) * .26, -.43);
  }
}

class _MancalaStone extends StatelessWidget {
  const _MancalaStone({required this.size, this.moving = false});

  final double size;
  final bool moving;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(
          color: moving ? Colors.white70 : Colors.black45,
          blurRadius: moving ? 10 : 3,
          offset: Offset(0, moving ? 0 : 2),
        ),
      ],
    ),
    child: Image.asset(
      'assets/games/mancala/stone.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    ),
  );
}
