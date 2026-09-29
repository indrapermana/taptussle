enum RockPaperScissorsChoice { rock, paper, scissors }

enum RockPaperScissorsRoundOutcome { playerOneWin, playerTwoWin, draw }

enum RockPaperScissorsPlayResult {
  roundDraw,
  playerOneScored,
  playerTwoScored,
  playerOneWonMatch,
  playerTwoWonMatch,
  matchFinished,
}

class RockPaperScissorsRound {
  const RockPaperScissorsRound({
    required this.playerOneChoice,
    required this.playerTwoChoice,
    required this.outcome,
  });

  final RockPaperScissorsChoice playerOneChoice;
  final RockPaperScissorsChoice playerTwoChoice;
  final RockPaperScissorsRoundOutcome outcome;
}

/// Pure rules and score state for one Rock Paper Scissors match.
///
/// Both choices are submitted together so neither participant gains information
/// about the other choice before the round has been resolved.
class RockPaperScissorsModel {
  RockPaperScissorsModel({required this.winningScore}) {
    if (winningScore <= 0) {
      throw ArgumentError.value(
        winningScore,
        'winningScore',
        'Must be positive',
      );
    }
  }

  final int winningScore;
  final List<int> _scores = [0, 0];

  List<int> get scores => List.unmodifiable(_scores);

  int _roundCount = 0;
  int get roundCount => _roundCount;

  RockPaperScissorsRound? _lastRound;
  RockPaperScissorsRound? get lastRound => _lastRound;

  int? _winner;
  int? get winner => _winner;
  bool get isFinished => _winner != null;

  RockPaperScissorsPlayResult playRound(
    RockPaperScissorsChoice playerOneChoice,
    RockPaperScissorsChoice playerTwoChoice,
  ) {
    if (isFinished) return RockPaperScissorsPlayResult.matchFinished;

    final outcome = outcomeFor(playerOneChoice, playerTwoChoice);
    _roundCount++;
    _lastRound = RockPaperScissorsRound(
      playerOneChoice: playerOneChoice,
      playerTwoChoice: playerTwoChoice,
      outcome: outcome,
    );

    switch (outcome) {
      case RockPaperScissorsRoundOutcome.draw:
        return RockPaperScissorsPlayResult.roundDraw;
      case RockPaperScissorsRoundOutcome.playerOneWin:
        _scores[0]++;
        if (_scores[0] >= winningScore) {
          _winner = 0;
          return RockPaperScissorsPlayResult.playerOneWonMatch;
        }
        return RockPaperScissorsPlayResult.playerOneScored;
      case RockPaperScissorsRoundOutcome.playerTwoWin:
        _scores[1]++;
        if (_scores[1] >= winningScore) {
          _winner = 1;
          return RockPaperScissorsPlayResult.playerTwoWonMatch;
        }
        return RockPaperScissorsPlayResult.playerTwoScored;
    }
  }

  static RockPaperScissorsRoundOutcome outcomeFor(
    RockPaperScissorsChoice playerOneChoice,
    RockPaperScissorsChoice playerTwoChoice,
  ) {
    if (playerOneChoice == playerTwoChoice) {
      return RockPaperScissorsRoundOutcome.draw;
    }
    final playerOneWins =
        (playerOneChoice == RockPaperScissorsChoice.rock &&
            playerTwoChoice == RockPaperScissorsChoice.scissors) ||
        (playerOneChoice == RockPaperScissorsChoice.paper &&
            playerTwoChoice == RockPaperScissorsChoice.rock) ||
        (playerOneChoice == RockPaperScissorsChoice.scissors &&
            playerTwoChoice == RockPaperScissorsChoice.paper);
    return playerOneWins
        ? RockPaperScissorsRoundOutcome.playerOneWin
        : RockPaperScissorsRoundOutcome.playerTwoWin;
  }

  void reset() {
    _scores.fillRange(0, _scores.length, 0);
    _roundCount = 0;
    _lastRound = null;
    _winner = null;
  }

  void startRematch() => reset();
}
