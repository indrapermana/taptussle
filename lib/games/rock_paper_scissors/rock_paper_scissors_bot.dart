import 'dart:math';

import '../../core/match_options.dart';
import 'rock_paper_scissors_model.dart';

/// Chooses from completed-round history only.
///
/// The current human choice is intentionally absent from [chooseChoice], so a
/// delayed bot cannot inspect it while it is waiting.
class RockPaperScissorsBot {
  RockPaperScissorsBot({required this.difficulty, Random? random})
    : _random = random ?? Random();

  final BotDifficulty difficulty;
  final Random _random;
  final List<RockPaperScissorsChoice> _humanHistory = [];

  List<RockPaperScissorsChoice> get humanHistory =>
      List.unmodifiable(_humanHistory);

  void observeCompletedRound(RockPaperScissorsChoice humanChoice) {
    _humanHistory.add(humanChoice);
  }

  void reset() => _humanHistory.clear();

  RockPaperScissorsChoice chooseChoice() => switch (difficulty) {
    BotDifficulty.easy => _randomChoice(),
    BotDifficulty.normal => _normalChoice(),
    BotDifficulty.hard => _hardChoice(),
  };

  RockPaperScissorsChoice _normalChoice() {
    if (_humanHistory.isEmpty || _random.nextDouble() >= .65) {
      return _randomChoice();
    }
    return counterFor(_mostFrequent(_humanHistory));
  }

  RockPaperScissorsChoice _hardChoice() {
    if (_humanHistory.isEmpty) return _randomChoice();
    final lastChoice = _humanHistory.last;
    final choicesAfterLast = <RockPaperScissorsChoice>[];
    for (var index = 0; index < _humanHistory.length - 1; index++) {
      if (_humanHistory[index] == lastChoice) {
        choicesAfterLast.add(_humanHistory[index + 1]);
      }
    }
    final prediction = choicesAfterLast.isEmpty
        ? _mostFrequent(_humanHistory)
        : _mostFrequent(choicesAfterLast);
    return counterFor(prediction);
  }

  RockPaperScissorsChoice _mostFrequent(List<RockPaperScissorsChoice> choices) {
    final counts = {
      for (final choice in RockPaperScissorsChoice.values) choice: 0,
    };
    for (final choice in choices) {
      counts[choice] = counts[choice]! + 1;
    }
    var best = RockPaperScissorsChoice.values.first;
    for (final choice in RockPaperScissorsChoice.values) {
      if (counts[choice]! > counts[best]!) best = choice;
    }
    return best;
  }

  RockPaperScissorsChoice _randomChoice() =>
      RockPaperScissorsChoice.values[_random.nextInt(
        RockPaperScissorsChoice.values.length,
      )];

  static RockPaperScissorsChoice counterFor(RockPaperScissorsChoice choice) =>
      switch (choice) {
        RockPaperScissorsChoice.rock => RockPaperScissorsChoice.paper,
        RockPaperScissorsChoice.paper => RockPaperScissorsChoice.scissors,
        RockPaperScissorsChoice.scissors => RockPaperScissorsChoice.rock,
      };
}
