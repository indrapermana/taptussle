# M23.4 runtime and resilience results

Date: 2026-10-11

This checkpoint verifies behavior around normal play rather than game rules or
rendering performance. Performance profiling remains separate in M23.3.

## Automated evidence

- [x] The complete host suite passes: 670 tests.
- [x] Match lifecycle transitions pause active play and do not abandon saved
  progress until the player actually leaves the match route.
- [x] Leaving a paused match clears game-specific active progress where the
  catalog entry provides an abandon handler, so reopening from game selection
  starts cleanly.
- [x] Bot and animation callbacks are cancelled or rescheduled across pause,
  resume, rematch, result, and disposal by their focused controller tests.
- [x] Global settings, favourites, game setup, records, and resumable puzzle
  repositories persist locally with no server dependency.
- [x] Malformed JSON, mismatched snapshots, invalid values, and wrong storage
  types fall back safely. Wrong-type coverage includes global settings, Ludo,
  Cangkulan, Solitaire, Sudoku, Water Sort, and Nuts & Bolts.
- [x] Every sound effect resolves to a bundled asset. Zero volume suppresses
  playback, lifecycle interruption stops active players, and audio is configured
  to respect the platform silent setting.
- [x] Vibration is optional, locally persisted, rate limited, and has a no-op
  path on unsupported hardware.
- [x] The release manifests and Dart dependencies contain no network client or
  release INTERNET permission. Debug/profile INTERNET permission is Flutter
  tooling support and is absent from the Android release manifest.

## Physical iPhone checklist

Use the current release candidate on the iPhone 12 mini. These checks are short
manual behavior checks; they do not run the profiler.

| Check | Expected behavior | Status |
| --- | --- | --- |
| Offline cold launch | Force-quit, enable airplane mode, disable Wi-Fi, then launch. Home artwork, Settings, one real-time game, and one puzzle open and play normally. | Passed by project owner on iPhone 12 mini |
| Silent switch | With effects volume above zero and the iPhone in silent mode, game effects remain silent. | Passed by project owner on iPhone 12 mini |
| Volume and vibration settings | Effects volume zero silences effects. Vibration Off suppresses game feedback; turning it back On restores feedback. | Pending |
| Audio interruption | Start external audio, play a game, and trigger an effect. Lock/unlock or briefly interrupt audio. The game does not crash or leave a looping effect. | Pending |
| Background and lock | During Paddle Duel or Lane Dash, background or lock the phone. Returning shows the paused state; no score, movement, or bot action happened while hidden. | Pending |
| Leave and reopen | Pause, choose Games or Change options, then reopen the same game. It starts a new match rather than resuming the abandoned board. | Pending |
| Intended puzzle restoration | Force-quit during an unfinished Solitaire, Sudoku, Water Sort, Nuts & Bolts, Ludo, or Cangkulan session. Relaunching may restore its valid active save; explicitly leaving through Games clears it. | Pending |
| Saved preferences | Change favourite, difficulty, effects volume, vibration, picture quality, and smoothness. Force-quit and relaunch; each intended preference remains. | Pending |
| Longer session | Play for at least 20 minutes across one real-time game and one board/puzzle game. Touch, timers, audio, pause, and navigation remain responsive without a crash. | Pending |

The project owner accepted the airplane-mode and silent-mode checks as the
physical M23.4 pass on 2026-10-11. The remaining rows are retained as useful
release-smoke scenarios; their lifecycle, persistence, settings, and feedback
behavior is covered by the automated suite and the earlier complete iPhone 12
mini catalog pass.
