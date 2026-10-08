import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/core/match_session.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_game.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_model.dart';
import 'package:tap_tussle/games/lane_dash/lane_dash_view.dart';

void main() {
  test('assigns friend and difficulty-specific bot cars', () {
    final friendSession = MatchSession(options: MatchOptions.friend());
    final friendGame = LaneDashGame(friendSession);
    expect(friendGame.carSpriteForPlayer(0), 'car_blue');
    expect(friendGame.carSpriteForPlayer(1), 'car_red');
    friendGame.stopMatch();
    friendSession.dispose();

    const expected = {
      BotDifficulty.easy: 'car_green',
      BotDifficulty.normal: 'car_yellow',
      BotDifficulty.hard: 'car_purple',
    };
    for (final entry in expected.entries) {
      final session = MatchSession(
        options: MatchOptions.bot(difficulty: entry.key),
      );
      final game = LaneDashGame(session);
      expect(game.carSpriteForPlayer(0), 'car_blue');
      expect(game.carSpriteForPlayer(1), entry.value);
      game.stopMatch();
      session.dispose();
    }
  });

  test('maps every obstacle kind to a production sprite', () {
    final session = MatchSession(options: MatchOptions.friend());
    final game = LaneDashGame(session);

    expect(
      LaneObstacleKind.values.map(game.obstacleSpriteForKind).toSet().length,
      LaneObstacleKind.values.length,
    );

    game.stopMatch();
    session.dispose();
  });

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
    expect(tester.takeException(), isNull);

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
