# TapTussle

Offline, same-device mini-games for two players, built with Flutter and Flame.
The current catalog includes **Paddle Duel**, **Reaction Duel**, **Air Hockey**,
**Lane Dash**, and **Tic-Tac-Toe**, with friend and local-bot modes. Android and
iOS are the mobile targets; web is included for quick desktop previews.

## Development roadmap

See [the development plan](docs/DEVELOPMENT_PLAN.md) for milestone checklists,
remaining games, friend/bot modes, favourites, difficulty, expanded settings,
and the live resolution/FPS comparison preview. The current five-game foundation
has completed its branding and automated-regression checkpoint. The planned first
public release expands the catalog to all 18 currently selected games, adds solo
and up-to-four-player support, and runs final release validation in M23.

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

The native mobile launch experience uses the branded Tap Tussle artwork on iOS
and supported Android versions. Android 12 and newer use the TT app icon on a
matching dark-blue background within the operating system's splash layout. A
branded Flutter loading screen then initializes saved preferences and feedback
services with an animated progress bar before opening the game catalog.

## Play

Choose a game, then select **Play vs Friend** or **Play vs Bot**. Bot mode offers
Easy, Normal, and Hard. Game setup also lets you favourite a game. Saved favourites
appear first in the selection list while the remaining games retain catalog order.
The catalog tabs filter games by **1 Player**, **2 Players**, or **Up to 4 Players**
and remember the last selection. Games that support both two and three/four players
appear in both compatible tabs; favourites remain first inside the active tab.

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

Each `MiniGame` also declares supported one-to-four player counts, supported
solo/friend/bot modes, what its difficulty changes (bot, puzzle, challenge, or
none), optional catalog artwork, and optional ordered record metrics. Catalog
artwork uses a shared stable-ID map with 1×/2× assets, readable contain fitting,
and an icon fallback when an asset cannot load. Existing games remain explicit
two-player friend/bot games. Record metadata defines comparison order. The shared
offline repository stores immutable results by game ID, record type, and
difficulty/rules variant, using device-local completion timestamps. It ranks the
primary metric and tie-breakers in their declared direction; duration metric values
are stored in milliseconds. Games submit results without owning persistence or
ranking logic. For solo games with records, the shared setup panel derives Daily
Best from the current local date, Weekly Best from Monday–Sunday, and Overall Best
from the matching history. These windows are recomputed from timestamps when read,
so calendar rollover does not require a background job. History is capped at 250
attempts per game, record type, and variant. Retention keeps the all-time best and
the newest attempts, preserving Overall Best while bounding local storage.

`MatchOptions` carries an immutable ordered list of one to four participants.
Each participant has a display name, human or bot ownership, a unique color and
token, and an optional bot difficulty. The friend and bot factories retain the
existing two-player defaults, while solo and custom factories support future game
setups without making individual games own participant configuration.

All UI and gameplay audio routes through the shared `SoundEffects` facade and
the bundled TapTussle Shared Sound Pack. The typed map includes UI, countdown,
round, scoring, impact, movement, card, dice, puzzle, and result cues. The match
shell emits one start and one final-result sound per round; games emit only their
own moves, collisions, countdowns, and non-final score cues. Warm/cool scoring
follows participant color, while bot matches distinguish human wins and losses.
The service respects the master volume, suppresses near-simultaneous duplicate
cues, stops playback in the background, and disposes its players with the app.

Games supporting three or four players use the shared participant setup screen to
choose a supported count and configure each ordered seat. It keeps at least one
local human, prevents duplicate colors and tokens, and shows bot controls only
when the game's capabilities allow them. Existing two-player games retain their
short Friend/Bot flow, and solo-only games start through a dedicated solo action.

`MatchSession` provides ready → playing → paused/finished, immutable
participant-ordered score snapshots, an optional winning participant, explicit
draw and winnerless-completion outcomes, optional ordered standings, and a round
counter for resets. The shell owns/disposes the session. Games listen to it, stop
updates and input while not playing, reset when the round changes, and remove
listeners on disposal. Games own their win rules and publish scores/results; the
shell does not calculate winners. The original two-player reporting methods remain
available as compatibility adapters.

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
functional passes and the M8 automated checkpoint are complete. M9 introduces
player-count capabilities, catalog filters, and local solo records.

## Verification and remaining device checks

Tests cover game rules, scoring/results, bot policies, rematches, settings,
simultaneous input, lifecycle pausing, navigation, and layout behavior.

Paddle Duel, Reaction Duel, Air Hockey, Lane Dash, and Tic-Tac-Toe have been
exercised during development. M3–M7 are functionally confirmed on physical
iPhone and Android devices. The newly revised Air Hockey bot profiles still need
another device pass.
M23 consolidates recorded device/build details, profile-mode graphics measurements,
offline and interruption checks, accessibility/safe-area coverage, long-session
checks, final 18-game signing, and store preparation. Native UI
automation remains parked because Flutter could not attach its iPhone test runner.
Use [`docs/M23_GRAPHICS_PROFILE_RESULTS.md`](docs/M23_GRAPHICS_PROFILE_RESULTS.md)
for the retained procedure and the final physical-device graphics evidence matrix.
