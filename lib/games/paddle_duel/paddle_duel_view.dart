import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/match_session.dart';
import 'paddle_duel_game.dart';
import 'paddle_duel_model.dart';

class PaddleDuelView extends StatefulWidget {
  const PaddleDuelView({
    required this.session,
    required this.winningScore,
    super.key,
  });
  final MatchSession session;
  final int winningScore;
  @override
  State<PaddleDuelView> createState() => _PaddleDuelViewState();
}

class _PaddleDuelViewState extends State<PaddleDuelView> {
  late final PaddleDuelGame game;
  final Map<int, int> pointers = {};
  int round = 0;

  @override
  void initState() {
    super.initState();
    game = PaddleDuelGame(
      session: widget.session,
      winningScore: widget.winningScore,
    );
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    if (round != widget.session.round) {
      round = widget.session.round;
      pointers.clear();
      game.model.reset();
    }
    if (widget.session.phase == MatchPhase.playing) {
      game.resumeEngine();
    } else {
      pointers.clear();
      game.pauseEngine();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: AspectRatio(
      aspectRatio: PaddleDuelModel.width / PaddleDuelModel.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          void move(int pointer, Offset position) {
            final player = pointers[pointer];
            if (player == null || widget.session.phase != MatchPhase.playing) {
              return;
            }
            game.model.movePaddle(
              player,
              position.dx / constraints.maxWidth * PaddleDuelModel.width,
            );
          }

          return Listener(
            key: const ValueKey('paddle-court'),
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (widget.session.phase != MatchPhase.playing) return;
              final player = event.localPosition.dy < constraints.maxHeight / 2
                  ? 1
                  : 0;
              // A finger stays assigned to its starting side until release.
              if (pointers.containsValue(player)) return;
              pointers[event.pointer] = player;
              move(event.pointer, event.localPosition);
            },
            onPointerMove: (event) => move(event.pointer, event.localPosition),
            onPointerUp: (event) => pointers.remove(event.pointer),
            onPointerCancel: (event) => pointers.remove(event.pointer),
            child: GameWidget<PaddleDuelGame>(game: game),
          );
        },
      ),
    ),
  );
}
