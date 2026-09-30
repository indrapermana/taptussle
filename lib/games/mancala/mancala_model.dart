enum MancalaOutcome { playerOneWin, playerTwoWin, draw }

enum MancalaMoveResult {
  accepted,
  invalidPlayer,
  invalidPit,
  wrongTurn,
  emptyPit,
  matchFinished,
}

class MancalaTurn {
  const MancalaTurn({
    required this.player,
    required this.pit,
    required this.stonesSown,
    required this.sowingPath,
    required this.capturedStones,
    required this.extraTurn,
    required this.finished,
  });

  final int player;
  final int pit;
  final int stonesSown;
  final List<int> sowingPath;
  final int capturedStones;
  final bool extraTurn;
  final bool finished;

  int get landingPosition => sowingPath.last;
  bool get wasCapture => capturedStones > 0;
}

/// Pure rules for standard two-player Kalah.
///
/// Positions follow counterclockwise sowing order. Player 1 owns pits 0–5 and
/// store 6; Player 2 owns pits 7–12 and store 13. Public moves use a local pit
/// number from 0–5 for either player, keeping the future UI orientation-neutral.
class MancalaModel {
  MancalaModel({int startingPlayer = 0})
    : this.fromBoard(
        board: const [4, 4, 4, 4, 4, 4, 0, 4, 4, 4, 4, 4, 4, 0],
        currentPlayer: startingPlayer,
        startingPlayer: startingPlayer,
      );

  MancalaModel.fromBoard({
    required List<int> board,
    this.currentPlayer = 0,
    int? startingPlayer,
  }) : startingPlayer = startingPlayer ?? currentPlayer,
       _board = List.of(board) {
    _validatePlayer(currentPlayer, 'currentPlayer');
    _validatePlayer(this.startingPlayer, 'startingPlayer');
    if (_board.length != boardPositionCount) {
      throw ArgumentError.value(
        board.length,
        'board',
        'Must contain exactly $boardPositionCount positions',
      );
    }
    if (_board.any((stones) => stones < 0)) {
      throw ArgumentError.value(
        board,
        'board',
        'Stone counts cannot be negative',
      );
    }
    _totalStones = _board.fold(0, (total, stones) => total + stones);
    _finishIfSideEmpty();
  }

  MancalaModel.copy(MancalaModel other)
    : startingPlayer = other.startingPlayer,
      currentPlayer = other.currentPlayer,
      _board = List.of(other._board),
      _totalStones = other._totalStones,
      _outcome = other._outcome,
      _lastTurn = other._lastTurn;

  static const int pitsPerPlayer = 6;
  static const int boardPositionCount = 14;
  static const int initialStoneCount = 48;
  static const int playerOneStore = 6;
  static const int playerTwoStore = 13;

  final int startingPlayer;
  final List<int> _board;
  late final int _totalStones;

  List<int> get board => List.unmodifiable(_board);
  int currentPlayer;

  MancalaOutcome? _outcome;
  MancalaOutcome? get outcome => _outcome;
  bool get isFinished => _outcome != null;
  bool get isDraw => _outcome == MancalaOutcome.draw;
  int? get winner => switch (_outcome) {
    MancalaOutcome.playerOneWin => 0,
    MancalaOutcome.playerTwoWin => 1,
    MancalaOutcome.draw || null => null,
  };

  MancalaTurn? _lastTurn;
  MancalaTurn? get lastTurn => _lastTurn;

  int storeFor(int player) {
    _validatePlayer(player, 'player');
    return player == 0 ? playerOneStore : playerTwoStore;
  }

  int stonesInStore(int player) => _board[storeFor(player)];

  int boardPositionForPit(int player, int pit) {
    _validatePlayer(player, 'player');
    if (pit < 0 || pit >= pitsPerPlayer) {
      throw RangeError.range(pit, 0, pitsPerPlayer - 1, 'pit');
    }
    return player == 0 ? pit : 7 + pit;
  }

  int stonesInPit(int player, int pit) =>
      _board[boardPositionForPit(player, pit)];

  List<int> legalPitsFor(int player) {
    _validatePlayer(player, 'player');
    if (isFinished || player != currentPlayer) return const [];
    return List.unmodifiable([
      for (var pit = 0; pit < pitsPerPlayer; pit++)
        if (stonesInPit(player, pit) > 0) pit,
    ]);
  }

  MancalaMoveResult play(int player, int pit) {
    if (player < 0 || player > 1) return MancalaMoveResult.invalidPlayer;
    if (pit < 0 || pit >= pitsPerPlayer) return MancalaMoveResult.invalidPit;
    if (isFinished) return MancalaMoveResult.matchFinished;
    if (player != currentPlayer) return MancalaMoveResult.wrongTurn;

    final source = boardPositionForPit(player, pit);
    final stones = _board[source];
    if (stones == 0) return MancalaMoveResult.emptyPit;

    _board[source] = 0;
    final path = <int>[];
    var position = source;
    for (var remaining = stones; remaining > 0; remaining--) {
      do {
        position = (position + 1) % boardPositionCount;
      } while (position == storeFor(1 - player));
      _board[position]++;
      path.add(position);
    }

    var captured = 0;
    if (_isOwnedPit(player, position) && _board[position] == 1) {
      final opposite = 12 - position;
      if (_board[opposite] > 0) {
        captured = _board[opposite] + 1;
        _board[opposite] = 0;
        _board[position] = 0;
        _board[storeFor(player)] += captured;
      }
    }

    final landedInOwnStore = position == storeFor(player);
    final finished = _finishIfSideEmpty();
    final extraTurn = landedInOwnStore && !finished;
    if (!finished && !extraTurn) currentPlayer = 1 - player;

    _assertStoneInvariant();
    _lastTurn = MancalaTurn(
      player: player,
      pit: pit,
      stonesSown: stones,
      sowingPath: List.unmodifiable(path),
      capturedStones: captured,
      extraTurn: extraTurn,
      finished: finished,
    );
    return MancalaMoveResult.accepted;
  }

  bool _finishIfSideEmpty() {
    final playerOneEmpty = _sideIsEmpty(0);
    final playerTwoEmpty = _sideIsEmpty(1);
    if (!playerOneEmpty && !playerTwoEmpty) return false;

    for (final player in [0, 1]) {
      final store = storeFor(player);
      for (var pit = 0; pit < pitsPerPlayer; pit++) {
        final position = boardPositionForPit(player, pit);
        _board[store] += _board[position];
        _board[position] = 0;
      }
    }

    final playerOneScore = stonesInStore(0);
    final playerTwoScore = stonesInStore(1);
    _outcome = playerOneScore == playerTwoScore
        ? MancalaOutcome.draw
        : playerOneScore > playerTwoScore
        ? MancalaOutcome.playerOneWin
        : MancalaOutcome.playerTwoWin;
    return true;
  }

  bool _sideIsEmpty(int player) {
    for (var pit = 0; pit < pitsPerPlayer; pit++) {
      if (stonesInPit(player, pit) > 0) return false;
    }
    return true;
  }

  static bool _isOwnedPit(int player, int position) => player == 0
      ? position >= 0 && position < playerOneStore
      : position > playerOneStore && position < playerTwoStore;

  void _assertStoneInvariant() {
    assert(
      _board.fold(0, (total, stones) => total + stones) == _totalStones,
      'A Mancala move must conserve every stone.',
    );
  }

  static void _validatePlayer(int player, String name) {
    if (player < 0 || player > 1) {
      throw ArgumentError.value(player, name, 'Must be 0 or 1');
    }
  }
}
