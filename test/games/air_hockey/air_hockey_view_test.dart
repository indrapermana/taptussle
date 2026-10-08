import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/air_hockey/air_hockey_view.dart';

void main() {
  testWidgets('production sprites load and the rink accepts player input', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend(winningScore: 5))
      ..start();
    addTearDown(session.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: AirHockeyView(session: session, options: session.options),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tapAt(const Offset(180, 500));
    await tester.pump(const Duration(milliseconds: 100));

    expect(session.phase, MatchPhase.playing);
    expect(tester.takeException(), isNull);
  });
}
