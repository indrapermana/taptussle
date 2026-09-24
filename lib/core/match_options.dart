enum PlayMode { friend, bot }

enum BotDifficulty {
  easy('Easy'),
  normal('Normal'),
  hard('Hard');

  const BotDifficulty(this.label);
  final String label;
}

/// Frozen at match creation. Friend matches can never carry a bot difficulty.
class MatchOptions {
  const MatchOptions.friend({this.winningScore = 7})
    : mode = PlayMode.friend,
      botDifficulty = null,
      assert(winningScore > 0);

  const MatchOptions.bot({
    required BotDifficulty difficulty,
    this.winningScore = 7,
  }) : mode = PlayMode.bot,
       botDifficulty = difficulty,
       assert(winningScore > 0);

  final PlayMode mode;
  final BotDifficulty? botDifficulty;
  final int winningScore;

  String playerLabel(int player) => mode == PlayMode.friend
      ? 'Player ${player + 1}'
      : player == 0
      ? 'You'
      : 'Bot';

  String resultLabel(int winner) => mode == PlayMode.bot && winner == 0
      ? 'You win!'
      : '${playerLabel(winner)} wins!';
}

/// Setup remembers difficulty even when the player switches back to friend mode.
class GamePreferences {
  const GamePreferences({
    this.mode = PlayMode.friend,
    this.difficulty = BotDifficulty.normal,
  });

  final PlayMode mode;
  final BotDifficulty difficulty;

  GamePreferences copyWith({PlayMode? mode, BotDifficulty? difficulty}) =>
      GamePreferences(
        mode: mode ?? this.mode,
        difficulty: difficulty ?? this.difficulty,
      );

  MatchOptions matchOptions(int winningScore) => mode == PlayMode.friend
      ? MatchOptions.friend(winningScore: winningScore)
      : MatchOptions.bot(difficulty: difficulty, winningScore: winningScore);
}
