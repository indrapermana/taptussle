import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../../core/match_options.dart';
import '../../core/match_session.dart';
import 'slither_challenge_profile.dart';
import 'slither_simulation.dart';
import 'slither_snakes_game.dart';

class SlitherSnakesView extends StatefulWidget {
  const SlitherSnakesView({
    required this.session,
    required this.options,
    this.initialSimulation,
    super.key,
  });

  final MatchSession session;
  final MatchOptions options;
  final SlitherSimulation? initialSimulation;

  @override
  State<SlitherSnakesView> createState() => _SlitherSnakesViewState();
}

class _SlitherSnakesViewState extends State<SlitherSnakesView> {
  late final SlitherSnakesGame game;
  final Set<int> _steeringPointers = {};
  var _round = -1;

  @override
  void initState() {
    super.initState();
    final profile = SlitherChallengeProfile.forDifficulty(
      widget.options.difficulty,
    );
    game = SlitherSnakesGame(
      session: widget.session,
      config: profile.config,
      simulation: widget.initialSimulation,
    );
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    if (_round != widget.session.round) {
      _round = widget.session.round;
      _steeringPointers.clear();
      if (_round > 1 || widget.initialSimulation == null) {
        game.reset(round: _round);
      }
    }
    if (widget.session.phase != MatchPhase.playing) {
      _steeringPointers.clear();
      game.clearSteering();
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
    builder: (context, _) {
      void steer(PointerEvent event) {
        if (!_steeringPointers.contains(event.pointer) ||
            widget.session.phase != MatchPhase.playing) {
          return;
        }
        game.steerFromScreen(event.localPosition);
      }

      return Stack(
        fit: StackFit.expand,
        children: [
          GameWidget(game: game),
          Semantics(
            container: true,
            label: 'Slither snake arena',
            hint: 'Drag anywhere on the arena to steer your snake',
            child: Listener(
              key: const ValueKey('slither-steering-surface'),
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (widget.session.phase != MatchPhase.playing) return;
                _steeringPointers.add(event.pointer);
                steer(event);
              },
              onPointerMove: steer,
              onPointerUp: (event) {
                _steeringPointers.remove(event.pointer);
                if (_steeringPointers.isEmpty) game.clearSteering();
              },
              onPointerCancel: (event) {
                _steeringPointers.remove(event.pointer);
                if (_steeringPointers.isEmpty) game.clearSteering();
              },
              child: const SizedBox.expand(),
            ),
          ),
          const Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: IgnorePointer(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 72),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'DRAG ANYWHERE TO STEER',
                    key: ValueKey('slither-steering-instruction'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0x99FFFFFF),
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
