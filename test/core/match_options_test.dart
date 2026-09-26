import 'package:flutter_test/flutter_test.dart';
import 'package:tap_tussle/core/match_options.dart';

void main() {
  const playerOne = MatchParticipant.human(
    displayName: 'Player 1',
    color: ParticipantColor.mint,
    token: ParticipantToken.circle,
  );
  const playerTwo = MatchParticipant.human(
    displayName: 'Player 2',
    color: ParticipantColor.coral,
    token: ParticipantToken.diamond,
  );
  const playerThree = MatchParticipant.human(
    displayName: 'Player 3',
    color: ParticipantColor.gold,
    token: ParticipantToken.triangle,
  );
  const playerFour = MatchParticipant.bot(
    displayName: 'Bot 4',
    color: ParticipantColor.violet,
    token: ParticipantToken.star,
    difficulty: BotDifficulty.hard,
  );

  test('legacy friend and bot factories preserve labels and difficulty', () {
    final friend = MatchOptions.friend(winningScore: 5);
    final bot = MatchOptions.bot(
      difficulty: BotDifficulty.hard,
      winningScore: 11,
    );

    expect(friend.mode, PlayMode.friend);
    expect(friend.participants, hasLength(2));
    expect(friend.playerLabel(0), 'Player 1');
    expect(friend.playerLabel(1), 'Player 2');
    expect(friend.botDifficulty, isNull);
    expect(friend.winningScore, 5);

    expect(bot.mode, PlayMode.bot);
    expect(bot.participants.first.kind, ParticipantKind.human);
    expect(bot.participants.last.kind, ParticipantKind.bot);
    expect(bot.playerLabel(0), 'You');
    expect(bot.resultLabel(0), 'You win!');
    expect(bot.resultLabel(1), 'Bot wins!');
    expect(bot.botDifficulty, BotDifficulty.hard);
    expect(bot.winningScore, 11);
  });

  test('custom options retain an immutable ordered mixed participant list', () {
    final source = [playerOne, playerTwo, playerThree, playerFour];
    final options = MatchOptions.custom(
      mode: PlayMode.bot,
      participants: source,
    );
    source.clear();

    expect(options.participants.map((participant) => participant.displayName), [
      'Player 1',
      'Player 2',
      'Player 3',
      'Bot 4',
    ]);
    expect(options.participants.last.botDifficulty, BotDifficulty.hard);
    expect(() => options.participants.add(playerOne), throwsUnsupportedError);
  });

  test('solo options create one human with a stable visual identity', () {
    final options = MatchOptions.solo(displayName: 'Indra');

    expect(options.mode, PlayMode.solo);
    expect(options.participants, hasLength(1));
    expect(options.playerLabel(0), 'Indra');
    expect(options.participants.single.color, ParticipantColor.mint);
    expect(options.participants.single.token, ParticipantToken.circle);
    expect(options.participants.single.botDifficulty, isNull);
  });

  test('custom options reject invalid participant configurations', () {
    expect(
      () => MatchOptions.custom(mode: PlayMode.friend, participants: const []),
      throwsArgumentError,
    );
    expect(
      () => MatchOptions.custom(
        mode: PlayMode.friend,
        participants: const [playerOne],
      ),
      throwsArgumentError,
    );
    expect(
      () => MatchOptions.custom(
        mode: PlayMode.friend,
        participants: const [
          playerOne,
          MatchParticipant.human(
            displayName: 'Duplicate color',
            color: ParticipantColor.mint,
            token: ParticipantToken.diamond,
          ),
        ],
      ),
      throwsArgumentError,
    );
    expect(
      () => MatchOptions.custom(
        mode: PlayMode.bot,
        participants: const [playerOne, playerTwo],
      ),
      throwsArgumentError,
    );
    expect(
      () => MatchOptions.custom(
        mode: PlayMode.bot,
        participants: const [
          MatchParticipant.bot(
            displayName: 'Bot 1',
            color: ParticipantColor.mint,
            token: ParticipantToken.circle,
            difficulty: BotDifficulty.easy,
          ),
          MatchParticipant.bot(
            displayName: 'Bot 2',
            color: ParticipantColor.coral,
            token: ParticipantToken.diamond,
            difficulty: BotDifficulty.normal,
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
