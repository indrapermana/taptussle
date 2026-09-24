import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'air_hockey_game.dart';

class AirHockeyView extends StatefulWidget {
  const AirHockeyView({
    required this.session,
    required this.options,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;

  @override
  State<AirHockeyView> createState() => _AirHockeyViewState();
}

class _AirHockeyViewState extends State<AirHockeyView> {
  late final AirHockeyGame game;
  final pointers = <int, int>{};
  int _round = -1;

  @override
  void initState() {
    super.initState();
    game = AirHockeyGame(widget.session);
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      pointers.clear();
      game.resetMatch();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    game.stopMatch();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.min(constraints.maxWidth, constraints.maxHeight * .6);
      final left = (constraints.maxWidth - width) / 2;
      void move(int pointer, Offset position) {
        final player = pointers[pointer];
        if (player == null) return;
        game.model.moveMallet(
          player,
          (position.dx - left) / width * 360,
          position.dy / constraints.maxHeight * 600,
        );
      }

      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (widget.session.phase != MatchPhase.playing) return;
          final player = event.localPosition.dy < constraints.maxHeight / 2
              ? 1
              : 0;
          if (widget.options.mode == PlayMode.bot && player == 1) return;
          if (pointers.containsValue(player)) return;
          pointers[event.pointer] = player;
          move(event.pointer, event.localPosition);
        },
        onPointerMove: (event) => move(event.pointer, event.localPosition),
        onPointerUp: (event) => pointers.remove(event.pointer),
        onPointerCancel: (event) => pointers.remove(event.pointer),
        child: Center(
          child: AspectRatio(aspectRatio: .6, child: GameWidget(game: game)),
        ),
      );
    },
  );
}
