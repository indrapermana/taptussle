enum PlayMode { friend, bot, solo }

enum BotDifficulty {
  easy('Easy'),
  normal('Normal'),
  hard('Hard');

  const BotDifficulty(this.label);
  final String label;
}

enum ParticipantKind { human, bot }

enum ParticipantColor { mint, coral, gold, violet }

enum ParticipantToken { circle, diamond, triangle, star }

class MatchParticipant {
  const MatchParticipant.human({
    required this.displayName,
    required this.color,
    required this.token,
  }) : kind = ParticipantKind.human,
       botDifficulty = null;

  const MatchParticipant.bot({
    required this.displayName,
    required this.color,
    required this.token,
    required BotDifficulty difficulty,
  }) : kind = ParticipantKind.bot,
       botDifficulty = difficulty;

  final String displayName;
  final ParticipantKind kind;
  final ParticipantColor color;
  final ParticipantToken token;
  final BotDifficulty? botDifficulty;

  bool get isBot => kind == ParticipantKind.bot;
}

/// Frozen at match creation. Games receive the same ordered participant list for
/// solo, friend, bot, and future mixed multiplayer matches.
class MatchOptions {
  factory MatchOptions.friend({int winningScore = 7}) => MatchOptions._(
    mode: PlayMode.friend,
    participants: const [
      MatchParticipant.human(
        displayName: 'Player 1',
        color: ParticipantColor.mint,
        token: ParticipantToken.circle,
      ),
      MatchParticipant.human(
        displayName: 'Player 2',
        color: ParticipantColor.coral,
        token: ParticipantToken.diamond,
      ),
    ],
    winningScore: winningScore,
  );

  factory MatchOptions.bot({
    required BotDifficulty difficulty,
    int winningScore = 7,
  }) => MatchOptions._(
    mode: PlayMode.bot,
    participants: [
      const MatchParticipant.human(
        displayName: 'You',
        color: ParticipantColor.mint,
        token: ParticipantToken.circle,
      ),
      MatchParticipant.bot(
        displayName: 'Bot',
        color: ParticipantColor.coral,
        token: ParticipantToken.diamond,
        difficulty: difficulty,
      ),
    ],
    winningScore: winningScore,
  );

  factory MatchOptions.solo({
    String displayName = 'You',
    ParticipantColor color = ParticipantColor.mint,
    ParticipantToken token = ParticipantToken.circle,
    int winningScore = 7,
  }) => MatchOptions._(
    mode: PlayMode.solo,
    participants: [
      MatchParticipant.human(
        displayName: displayName,
        color: color,
        token: token,
      ),
    ],
    winningScore: winningScore,
  );

  factory MatchOptions.custom({
    required PlayMode mode,
    required List<MatchParticipant> participants,
    int winningScore = 7,
  }) => MatchOptions._(
    mode: mode,
    participants: participants,
    winningScore: winningScore,
  );

  MatchOptions._({
    required this.mode,
    required List<MatchParticipant> participants,
    required this.winningScore,
  }) : participants = List.unmodifiable(participants) {
    if (winningScore <= 0) {
      throw ArgumentError.value(
        winningScore,
        'winningScore',
        'Must be positive',
      );
    }
    if (participants.isEmpty || participants.length > 4) {
      throw ArgumentError.value(
        participants.length,
        'participants',
        'A match requires one to four participants',
      );
    }
    if (participants.any(
      (participant) => participant.displayName.trim().isEmpty,
    )) {
      throw ArgumentError('Participant names cannot be empty');
    }
    if (participants.map((participant) => participant.color).toSet().length !=
        participants.length) {
      throw ArgumentError('Participant colors must be unique');
    }
    if (participants.map((participant) => participant.token).toSet().length !=
        participants.length) {
      throw ArgumentError('Participant tokens must be unique');
    }
    if (!participants.any((participant) => !participant.isBot)) {
      throw ArgumentError('A local match requires at least one human');
    }
    switch (mode) {
      case PlayMode.solo:
        if (participants.length != 1 || participants.single.isBot) {
          throw ArgumentError('Solo mode requires exactly one human');
        }
        break;
      case PlayMode.friend:
        if (participants.length < 2 ||
            participants.any((participant) => participant.isBot)) {
          throw ArgumentError('Friend mode requires two to four humans');
        }
        break;
      case PlayMode.bot:
        if (participants.length < 2 ||
            !participants.any((participant) => participant.isBot)) {
          throw ArgumentError('Bot mode requires a human and at least one bot');
        }
        break;
    }
  }

  final PlayMode mode;
  final List<MatchParticipant> participants;
  final int winningScore;

  /// Compatibility accessor for the existing one-bot games.
  BotDifficulty? get botDifficulty {
    for (final participant in participants) {
      if (participant.isBot) return participant.botDifficulty;
    }
    return null;
  }

  String playerLabel(int player) => participants[player].displayName;

  String resultLabel(int winner) {
    final label = playerLabel(winner);
    return label == 'You' ? 'You win!' : '$label wins!';
  }
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

  MatchOptions matchOptions(int winningScore) => switch (mode) {
    PlayMode.friend => MatchOptions.friend(winningScore: winningScore),
    PlayMode.bot => MatchOptions.bot(
      difficulty: difficulty,
      winningScore: winningScore,
    ),
    PlayMode.solo => MatchOptions.solo(winningScore: winningScore),
  };
}
