import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/app_settings.dart';
import '../../core/match_session.dart';
import 'paddle_duel_game.dart';

class PresentationMetrics {
  const PresentationMetrics({
    required this.outputSize,
    required this.requestedFps,
    required this.effectiveFps,
  });
  final Size outputSize;
  final int requestedFps;
  final double effectiveFps;
}

/// Separates the match simulation from its physical raster target.
///
/// Simulation advances at the display cadence. A snapshot is only produced at
/// the chosen presentation rate and is rasterized at the selected scale.
class PaddleDuelPresentation extends StatefulWidget {
  const PaddleDuelPresentation({
    required this.game,
    required this.session,
    required this.resolution,
    required this.frameRate,
    this.onMetrics,
    super.key,
  });

  final PaddleDuelGame game;
  final MatchSession session;
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;
  final ValueChanged<PresentationMetrics>? onMetrics;

  @override
  State<PaddleDuelPresentation> createState() => _PaddleDuelPresentationState();
}

class _PaddleDuelPresentationState extends State<PaddleDuelPresentation>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration? _previousTick;
  Duration? _previousRender;
  ui.Image? _frame;
  Size _outputSize = Size.zero;
  bool _rendering = false;
  Duration? _firstPublishedFrame;
  int _publishedFrames = 0;
  int _captureGeneration = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    // Widget tests drive the game model explicitly. On a device, including a
    // debug build, Flutter's normal binding starts the presentation ticker.
    if (!WidgetsBinding.instance.runtimeType.toString().contains('Test')) {
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(covariant PaddleDuelPresentation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resolution != widget.resolution ||
        oldWidget.frameRate != widget.frameRate) {
      _captureGeneration++;
      _previousRender = null;
      _firstPublishedFrame = null;
      _publishedFrames = 0;
    }
  }

  void _onTick(Duration elapsed) {
    final previous = _previousTick;
    _previousTick = elapsed;
    if (previous != null) {
      widget.game.update((elapsed - previous).inMicroseconds / 1000000);
    }
    if (_outputSize.isEmpty || _rendering) return;
    final lastRender = _previousRender;
    final interval = Duration(
      microseconds: 1000000 ~/ widget.frameRate.framesPerSecond,
    );
    if (lastRender != null && elapsed - lastRender < interval) return;
    _previousRender = elapsed;
    _captureFrame();
  }

  Future<void> _captureFrame() async {
    final renderedAt = _previousRender;
    if (renderedAt == null || _outputSize.isEmpty) return;
    final generation = _captureGeneration;
    final outputSize = _outputSize;
    _rendering = true;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    widget.game.renderAtSize(canvas, outputSize);
    final picture = recorder.endRecording();
    try {
      final image = await picture.toImage(
        outputSize.width.ceil(),
        outputSize.height.ceil(),
      );
      if (!mounted || generation != _captureGeneration) {
        image.dispose();
        return;
      }
      final previous = _frame;
      setState(() => _frame = image);
      previous?.dispose();
      _firstPublishedFrame ??= renderedAt;
      _publishedFrames++;
      final elapsed = renderedAt - _firstPublishedFrame!;
      widget.onMetrics?.call(
        PresentationMetrics(
          outputSize: outputSize,
          requestedFps: widget.frameRate.framesPerSecond,
          effectiveFps: _publishedFrames < 2 || elapsed.inMicroseconds == 0
              ? 0
              : (_publishedFrames - 1) * 1000000 / elapsed.inMicroseconds,
        ),
      );
    } catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'Paddle Duel graphics preview',
        ),
      );
    } finally {
      picture.dispose();
      _rendering = false;
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final logicalSize = Size(constraints.maxWidth, constraints.maxHeight);
      final pixelRatio = MediaQuery.devicePixelRatioOf(context);
      final nextOutput =
          logicalSize * pixelRatio * widget.resolution.renderScale;
      if (nextOutput != _outputSize) {
        _captureGeneration++;
        _outputSize = nextOutput;
        _previousRender = null;
      }
      return CustomPaint(
        painter: _PaddleDuelFramePainter(image: _frame, game: widget.game),
        child: const SizedBox.expand(),
      );
    },
  );
}

class _PaddleDuelFramePainter extends CustomPainter {
  const _PaddleDuelFramePainter({required this.image, required this.game});
  final ui.Image? image;
  final PaddleDuelGame game;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = image;
    if (frame != null) {
      canvas.drawImageRect(
        frame,
        Rect.fromLTWH(0, 0, frame.width.toDouble(), frame.height.toDouble()),
        Offset.zero & size,
        Paint()..filterQuality = FilterQuality.medium,
      );
      return;
    }
    // Show a complete court before the first asynchronous raster is ready.
    game.renderAtSize(canvas, size);
  }

  @override
  bool shouldRepaint(covariant _PaddleDuelFramePainter oldDelegate) =>
      oldDelegate.image != image || oldDelegate.game != game;
}
