import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../match/match_screen.dart';

class ParticipantSetupScreen extends StatefulWidget {
  const ParticipantSetupScreen({
    required this.game,
    required this.settings,
    super.key,
  });

  final MiniGame game;
  final AppSettings settings;

  @override
  State<ParticipantSetupScreen> createState() => _ParticipantSetupScreenState();
}

class _ParticipantSetupScreenState extends State<ParticipantSetupScreen> {
  late final List<PlayerCount> _allowedCounts;
  final List<_ParticipantDraft> _participants = [];
  late PlayerCount _playerCount;
  bool _saving = false;

  bool get _supportsFriend =>
      widget.game.supportedModes.contains(PlayMode.friend);
  bool get _supportsBot => widget.game.supportedModes.contains(PlayMode.bot);

  @override
  void initState() {
    super.initState();
    _allowedCounts =
        widget.game.supportedPlayerCounts
            .where((count) => count.value > 1)
            .toList()
          ..sort((left, right) => left.value.compareTo(right.value));
    assert(_allowedCounts.isNotEmpty);
    _playerCount = _allowedCounts.first;
    _resizeParticipants(_playerCount.value);
  }

  @override
  void dispose() {
    for (final participant in _participants) {
      participant.dispose();
    }
    super.dispose();
  }

  void _resizeParticipants(int count) {
    while (_participants.length > count) {
      _participants.removeLast().dispose();
    }
    while (_participants.length < count) {
      final index = _participants.length;
      final botByDefault =
          index > 0 &&
          _supportsBot &&
          (!_supportsFriend ||
              widget.settings.preferencesFor(widget.game.id).mode ==
                  PlayMode.bot);
      _participants.add(
        _ParticipantDraft(
          index: index,
          kind: botByDefault ? ParticipantKind.bot : ParticipantKind.human,
          difficulty: widget.settings.preferencesFor(widget.game.id).difficulty,
        ),
      );
    }
  }

  void _selectCount(PlayerCount count) {
    if (count == _playerCount) return;
    setState(() {
      _playerCount = count;
      _resizeParticipants(count.value);
    });
  }

  void _changeKind(int index, ParticipantKind kind) {
    if (index == 0 || _participants[index].kind == kind) return;
    setState(() => _participants[index].changeKind(kind));
  }

  Iterable<ParticipantColor> _availableColors(int index) {
    final used = _participants.indexed
        .where((entry) => entry.$1 != index)
        .map((entry) => entry.$2.color)
        .toSet();
    return ParticipantColor.values.where((color) => !used.contains(color));
  }

  Iterable<ParticipantToken> _availableTokens(int index) {
    final used = _participants.indexed
        .where((entry) => entry.$1 != index)
        .map((entry) => entry.$2.token)
        .toSet();
    return ParticipantToken.values.where((token) => !used.contains(token));
  }

  bool get _canPlay {
    if (_participants.any((draft) => draft.name.text.trim().isEmpty)) {
      return false;
    }
    final hasBot = _participants.any(
      (participant) => participant.kind == ParticipantKind.bot,
    );
    return hasBot ? _supportsBot : _supportsFriend;
  }

