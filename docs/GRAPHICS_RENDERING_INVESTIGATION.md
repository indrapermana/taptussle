# Graphics rendering investigation

Date: 2026-09-24  
Scope: M3.6 for TapTussle's installed Flutter 3.35.4 and Flame 1.35.1.

## Findings

`GameWidget` gives Flame a Flutter canvas that is rasterized at the device's
normal render-target resolution. Flame's fixed-resolution camera and viewport
APIs alter logical coordinates, visible world area, and aspect handling. They do
not request a smaller native render target. Using them for the Settings
"resolution" option would therefore change game layout or touch coordinates,
not graphics sharpness.

The Flame game loop calls `update(dt)` and `render(canvas)` for each Flutter
frame. Flame 1.35.1 has no public setting that caps a `GameWidget` to 30 FPS.
Dropping or delaying simulation updates to emulate 30 FPS would change Paddle
Duel's game speed, bot timing, and collision behavior, which is unacceptable.

## Required production approach

Resolution requires a shared presentation adapter that renders the game scene
to an offscreen target at 50%, 75%, or 100% of its physical dimensions, then
scales that image into the normal Flutter layout. It must leave the logical
360×600 Paddle Duel model and its input mapping unchanged.

FPS requires a separate presentation scheduler. Simulation remains elapsed-time
based at its existing bounded/fixed substeps; only publishing rendered frames is
limited to the selected cadence. On a 60 Hz display, the 30 FPS path may publish
every second eligible frame. It must report requested and effective cadence,
because a device's display rate can impose a different limit.

The two-pane preview should use this same adapter around a deterministic scene;
it must not use a video, a layout-only scaling trick, or a separate mock.

## Physical validation still required

Measure the adapter in profile mode on iPhone and Android at all six
resolution/FPS combinations. Record model/OS, actual offscreen dimensions,
requested/effective FPS, and frame build/raster timings. The current iPhone
Flutter debug transport issue and lack of an Android device prevent that device
evidence today, so M3.6 remains open.

## References

- [Flame game loop](https://docs.flame-engine.org/latest/flame/game.html)
- [Flame fixed-resolution camera](https://docs.flame-engine.org/latest/flame/camera.html)
- [Flutter rendering performance](https://docs.flutter.dev/perf/rendering-performance)
- [Flutter performance metrics](https://docs.flutter.dev/perf/metrics)
