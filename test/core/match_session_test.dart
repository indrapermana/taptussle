import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_session.dart';

void main() {
  test('pause preserves progress, finish freezes score, rematch resets', () {
    final session = MatchSession();
    addTearDown(session.dispose);
    session.reportScore(10, 1);
    expect(session.scores, [0, 0]);
    session.start();
    session.reportScore(3, 2);
    session.pause();
    session.reportScore(4, 2);
    expect(session.scores, [3, 2]);
    session.start();
    expect(session.phase, MatchPhase.paused);
    session.resume();
    session.reportScore(7, 2, winner: 0);
    expect(session.phase, MatchPhase.finished);
    expect(session.winner, 0);
    session.reportScore(8, 2);
    expect(session.scores, [7, 2]);
    session.start();
    expect(session.round, 2);
    expect(session.phase, MatchPhase.playing);
    expect(session.scores, [0, 0]);
    expect(session.winner, isNull);
  });
}
