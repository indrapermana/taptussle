# TapTussle

Offline, same-device mini-games for two players, built with Flutter and Flame.
The first increment includes **Paddle Duel only**. Android and iOS are the mobile
targets; web is included for quick desktop previews.

## Run

The project was created with Flutter 3.35.4 / Dart 3.9.2. Dependency resolution
selected Flame 1.35.1 for that SDK. Commit `pubspec.lock` with the application.

```sh
flutter pub get
flutter run                    # select a connected phone or emulator
flutter run -d chrome          # preview; use a touch device for two players
flutter analyze
flutter test
flutter build web --release --no-web-resources-cdn
```

Mobile gameplay requires no network, account, server, or downloaded assets.
Dependencies/toolchains require an internet connection during initial setup.
The web preview is not an offline-installed PWA; the offline product target is
the installed mobile application. Release signing and store assets are not set up.
The package namespace is `com.indesyakaryadigital.tap_tussle`.

## Play Paddle Duel

- Hold the phone in portrait and sit at opposite ends.
- Player 1 (mint) drags in the bottom half; Player 2 (coral) in the top half.
- Both players can drag at once. One finger owns each paddle until released;
  crossing the halfway line does not change ownership.
- Hit near a paddle edge to angle the return. The ball speeds up during rallies.
- A missed ball gives the opponent one point. Each serve has a short countdown.
- First to 7 wins by default. Settings offers 5, 7, or 11 and saves locally.
- Pause retains the match. Switching apps also pauses; returning requires Resume.
- Back during play pauses first. Use Back to games to leave, or Play again after
  a result to reset the same match.

## Structure

```text
lib/
  app/                     App theme and game catalog (composition root)
  core/                    Engine-independent definitions, session, settings
  features/
    home/                  Catalog and settings UI
    match/                 Instructions, score HUD, pause, result, lifecycle
  games/
    paddle_duel/
      paddle_duel_model.dart   Pure Dart simulation and rules
      paddle_duel_game.dart    Flame loop and rendering adapter
      paddle_duel_view.dart    Multi-touch input and session adapter
      paddle_duel_preview.dart Catalog artwork
```

Dependencies flow from `app` into modules, and from modules into `core`.
`core` and shared screens do not import individual games or Flame. Games do not
import each other. A game exposes a Flutter widget through `MiniGame.build`;
that widget may contain a Flame `GameWidget` or ordinary Flutter widgets.

`MatchSession` provides ready → playing → paused/finished, immutable score
snapshots, an optional winning player index (0 or 1), and a round counter for
resets. The shell owns/disposes the session. Games listen to it, stop updates and
input while not playing, reset when the round changes, and remove listeners on
disposal. Games own their win rules and publish scores/results with
`reportScore`; the shell does not calculate winners.

Paddle Duel uses Flame's low-level `Game` because it has a small, custom-rendered
court. Flame supplies its loop and canvas; its pure Dart model implements bounded
physics substeps, collisions, serves, and scoring. More complex games can use
`FlameGame` and components without changing the shared contract. Forge2D is not
needed for this Pong simulation; add it within a future module if justified.

## Add the next game

1. Create `lib/games/<game_id>/` with its own widget, rules, and assets if needed.
2. Accept a `MatchSession` and the score preference in the entry widget. Games
   that are not point-based can ignore the score preference.
3. Reset on each new `session.round`, freeze in non-playing phases, and publish
   a result with `session.reportScore(p1, p2, winner: playerIndex)`.
4. Add one `MiniGame` entry in `lib/app/game_catalog.dart`: unique ID, title,
   subtitle, instructions, icon, and builder. Optional `preview` and `matchLabel`
   customize the card art and HUD. Defaults are an icon and “2 PLAYERS”.
5. Add rule tests and input/lifecycle coverage for that game. No shared screen
   needs to change. Declare any local assets in `pubspec.yaml`.

The widget tests include a tiny pure Flutter test fixture proving this integration
path; it is not a second shipped mini-game. Avoid introducing a global game
manager or requiring inheritance from Paddle Duel. Extend the shared result
contract when a real game needs draws or timed-result metadata.

Suggested next increment: Reaction Duel in pure Flutter, validating a second
independent module. Air Hockey, a movement/racing game, and the fifth game remain
future work.

## Verification and remaining device checks

Tests cover court bounds, both paddles, wall collisions, deflection, scoring,
winning, rematches, long frame stalls, settings persistence, simultaneous touch,
lifecycle pausing, navigation, small-screen layout, and a pure Flutter adapter.

Before a mobile release, play on physical Android and iOS devices, especially
simultaneous edge touches, interruptions, notches, and tablet resizing. Native
builds depend on local Android/Xcode toolchains and signing. App icons are still
the generated Flutter defaults; audio/haptics and store packaging are deferred.

Initial verification (2026-09-23): `flutter analyze` is clean; all 13 tests pass;
the release web build succeeds. Phone-sized layouts were also rendered through
Flutter's test renderer. Android APK verification was attempted but stopped during
the slow initial Gradle distribution download, before compilation. To retry, run
`flutter build apk --debug`. iOS compilation was not attempted: local doctor
checks reported unavailable simulator runtimes and outdated CocoaPods. Neither
mobile platform has been play-tested on a physical device yet.
