# TapTussle

Offline, same-device mini-games for two players, built with Flutter and Flame.
The current catalog includes **Paddle Duel**, **Reaction Duel**, **Air Hockey**,
**Lane Dash**, and **Tic-Tac-Toe**, with friend and local-bot modes. Android and
iOS are the mobile targets; web is included for quick desktop previews.

## Development roadmap

See [the development plan](docs/DEVELOPMENT_PLAN.md) for milestone checklists,
remaining games, friend/bot modes, favourites, difficulty, expanded settings,
and the live resolution/FPS comparison preview. M3–M6 have functional passes on
iPhone and Android; native automation and release validation remain tracked there.

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

## Play

Choose a game, then select **Play vs Friend** or **Play vs Bot**. Bot mode offers
Easy, Normal, and Hard. Game setup also lets you favourite a game. Saved favourites
appear first in the selection list while the remaining games retain catalog order.

Paddle Duel uses these controls and match rules:

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
    <game_id>/
      <game_id>_model.dart       Pure rules and mutable game state
      <game_id>_bot.dart         Optional bot policy
      <game_id>_game.dart        Flame loop and rendering adapter
      <game_id>_controller.dart  Pure Flutter/timer orchestration alternative
      <game_id>_view.dart        Flutter input, layout, and lifecycle adapter
      <game_id>_preview.dart     Optional catalog or preview artwork
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

Flame games normally use a model, optional bot, game adapter, and Flutter view.
Pure Flutter games normally use a model, optional bot/controller, and view; they
do not add a Flame adapter merely to match the directory shape. Paddle Duel, Air
Hockey, and Lane Dash use Flame. Reaction Duel uses a timer-based Flutter
controller because it does not need a frame loop or canvas rendering.

The model owns legal state transitions and outcomes. A bot observes permitted
state and submits input through the same model methods used by a person. A Flame
game or Flutter controller advances time and publishes results to `MatchSession`.
The view maps touch input, owns widget listeners, and avoids game rules, bot
decisions, and rendering loops. Inject randomness into models and bots so rule
and difficulty tests remain deterministic.

Bots should feel human. Turn-based bots wait for a visible, bounded thinking
delay before moving, including on Hard. Real-time bots observe and react at
bounded intervals. Pause, match completion, option changes, and disposal cancel
pending actions; resume schedules a fresh action only when it remains the bot's
turn. Use this behavior for every future game with bot mode.

## Add the next game

1. Create `lib/games/<game_id>/` using the model/bot/game-or-controller/view
   responsibilities above. Include only the files that game needs.
2. Accept immutable `MatchOptions` and a `MatchSession` in the entry view. Games
   that are not point-based can ignore the configured winning score.
3. Reset on each new `session.round`, freeze in non-playing phases, and publish
   point, draw, or non-point results through `MatchSession`.
4. Add one `MiniGame` entry in `lib/app/game_catalog.dart`: unique ID, title,
   subtitle, instructions, icon, and builder. Optional `preview` and `matchLabel`
   customize the card art and HUD. Defaults are an icon and “2 PLAYERS”.
5. Add rule tests and input/lifecycle coverage for that game. No shared screen
   needs to change. Declare any local assets in `pubspec.yaml`.

Avoid introducing a global game manager or requiring inheritance from an existing
game. Shared code defines lifecycle and integration contracts; each module owns
its rules and presentation. The initial five-game catalog and its physical-device
functional passes are complete. M8 release validation is next.

## Verification and remaining device checks

Tests cover game rules, scoring/results, bot policies, rematches, settings,
simultaneous input, lifecycle pausing, navigation, and layout behavior.

Paddle Duel, Reaction Duel, Air Hockey, Lane Dash, and Tic-Tac-Toe have been
exercised during development. M3–M7 are functionally confirmed on physical
iPhone and Android devices. The newly revised Air Hockey bot profiles still need
another device pass.
Before release, M8 requires recorded device/build details, profile-mode graphics
measurements, offline and interruption checks, accessibility/safe-area coverage,
long-session checks, app icons, attribution, and release signing. Native UI
automation remains parked because Flutter could not attach its iPhone test runner.
