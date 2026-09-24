import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/games/air_hockey/air_hockey_model.dart';

void main() {
  test('winning goal is counted exactly once during a fixed-step update', () {
    final model = AirHockeyModel(winningScore: 5)..reset();
    model.scores[0] = 4;
    model.puck = const Point(180, -13);
    model.velocity = const Point(0, -300);

    model.update(.1);

    expect(model.scores, [5, 0]);
    expect(model.winner, 0);
  });
}
