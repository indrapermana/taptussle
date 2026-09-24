import 'package:flutter/foundation.dart';

import 'match_options.dart';

enum MatchPhase { ready, playing, paused, finished }

/// Engine-independent lifecycle. Games publish scores and results;
/// the Flutter shell owns navigation and lifecycle controls.
class MatchSession extends ChangeNotifier {
  MatchSession({this.options = const MatchOptions.friend()});

  final MatchOptions options;
  MatchPhase get phase => _phase;
  MatchPhase _phase = MatchPhase.ready;
  int get round => _round;
  int _round = 0;
  List<int> get scores => _scores;
  List<int> _scores = const [0, 0];
  int? get winner => _winner;
  int? _winner;

  void start() {
    if (_phase != MatchPhase.ready && _phase != MatchPhase.finished) return;
    _round++;
    _scores = const [0, 0];
    _winner = null;
    _phase = MatchPhase.playing;
    notifyListeners();
  }

  void pause() {
    if (_phase != MatchPhase.playing) return;
    _phase = MatchPhase.paused;
    notifyListeners();
  }

  void resume() {
    if (_phase != MatchPhase.paused) return;
    _phase = MatchPhase.playing;
    notifyListeners();
  }

  void reportScore(int playerOne, int playerTwo, {int? winner}) {
    if (_phase != MatchPhase.playing) return;
    assert(playerOne >= 0 && playerTwo >= 0);
    assert(winner == null || winner == 0 || winner == 1);
    _scores = List.unmodifiable([playerOne, playerTwo]);
    _winner = winner;
    if (winner != null) _phase = MatchPhase.finished;
    notifyListeners();
  }
}
