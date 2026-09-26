import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';

MatchOptions fourPlayerOptions() => MatchOptions.custom(
  mode: PlayMode.friend,
  participants: const [
    MatchParticipant.human(
      displayName: 'One',
      color: ParticipantColor.mint,
      token: ParticipantToken.circle,
    ),
    MatchParticipant.human(
      displayName: 'Two',
      color: ParticipantColor.coral,
      token: ParticipantToken.diamond,
    ),
    MatchParticipant.human(
      displayName: 'Three',
      color: ParticipantColor.gold,
      token: ParticipantToken.triangle,
    ),
    MatchParticipant.human(
      displayName: 'Four',
      color: ParticipantColor.violet,
      token: ParticipantToken.star,
    ),
  ],
);

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

  test('four-player scores can finish with any configured winner', () {
    final session = MatchSession(options: fourPlayerOptions());
    addTearDown(session.dispose);

    expect(session.scores, [0, 0, 0, 0]);
    session.start();
    session.reportScores([2, 4, 1, 3]);
    expect(session.scores, [2, 4, 1, 3]);
    session.reportScores([2, 4, 1, 5], winner: 3);

    expect(session.phase, MatchPhase.finished);
    expect(session.outcome, MatchOutcome.winner);
    expect(session.winner, 3);
    expect(session.scores, [2, 4, 1, 5]);
    expect(() => session.scores.add(9), throwsUnsupportedError);

    session.start();
    expect(session.scores, [0, 0, 0, 0]);
    expect(session.outcome, isNull);
    expect(session.standings, isEmpty);
  });

  test('draw and winnerless completion are explicit distinct outcomes', () {
    final session = MatchSession(options: fourPlayerOptions());
    addTearDown(session.dispose);
    session.start();
    session.reportDrawScores([
      8,
      8,
      4,
      2,
    ], details: 'One and Two share the lead.');
    expect(session.outcome, MatchOutcome.draw);
    expect(session.winner, isNull);
    expect(session.resultDetails, 'One and Two share the lead.');

    session.start();
    session.reportCompletion(
      scores: [12, 10, 8, 6],
      standings: [0, 1, 2, 3],
      details: 'All players reached the finish.',
    );
    expect(session.outcome, MatchOutcome.completed);
    expect(session.winner, isNull);
    expect(session.standings, [0, 1, 2, 3]);
    expect(() => session.standings.add(0), throwsUnsupportedError);
  });

  test('multi-player results validate score and standing indexes', () {
    final session = MatchSession(options: fourPlayerOptions())..start();
    addTearDown(session.dispose);

    expect(() => session.reportScores([1, 2]), throwsArgumentError);
    expect(
      () => session.reportScores([1, 2, 3, 4], winner: 4),
      throwsArgumentError,
    );
    expect(
      () => session.reportCompletion(
        scores: [1, 2, 3, 4],
        standings: [0, 1, 1, 3],
      ),
      throwsArgumentError,
    );
  });
}
