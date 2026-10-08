import 'dart:async';
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
  late List<int> _scores;
  Timer? _scoreNoticeTimer;
  int? _scoringParticipant;
  int _round = -1;

  @override
  void initState() {
    super.initState();
    game = AirHockeyGame(widget.session);
    _scores = List.of(widget.session.scores);
    widget.session.addListener(_syncSession);
    _syncSession();
  }

  void _syncSession() {
    final nextScores = widget.session.scores;
    if (nextScores.length >= 2 && _scores.length >= 2) {
      final scorer = nextScores[0] > _scores[0]
          ? 0
          : nextScores[1] > _scores[1]
          ? 1
          : null;
      if (scorer != null && widget.session.phase == MatchPhase.playing) {
        pointers.clear();
        _scoreNoticeTimer?.cancel();
        if (mounted) setState(() => _scoringParticipant = scorer);
        _scoreNoticeTimer = Timer(const Duration(seconds: 2), () {
          if (mounted) setState(() => _scoringParticipant = null);
        });
      }
    }
    _scores = List.of(nextScores);
    if (_round != widget.session.round) {
      _round = widget.session.round;
      pointers.clear();
      _scoreNoticeTimer?.cancel();
      _scoringParticipant = null;
      game.resetMatch();
    }
    if (widget.session.phase != MatchPhase.playing) pointers.clear();
  }

  @override
  void dispose() {
    widget.session.removeListener(_syncSession);
    _scoreNoticeTimer?.cancel();
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
        if (player == null ||
            widget.session.phase != MatchPhase.playing ||
            _scoringParticipant != null) {
          return;
        }
        game.model.moveMallet(
          player,
          (position.dx - left) / width * 360,
          position.dy / constraints.maxHeight * 600,
        );
      }

      return Listener(
        key: const ValueKey('air-hockey-court'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (widget.session.phase != MatchPhase.playing ||
              _scoringParticipant != null) {
            return;
          }
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
          child: AspectRatio(
            aspectRatio: .6,
            child: Stack(
              fit: StackFit.expand,
              children: [
                GameWidget(game: game),
                if (_scoringParticipant case final scorer?)
                  _AirHockeyScoreAnnouncement(
                    participantName: widget.options.playerLabel(scorer),
                    score: widget.session.scores[scorer],
                    color: scorer == 0
                        ? const Color(0xFF29C9FF)
                        : const Color(0xFFFF7043),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _AirHockeyScoreAnnouncement extends StatelessWidget {
  const _AirHockeyScoreAnnouncement({
    required this.participantName,
    required this.score,
    required this.color,
  });

  final String participantName;
  final int score;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    key: const ValueKey('air-hockey-score-announcement'),
    container: true,
    liveRegion: true,
    label: '$participantName scored. Score $score.',
    excludeSemantics: true,
    child: IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xD9061129),
          border: Border.symmetric(
            horizontal: BorderSide(color: color, width: 3),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            Opacity(
              opacity: .55,
              child: Image.asset(
                'assets/games/air_hockey/goal_flash.png',
                fit: BoxFit.contain,
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    participantName.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Lilita One',
                      fontSize: 28,
                      letterSpacing: 1.2,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                  const Text(
                    'SCORES!',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Lilita One',
                      fontSize: 36,
                      letterSpacing: 1.5,
                      shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                    ),
                  ),
                  Text(
                    '$score',
                    style: TextStyle(
                      color: color,
                      fontFamily: 'Lilita One',
                      fontSize: 32,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
