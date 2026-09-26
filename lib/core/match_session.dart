import 'package:flutter/foundation.dart';

import 'match_options.dart';

enum MatchPhase { ready, playing, paused, finished }

enum MatchOutcome { winner, draw, completed }

/// Engine-independent lifecycle. Games publish scores and results;
/// the Flutter shell owns navigation and lifecycle controls.
class MatchSession extends ChangeNotifier {
  MatchSession({MatchOptions? options})
    : options = options ?? MatchOptions.friend();

  final MatchOptions options;
  MatchPhase get phase => _phase;
  MatchPhase _phase = MatchPhase.ready;
  int get round => _round;
  int _round = 0;
  List<int> get scores => _scores;
  late List<int> _scores = _emptyScores();
  int? get winner => _winner;
  int? _winner;
  MatchOutcome? get outcome => _outcome;
  MatchOutcome? _outcome;
  List<int> get standings => _standings;
  List<int> _standings = const [];
  String? get resultDetails => _resultDetails;
  String? _resultDetails;

  List<int> _emptyScores() =>
      List<int>.unmodifiable(List<int>.filled(options.participants.length, 0));

  void start() {
    if (_phase != MatchPhase.ready && _phase != MatchPhase.finished) return;
    _round++;
    _scores = _emptyScores();
    _winner = null;
    _outcome = null;
    _standings = const [];
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
    reportScores([playerOne, playerTwo], winner: winner);
  }

  /// Publishes participant-ordered scores and optionally finishes with a winner.
  void reportScores(List<int> scores, {int? winner}) {
    if (_phase != MatchPhase.playing) return;
    if (winner == null) {
      _scores = _validateScores(scores);
      notifyListeners();
      return;
    }
    reportResult(outcome: MatchOutcome.winner, scores: scores, winner: winner);
  }

  void reportDraw(int playerOne, int playerTwo) {
    reportDrawScores([playerOne, playerTwo]);
  }

  void reportDrawScores(
    List<int> scores, {
    String? details,
    List<int> standings = const [],
  }) {
    reportResult(
      outcome: MatchOutcome.draw,
      scores: scores,
      details: details,
      standings: standings,
    );
  }

  /// Finishes an activity successfully without declaring a winner.
  void reportCompletion({
    String? details,
    List<int>? scores,
    List<int> standings = const [],
  }) {
    reportResult(
      outcome: MatchOutcome.completed,
      scores: scores ?? _scores,
      details: details,
      standings: standings,
    );
  }

  void reportResult({
    required MatchOutcome outcome,
    required List<int> scores,
    int? winner,
    String? details,
    List<int> standings = const [],
  }) {
    if (_phase != MatchPhase.playing) return;
    if (outcome == MatchOutcome.winner) {
      if (winner == null ||
          winner < 0 ||
          winner >= options.participants.length) {
        throw ArgumentError.value(
          winner,
          'winner',
          'Winner must identify a configured participant',
        );
      }
    } else if (winner != null) {
      throw ArgumentError.value(
        winner,
        'winner',
        'Only a winner outcome can identify a winner',
      );
    }
    final nextScores = _validateScores(scores);
    final nextStandings = _validateStandings(standings);
    _scores = nextScores;
    _standings = nextStandings;
    _winner = winner;
    _outcome = outcome;
    _resultDetails = details;
    _phase = MatchPhase.finished;
    notifyListeners();
  }

  /// Completes a race or other result that is not a point score.
  void reportNonPointResult({
    required int? winner,
    required String details,
    List<int>? scores,
    List<int> standings = const [],
  }) {
    reportResult(
      outcome: winner == null ? MatchOutcome.draw : MatchOutcome.winner,
      scores: scores ?? _emptyScores(),
      winner: winner,
      details: details,
      standings: standings,
    );
  }

  List<int> _validateScores(List<int> scores) {
    if (scores.length != options.participants.length ||
        scores.any((score) => score < 0)) {
      throw ArgumentError.value(
        scores,
        'scores',
        'Provide one non-negative score per participant',
      );
    }
    return List<int>.unmodifiable(scores);
  }

  List<int> _validateStandings(List<int> standings) {
    if (standings.isEmpty) return const [];
    final participants = options.participants.length;
    if (standings.length != participants ||
        standings.toSet().length != participants ||
        standings.any((index) => index < 0 || index >= participants)) {
      throw ArgumentError.value(
        standings,
        'standings',
        'Standings must contain every participant index exactly once',
      );
    }
    return List<int>.unmodifiable(standings);
  }
}
