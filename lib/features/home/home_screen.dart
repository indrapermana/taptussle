import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../game_setup/game_setup_screen.dart';
import '../settings/settings_screen.dart';
import 'game_artwork.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.settings, required this.games, super.key});

  final AppSettings settings;
  final List<MiniGame> games;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) {
      final visibleGames = favouritesFirst(
        games
            .where((game) => _matchesFilter(game, settings.catalogPlayerFilter))
            .toList(),
        settings.favouriteIds,
      );
      return Scaffold(
        body: TapTussleBackdrop(
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: CustomScrollView(
                  key: const PageStorageKey('game-selection'),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
                      sliver: SliverToBoxAdapter(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _LobbyHeader(settings: settings),
                            const SizedBox(height: 22),
                            const _RivalBanner(),
                            const SizedBox(height: 24),
                            Row(
                              children: [
                                const Icon(
                                  Icons.sports_esports_rounded,
                                  size: 19,
                                  color: TapTussleColors.gold,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'CHOOSE YOUR BATTLE',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontFamily: 'Lilita One',
                                          color: Colors.white,
                                          letterSpacing: 1.1,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  '${visibleGames.length} GAMES',
                                  style: const TextStyle(
                                    color: TapTussleColors.mutedText,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _PlayerFilterTabs(settings: settings),
                          ],
                        ),
                      ),
                    ),
                    if (visibleGames.isEmpty)
                      const SliverPadding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverToBoxAdapter(child: _EmptyCatalog()),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverGrid(
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                                maxCrossAxisExtent: 260,
                                mainAxisSpacing: 16,
                                crossAxisSpacing: 16,
                                childAspectRatio: .86,
                              ),
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => _GameTile(
                              game: visibleGames[index],
                              settings: settings,
                            ),
                            childCount: visibleGames.length,
                          ),
                        ),
                      ),
                    const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}

bool _matchesFilter(
  MiniGame game,
  CatalogPlayerFilter filter,
) => switch (filter) {
  CatalogPlayerFilter.onePlayer => game.supportsPlayerCount(PlayerCount.one),
  CatalogPlayerFilter.twoPlayers => game.supportsPlayerCount(PlayerCount.two),
  CatalogPlayerFilter.upToFourPlayers =>
    game.supportsPlayerCount(PlayerCount.three) ||
        game.supportsPlayerCount(PlayerCount.four),
};

class _PlayerFilterTabs extends StatelessWidget {
  const _PlayerFilterTabs({required this.settings});

  final AppSettings settings;

  Future<void> _select(BuildContext context, CatalogPlayerFilter filter) async {
    if (filter == settings.catalogPlayerFilter) return;
    SoundEffects.play(SoundEffect.uiTap);
    try {
      await settings.setCatalogPlayerFilter(filter);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save player filter.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: TapTussleColors.panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: TapTussleColors.panelBorder),
    ),
    child: Row(
      children: CatalogPlayerFilter.values
          .map(
            (filter) => Expanded(
              child: _PlayerFilterTab(
                filter: filter,
                selected: filter == settings.catalogPlayerFilter,
                onPressed: () => _select(context, filter),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _PlayerFilterTab extends StatelessWidget {
  const _PlayerFilterTab({
    required this.filter,
    required this.selected,
    required this.onPressed,
  });

  final CatalogPlayerFilter filter;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    button: true,
    label: filter.label,
    child: Material(
      color: selected ? TapTussleColors.gold : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        key: ValueKey('player-filter-${filter.name}'),
        borderRadius: BorderRadius.circular(13),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              filter.label.toUpperCase(),
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? TapTussleColors.midnight
                    : TapTussleColors.mutedText,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: .5,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _EmptyCatalog extends StatelessWidget {
  const _EmptyCatalog();

  @override
  Widget build(BuildContext context) => const ArcadePanel(
    key: ValueKey('empty-game-catalog'),
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 34),
    child: Column(
      children: [
        Icon(
          Icons.sports_esports_outlined,
          color: TapTussleColors.electricBlue,
          size: 46,
        ),
        SizedBox(height: 14),
        Text(
          'MORE GAMES ARE COMING',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Lilita One',
            color: Colors.white,
            fontSize: 20,
            letterSpacing: .7,
          ),
        ),
        SizedBox(height: 7),
        Text(
          'Choose another player tab to keep playing.',
          textAlign: TextAlign.center,
          style: TextStyle(color: TapTussleColors.mutedText, height: 1.4),
        ),
      ],
    ),
  );
}

class _LobbyHeader extends StatelessWidget {
  const _LobbyHeader({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              TapTussleColors.rivalRed,
              TapTussleColors.gold,
              TapTussleColors.electricBlue,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x5527C7FF),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'TT',
          style: TextStyle(
            fontFamily: 'Lilita One',
            color: TapTussleColors.midnight,
            fontSize: 26,
            height: 1,
            letterSpacing: -1,
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'TAP TUSSLE',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                height: .95,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 3),
            const Text(
              'LOCAL ARCADE • SAME DEVICE',
              style: TextStyle(
                color: TapTussleColors.mutedText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      Material(
        color: TapTussleColors.panel,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: TapTussleColors.panelBorder),
          borderRadius: BorderRadius.circular(16),
        ),
        child: IconButton(
          tooltip: 'Settings',
          onPressed: () {
            SoundEffects.play(SoundEffect.uiTap);
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(settings: settings),
              ),
            );
          },
          icon: const Icon(Icons.settings_rounded),
          color: TapTussleColors.text,
        ),
      ),
    ],
  );
}

class _RivalBanner extends StatelessWidget {
  const _RivalBanner();

  @override
  Widget build(BuildContext context) => const ArcadePanel(
    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    child: Row(
      children: [
        _RivalSide(
          alignment: CrossAxisAlignment.start,
          eyebrow: 'ONE PHONE',
          title: 'TWO',
          color: TapTussleColors.rivalRed,
        ),
        Expanded(child: Center(child: _VersusBolt())),
        _RivalSide(
          alignment: CrossAxisAlignment.end,
          eyebrow: 'ENDLESS FUN',
          title: 'RIVALS',
          color: TapTussleColors.electricBlue,
        ),
      ],
    ),
  );
}

class _VersusBolt extends StatelessWidget {
  const _VersusBolt();

  @override
  Widget build(BuildContext context) => Transform.rotate(
    angle: -.12,
    child: Container(
      width: 42,
      height: 42,
      decoration: const BoxDecoration(
        color: TapTussleColors.gold,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Color(0x66FFD338), blurRadius: 16)],
      ),
      child: const Icon(
        Icons.bolt_rounded,
        color: TapTussleColors.midnight,
        size: 30,
      ),
    ),
  );
}

class _RivalSide extends StatelessWidget {
  const _RivalSide({
    required this.alignment,
    required this.eyebrow,
    required this.title,
    required this.color,
  });

  final CrossAxisAlignment alignment;
  final String eyebrow;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: alignment,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.start
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Text(
            eyebrow,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignment == CrossAxisAlignment.start
              ? Alignment.centerLeft
              : Alignment.centerRight,
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: 'Lilita One',
              fontSize: 27,
              height: 1.05,
              color: Colors.white,
            ),
          ),
        ),
      ],
    ),
  );
}

