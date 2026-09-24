import 'package:flutter/foundation.dart';

import 'match_options.dart';

enum MatchPhase { ready, playing, paused, finished }

enum MatchOutcome { winner, draw }

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
  MatchOutcome? get outcome => _outcome;
  MatchOutcome? _outcome;
  String? get resultDetails => _resultDetails;
  String? _resultDetails;

  void start() {
    if (_phase != MatchPhase.ready && _phase != MatchPhase.finished) return;
    _round++;
    _scores = const [0, 0];
    _winner = null;
    _outcome = null;
    _resultDetails = null;
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
    if (winner != null) {
      _outcome = MatchOutcome.winner;
      _phase = MatchPhase.finished;
    }
    notifyListeners();
  }

  void reportDraw(int playerOne, int playerTwo) {
    if (_phase != MatchPhase.playing) return;
    _scores = List.unmodifiable([playerOne, playerTwo]);
    _winner = null;
    _outcome = MatchOutcome.draw;
    _phase = MatchPhase.finished;
    notifyListeners();
  }

  /// Completes a race or other result that is not a point score.
  void reportNonPointResult({
    required int? winner,
    required String details,
    List<int> scores = const [0, 0],
  }) {
    if (_phase != MatchPhase.playing) return;
    _scores = List.unmodifiable(scores);
    _winner = winner;
    _outcome = winner == null ? MatchOutcome.draw : MatchOutcome.winner;
    _resultDetails = details;
    _phase = MatchPhase.finished;
    notifyListeners();
  }
}
