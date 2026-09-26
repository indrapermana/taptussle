# M23 graphics profile results

Use this sheet for physical-device evidence only. Debug and simulator runs do
not count. Test the production Paddle Duel presentation adapter in a real match;
the two-pane Settings comparison is useful for confirming cadence and image
sharpness, but its extra workload is not representative of normal gameplay.

## Build under test

- App version: `1.0.0+1`
- Git revision: `5c5bb4e`
- Flutter mode: profile
- Date started: 2026-09-25

## Collection procedure

1. Connect one physical device, unlock it, and keep it unplugged from Low Power
   Mode or battery-saver behavior that limits refresh rate.
2. Start `flutter run --profile -d <device-id>` and open Flutter DevTools from
   the printed VM service link.
3. In Settings, apply one resolution/FPS combination. Open Paddle Duel versus a
   friend and play for at least two minutes after a 30-second warm-up.
4. In the DevTools Performance view, record average build time, average raster
   time, slow-frame count, and total sampled frames. Confirm that input, ball
   speed, scoring, and bot timing remain unchanged.
5. Open the graphics comparison and record the actual offscreen pixel dimensions
   and measured presentation FPS. Treat this as a cadence check, not the match
   frame-timing sample.
6. Repeat all six combinations, then repeat the matrix on the other platform.

For a 60 Hz device, a healthy 60 FPS sample should normally keep build and
raster work below the 16.7 ms frame budget. The 30 FPS option intentionally
publishes the game image less often, while Flutter may still compose surrounding
UI at the display cadence. Record measurements as observed rather than forcing
them into a pass result.

## iPhone

- Device name: Indra
- Model: Pending device confirmation
- OS: iOS 26.6.2 (23G90)
- Device ID: `00008101-0012186122C2001E`
- Profile install: Build and signing succeeded on 2026-09-25
- Collection status: Blocked after launch because Flutter lost its device
  connection; no DevTools frame sample was available

| Resolution | Scale | Requested FPS | Offscreen pixels | Effective FPS | Avg build | Avg raster | Slow / total frames | Stability and gameplay | Result |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| Economy | 50% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Economy | 50% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## iPad

- Device name: Qpad
- Model: Pending device confirmation
- OS: iPadOS 26.7 (23H24)
- Device ID: `00008020-001549A611D1002E`
- Profile install: Build, signing, installation, and launch succeeded on
  2026-09-25
- Collection status: Flutter maintained the Dart VM Service and DevTools
  connection during the smoke run. The per-setting measurements below still
  require the six interactive gameplay samples described above.

| Resolution | Scale | Requested FPS | Offscreen pixels | Effective FPS | Avg build | Avg raster | Slow / total frames | Stability and gameplay | Result |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| Economy | 50% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Economy | 50% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

## Android

- Device/model: Pending connection
- OS: Pending
- Device ID: Pending
- Collection status: No physical Android device connected on 2026-09-25

| Resolution | Scale | Requested FPS | Offscreen pixels | Effective FPS | Avg build | Avg raster | Slow / total frames | Stability and gameplay | Result |
| --- | ---: | ---: | --- | ---: | ---: | ---: | --- | --- | --- |
| Economy | 50% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Economy | 50% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Balanced | 75% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 30 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |
| Native | 100% | 60 | Pending | Pending | Pending | Pending | Pending | Pending | Pending |

M23 graphics profiling is complete only when the iPhone and Android tables contain
measurements from the final release candidate and any release-blocking instability
has been fixed and retested. The iPad table provides additional large-screen iOS
coverage. The entries above are retained early evidence and must be refreshed after
M22 for the release candidate.
