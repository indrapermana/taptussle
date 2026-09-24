import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';
import 'package:tap_tussle/games/air_hockey/air_hockey_bot.dart';
import 'package:tap_tussle/games/air_hockey/air_hockey_model.dart';

void main() {
  test('difficulty changes how quickly the bot reacts', () {
    AirHockeyModel incomingModel() => AirHockeyModel(winningScore: 5)
      ..reset()
      ..puck = const Point(300, 220)
      ..velocity = const Point(-50, -300);

    final easyModel = incomingModel();
    final normalModel = incomingModel();
    final hardModel = incomingModel();
    final easy = AirHockeyBot(BotDifficulty.easy, random: Random(7));
    final normal = AirHockeyBot(BotDifficulty.normal, random: Random(7));
    final hard = AirHockeyBot(BotDifficulty.hard, random: Random(7));

    easy.update(easyModel, .11);
    normal.update(normalModel, .11);
    hard.update(hardModel, .11);

    expect(easyModel.targets[1], const Point<double>(180, 100));
    expect(normalModel.targets[1], const Point<double>(180, 100));
    expect(hardModel.targets[1], isNot(const Point<double>(180, 100)));

    normal.update(normalModel, .12);
    expect(normalModel.targets[1], isNot(const Point<double>(180, 100)));
    expect(easyModel.targets[1], const Point<double>(180, 100));

    easy.update(easyModel, .32);
    expect(easyModel.targets[1], isNot(const Point<double>(180, 100)));
  });

  test('bot targets remain inside the same legal half as a human mallet', () {
    final model = AirHockeyModel(winningScore: 5)..reset();
    final bot = AirHockeyBot(BotDifficulty.hard, random: Random(3));
    model.puck = const Point(350, 40);
    model.velocity = const Point(650, -500);

    for (var step = 0; step < 30; step++) {
      bot.update(model, .1);
      model.update(.1);
    }

    expect(
      model.mallets[1].x,
      inInclusiveRange(
        AirHockeyModel.malletRadius,
        AirHockeyModel.width - AirHockeyModel.malletRadius,
      ),
    );
    expect(
      model.mallets[1].y,
      inInclusiveRange(
        AirHockeyModel.malletRadius,
        AirHockeyModel.height / 2 - AirHockeyModel.malletRadius,
      ),
    );
  });
}