class _GameTile extends StatefulWidget {
  const _GameTile({required this.game, required this.settings});

  final MiniGame game;
  final AppSettings settings;

  @override
  State<_GameTile> createState() => _GameTileState();
}

class _GameTileState extends State<_GameTile> {
  bool _pressed = false;

  Color get accent => switch (widget.game.id) {
    'reaction-duel' || 'paddle-duel' => TapTussleColors.rivalRed,
    'tic-tac-toe' => TapTussleColors.gold,
    _ => TapTussleColors.electricBlue,
  };

  void _open() {
    SoundEffects.play(SoundEffect.uiTap);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            GameSetupScreen(game: widget.game, settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favourite = widget.settings.isFavourite(widget.game.id);
    return AnimatedScale(
      scale: _pressed ? .965 : 1,
      duration: const Duration(milliseconds: 100),
      curve: Curves.easeOut,
      child: Container(
        key: ValueKey('game-card-${widget.game.id}'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(23),
          boxShadow: [
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
            BoxShadow(
              color: accent.withValues(alpha: favourite ? .24 : .11),
              blurRadius: favourite ? 20 : 12,
            ),
          ],
        ),
        child: Material(
          color: TapTussleColors.navy,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(
              color: favourite ? TapTussleColors.gold : accent,
              width: favourite ? 2 : 1.2,
            ),
          ),
          child: Semantics(
            button: true,
            label: 'Open ${widget.game.title}',
            child: InkWell(
              onTap: _open,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapUp: (_) => setState(() => _pressed = false),
              onTapCancel: () => setState(() => _pressed = false),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (widget.game.artworkAsset != null)
                    GameArtwork(
                      gameId: widget.game.id,
                      assetPath: widget.game.artworkAsset,
                      icon: widget.game.icon,
                      accent: accent,
                    )
                  else
                    widget.game.preview?.call(context) ??
                        GameArtwork(
                          gameId: widget.game.id,
                          icon: widget.game.icon,
                          accent: accent,
                        ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x00000000),
                          Color(0x22030A16),
                          Color(0xF2030915),
                        ],
                        stops: [0, .38, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    child: _ModeBadges(game: widget.game),
                  ),
                  if (favourite)
                    const Positioned(
                      top: 9,
                      right: 9,
                      child: _FavouriteBadge(),
                    ),
                  Positioned(
                    left: 14,
                    right: 14,
                    bottom: 13,
                    child: Text(
                      widget.game.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Lilita One',
                        color: Colors.white,
                        fontSize: 20,
                        height: 1,
                        letterSpacing: .4,
                        shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeBadges extends StatelessWidget {
  const _ModeBadges({required this.game});

  final MiniGame game;

  String get playerLabel {
    final counts =
        game.supportedPlayerCounts.map((count) => count.value).toList()..sort();
    return counts.first == counts.last
        ? '${counts.first}P'
        : '${counts.first}–${counts.last}P';
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      _TinyBadge(label: playerLabel),
      if (game.supportedModes.contains(PlayMode.bot)) ...[
        const SizedBox(width: 5),
        const _TinyBadge(label: 'BOT'),
      ],
    ],
  );
}

class _TinyBadge extends StatelessWidget {
  const _TinyBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xC9061129),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9,
        fontWeight: FontWeight.w800,
        letterSpacing: .7,
      ),
    ),
  );
}

class _FavouriteBadge extends StatelessWidget {
  const _FavouriteBadge();

  @override
  Widget build(BuildContext context) => Container(
    width: 32,
    height: 32,
    decoration: BoxDecoration(
      color: TapTussleColors.midnight.withValues(alpha: .88),
      shape: BoxShape.circle,
      border: Border.all(color: TapTussleColors.gold),
    ),
    child: const Icon(
      Icons.star_rounded,
      color: TapTussleColors.gold,
      size: 21,
    ),
  );
}
