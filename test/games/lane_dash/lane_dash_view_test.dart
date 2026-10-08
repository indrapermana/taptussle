import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_game.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_view.dart';

void main() {
  testWidgets('both players move in the same screen direction as their swipe', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(const Offset(180, 450), const Offset(-80, 0));
    expect(game.model.lanes[0], 0, reason: 'Player 1 swiped left');
    game.model.lanes[0] = 1;
    await tester.dragFrom(const Offset(180, 450), const Offset(80, 0));
    expect(game.model.lanes[0], 2, reason: 'Player 1 swiped right');

    await tester.dragFrom(const Offset(180, 150), const Offset(-80, 0));
    expect(game.model.lanes[1], 0, reason: 'Player 2 swiped left');
    game.model.lanes[1] = 1;
    await tester.dragFrom(const Offset(180, 150), const Offset(80, 0));
    expect(game.model.lanes[1], 2, reason: 'Player 2 swiped right');
  });

  testWidgets('short and mostly vertical gestures do not change lanes', (
    tester,
  ) async {
    final session = MatchSession(options: MatchOptions.friend())..start();
    addTearDown(session.dispose);
    final game = LaneDashGame(session);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 360,
            height: 600,
            child: LaneDashView(
              session: session,
              options: session.options,
              gameOverride: game,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.dragFrom(const Offset(180, 450), const Offset(20, 0));
    await tester.dragFrom(const Offset(180, 150), const Offset(30, 90));

    expect(game.model.lanes, [1, 1]);
  });
}
