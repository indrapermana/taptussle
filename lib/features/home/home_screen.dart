import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/mini_game.dart';
import '../../core/sound_service.dart';
import '../game_setup/game_setup_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({required this.settings, required this.games, super.key});

  final AppSettings settings;
  final List<MiniGame> games;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: settings,
    builder: (context, _) => Scaffold(
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
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        fontFamily: 'Lilita One',
                                        color: Colors.white,
                                        letterSpacing: 1.1,
                                      ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${games.length} GAMES',
                                style: const TextStyle(
                                  color: TapTussleColors.mutedText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
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
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final game = favouritesFirst(
                          games,
                          settings.favouriteIds,
                        )[index];
                        return _GameTile(game: game, settings: settings);
                      }, childCount: games.length),
                    ),
                  ),
                  const SliverPadding(padding: EdgeInsets.only(bottom: 28)),
                ],
              ),
            ),
          ),
        ),
      ),
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
            SoundEffects.play(SoundEffect.click);
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
    SoundEffects.play(SoundEffect.click);
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
                  widget.game.preview?.call(context) ??
                      _IconPreview(icon: widget.game.icon, accent: accent),
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

class _IconPreview extends StatelessWidget {
  const _IconPreview({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: RadialGradient(
        center: const Alignment(0, -.15),
        radius: .82,
        colors: [accent.withValues(alpha: .52), TapTussleColors.navy],
      ),
    ),
    child: Center(
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: TapTussleColors.midnight.withValues(alpha: .62),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: .8)),
          boxShadow: [
            BoxShadow(color: accent.withValues(alpha: .25), blurRadius: 20),
          ],
        ),
        child: Icon(icon, size: 50, color: Colors.white),
      ),
    ),
  );
}

class _ModeBadges extends StatelessWidget {
  const _ModeBadges({required this.game});

  final MiniGame game;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const _TinyBadge(label: '2P'),
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