  Future<void> _play() async {
    if (!_canPlay || _saving) return;
    setState(() => _saving = true);
    try {
      final hasBot = _participants.any(
        (participant) => participant.kind == ParticipantKind.bot,
      );
      final mode = hasBot ? PlayMode.bot : PlayMode.friend;
      final participants = _participants
          .map((draft) => draft.build())
          .toList(growable: false);
      final options = MatchOptions.custom(
        mode: mode,
        participants: participants,
        winningScore: widget.settings.winningScore,
      );
      final rememberedDifficulty = _participants
          .where((participant) => participant.kind == ParticipantKind.bot)
          .map((participant) => participant.difficulty)
          .firstOrNull;
      await widget.settings.saveGamePreferences(
        widget.game.id,
        GamePreferences(
          mode: mode,
          difficulty:
              rememberedDifficulty ??
              widget.settings.preferencesFor(widget.game.id).difficulty,
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MatchScreen(
            game: widget.game,
            options: options,
            resolution: widget.settings.resolution,
            frameRate: widget.settings.frameRate,
            startImmediately: true,
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Set up players')),
    body: TapTussleBackdrop(
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              children: [
                ArcadePanel(
                  accent: TapTussleColors.gold,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SetupHeading(
                        icon: Icons.groups_rounded,
                        title: 'How many players?',
                        color: TapTussleColors.gold,
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final count in _allowedCounts)
                            ChoiceChip(
                              key: ValueKey('participant-count-${count.value}'),
                              label: Text('${count.value} PLAYERS'),
                              selected: _playerCount == count,
                              onSelected: _saving
                                  ? null
                                  : (selected) {
                                      if (selected) _selectCount(count);
                                    },
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                for (final entry in _participants.indexed) ...[
                  _ParticipantCard(
                    index: entry.$1,
                    draft: entry.$2,
                    canChooseKind:
                        entry.$1 > 0 && _supportsFriend && _supportsBot,
                    fixedBot: entry.$1 > 0 && !_supportsFriend && _supportsBot,
                    showBotDifficulty:
                        widget.game.difficultyType == DifficultyType.bot,
                    availableColors: _availableColors(entry.$1).toList(),
                    availableTokens: _availableTokens(entry.$1).toList(),
                    enabled: !_saving,
                    onKindChanged: (kind) => _changeKind(entry.$1, kind),
                    onChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const ValueKey('start-configured-match'),
                  onPressed: _canPlay && !_saving
                      ? () {
                          SoundEffects.play(SoundEffect.click);
                          _play();
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start match'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ParticipantDraft {
  _ParticipantDraft({
    required int index,
    required this.kind,
    required this.difficulty,
  }) : seatNumber = index + 1,
       name = TextEditingController(
         text: kind == ParticipantKind.bot
             ? 'Bot ${index + 1}'
             : 'Player ${index + 1}',
       ),
       color = ParticipantColor.values[index],
       token = ParticipantToken.values[index];

  final TextEditingController name;
  final int seatNumber;
  ParticipantKind kind;
  ParticipantColor color;
  ParticipantToken token;
  BotDifficulty difficulty;

  void changeKind(ParticipantKind next) {
    final oldDefault = kind == ParticipantKind.bot
        ? 'Bot $seatNumber'
        : 'Player $seatNumber';
    if (name.text == oldDefault) {
      name.text = next == ParticipantKind.bot
          ? 'Bot $seatNumber'
          : 'Player $seatNumber';
    }
    kind = next;
  }

  MatchParticipant build() => switch (kind) {
    ParticipantKind.human => MatchParticipant.human(
      displayName: name.text.trim(),
      color: color,
      token: token,
    ),
    ParticipantKind.bot => MatchParticipant.bot(
      displayName: name.text.trim(),
      color: color,
      token: token,
      difficulty: difficulty,
    ),
  };

  void dispose() => name.dispose();
}

class _ParticipantCard extends StatelessWidget {
  const _ParticipantCard({
    required this.index,
    required this.draft,
    required this.canChooseKind,
    required this.fixedBot,
    required this.showBotDifficulty,
    required this.availableColors,
    required this.availableTokens,
    required this.enabled,
    required this.onKindChanged,
    required this.onChanged,
  });

  final int index;
  final _ParticipantDraft draft;
  final bool canChooseKind;
  final bool fixedBot;
  final bool showBotDifficulty;
  final List<ParticipantColor> availableColors;
  final List<ParticipantToken> availableTokens;
  final bool enabled;
  final ValueChanged<ParticipantKind> onKindChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final accent = _participantColor(draft.color);
    return ArcadePanel(
      accent: accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SetupHeading(
            icon: draft.kind == ParticipantKind.bot
                ? Icons.smart_toy_rounded
                : Icons.person_rounded,
            title: 'Player ${index + 1}',
            color: accent,
          ),
          const SizedBox(height: 14),
          if (canChooseKind)
            SegmentedButton<ParticipantKind>(
              key: ValueKey('participant-kind-$index'),
              segments: const [
                ButtonSegment(
                  value: ParticipantKind.human,
                  icon: Icon(Icons.person_rounded),
                  label: Text('Human'),
                ),
                ButtonSegment(
                  value: ParticipantKind.bot,
                  icon: Icon(Icons.smart_toy_rounded),
                  label: Text('Bot'),
                ),
              ],
              selected: {draft.kind},
              onSelectionChanged: enabled
                  ? (selection) => onKindChanged(selection.single)
                  : null,
            )
          else
            _LockedKindLabel(
              isBot: fixedBot || draft.kind == ParticipantKind.bot,
            ),
          const SizedBox(height: 14),
          TextField(
            key: ValueKey('participant-name-$index'),
            controller: draft.name,
            enabled: enabled,
            maxLength: 18,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              labelText: 'Display name',
              counterText: '',
            ),
            onChanged: (_) => onChanged(),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<ParticipantColor>(
                  key: ValueKey('participant-color-$index-${draft.color.name}'),
                  initialValue: draft.color,
                  decoration: const InputDecoration(labelText: 'Color'),
                  items: availableColors
                      .map(
                        (color) => DropdownMenuItem(
                          value: color,
                          child: Text(_colorLabel(color)),
                        ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (color) {
                          if (color == null) return;
                          draft.color = color;
                          onChanged();
                        }
                      : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<ParticipantToken>(
                  key: ValueKey('participant-token-$index-${draft.token.name}'),
                  initialValue: draft.token,
                  decoration: const InputDecoration(labelText: 'Token'),
                  items: availableTokens
                      .map(
                        (token) => DropdownMenuItem(
                          value: token,
                          child: Text(_tokenLabel(token)),
                        ),
                      )
                      .toList(),
                  onChanged: enabled
                      ? (token) {
                          if (token == null) return;
                          draft.token = token;
                          onChanged();
                        }
                      : null,
                ),
              ),
            ],
          ),
          if (draft.kind == ParticipantKind.bot && showBotDifficulty) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<BotDifficulty>(
              key: ValueKey(
                'participant-difficulty-$index-${draft.difficulty.name}',
              ),
              initialValue: draft.difficulty,
              decoration: const InputDecoration(labelText: 'Bot difficulty'),
              items: BotDifficulty.values
                  .map(
                    (difficulty) => DropdownMenuItem(
                      value: difficulty,
                      child: Text(difficulty.label),
                    ),
                  )
                  .toList(),
              onChanged: enabled
                  ? (difficulty) {
                      if (difficulty == null) return;
                      draft.difficulty = difficulty;
                      onChanged();
                    }
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _LockedKindLabel extends StatelessWidget {
  const _LockedKindLabel({required this.isBot});

  final bool isBot;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        isBot ? Icons.smart_toy_rounded : Icons.person_rounded,
        color: TapTussleColors.mutedText,
      ),
      const SizedBox(width: 8),
      Text(
        isBot ? 'BOT' : 'LOCAL HUMAN',
        style: const TextStyle(
          color: TapTussleColors.mutedText,
          fontWeight: FontWeight.w800,
          letterSpacing: .8,
        ),
      ),
    ],
  );
}

class _SetupHeading extends StatelessWidget {
  const _SetupHeading({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color),
      const SizedBox(width: 9),
      Expanded(
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Lilita One',
            color: color,
            fontSize: 20,
            letterSpacing: .7,
          ),
        ),
      ),
    ],
  );
}

Color _participantColor(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => const Color(0xFF9DF5CF),
  ParticipantColor.coral => const Color(0xFFFF968A),
  ParticipantColor.gold => TapTussleColors.gold,
  ParticipantColor.violet => const Color(0xFFB388FF),
};

String _colorLabel(ParticipantColor color) => switch (color) {
  ParticipantColor.mint => 'Mint',
  ParticipantColor.coral => 'Coral',
  ParticipantColor.gold => 'Gold',
  ParticipantColor.violet => 'Violet',
};

String _tokenLabel(ParticipantToken token) => switch (token) {
  ParticipantToken.circle => 'Circle',
  ParticipantToken.diamond => 'Diamond',
  ParticipantToken.triangle => 'Triangle',
  ParticipantToken.star => 'Star',
};
