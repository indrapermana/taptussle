enum TicTacToeMark { x, o }

enum TicTacToeOutcome { playerOneWin, playerTwoWin, draw }

enum TicTacToeMoveResult {
  accepted,
  invalidPlayer,
  outOfBounds,
  wrongTurn,
  occupied,
  matchFinished,
}

/// Pure rules and state for one Tic-Tac-Toe match.
///
/// Player 1 always owns X and Player 2 always owns O. Rematches alternate which
/// participant moves first without changing mark ownership.
class TicTacToeModel {
  TicTacToeModel({int startingPlayer = 0})
    : assert(startingPlayer == 0 || startingPlayer == 1),
      _startingPlayer = startingPlayer,
      _currentPlayer = startingPlayer;

  static const cellCount = 9;
  static const winningLines = <List<int>>[
    [0, 1, 2],
    [3, 4, 5],
    [6, 7, 8],
    [0, 3, 6],
    [1, 4, 7],
    [2, 5, 8],
    [0, 4, 8],
    [2, 4, 6],
  ];

  final List<TicTacToeMark?> _board = List.filled(cellCount, null);
  List<TicTacToeMark?> get board => List.unmodifiable(_board);
  List<int> get availableCells => [
    for (var cell = 0; cell < cellCount; cell++)
      if (_board[cell] == null) cell,
  ];

  int _startingPlayer;
  int get startingPlayer => _startingPlayer;

  int _currentPlayer;
  int get currentPlayer => _currentPlayer;

  TicTacToeOutcome? _outcome;
  TicTacToeOutcome? get outcome => _outcome;

  List<int>? _winningLine;
  List<int>? get winningLine =>
      _winningLine == null ? null : List.unmodifiable(_winningLine!);

  int _moveCount = 0;
  int get moveCount => _moveCount;
  bool get isFinished => _outcome != null;
  bool get isDraw => _outcome == TicTacToeOutcome.draw;
  int? get winner => switch (_outcome) {
    TicTacToeOutcome.playerOneWin => 0,
    TicTacToeOutcome.playerTwoWin => 1,
    TicTacToeOutcome.draw || null => null,
  };

  TicTacToeMark markForPlayer(int player) {
    if (player == 0) return TicTacToeMark.x;
    if (player == 1) return TicTacToeMark.o;
    throw RangeError.range(player, 0, 1, 'player');
  }

  TicTacToeMoveResult play(int player, int cell) {
    if (player < 0 || player > 1) {
      return TicTacToeMoveResult.invalidPlayer;
    }
    if (cell < 0 || cell >= cellCount) {
      return TicTacToeMoveResult.outOfBounds;
    }
    if (isFinished) {
      return TicTacToeMoveResult.matchFinished;
    }
    if (player != _currentPlayer) {
      return TicTacToeMoveResult.wrongTurn;
    }
    if (_board[cell] != null) {
      return TicTacToeMoveResult.occupied;
    }

    final mark = markForPlayer(player);
    _board[cell] = mark;
    _moveCount++;
    for (final line in winningLines) {
      if (line.every((index) => _board[index] == mark)) {
        _winningLine = List.of(line);
        _outcome = player == 0
            ? TicTacToeOutcome.playerOneWin
            : TicTacToeOutcome.playerTwoWin;
        return TicTacToeMoveResult.accepted;
      }
    }
    if (_moveCount == cellCount) {
      _outcome = TicTacToeOutcome.draw;
      return TicTacToeMoveResult.accepted;
    }

    _currentPlayer = 1 - _currentPlayer;
    return TicTacToeMoveResult.accepted;
  }

  /// Clears the board while keeping the current match's starting participant.
  void reset() => _clearBoard();

  /// Clears the board and gives the other participant the first move.
  void startRematch() {
    _startingPlayer = 1 - _startingPlayer;
    _clearBoard();
  }

  void _clearBoard() {
    _board.fillRange(0, cellCount, null);
    _currentPlayer = _startingPlayer;
    _outcome = null;
    _winningLine = null;
    _moveCount = 0;
  }
}
