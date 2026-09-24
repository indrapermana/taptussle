import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/match_options.dart';
import '../../core/match_session.dart';
import '../../games/paddle_duel/paddle_duel_game.dart';
import '../../games/paddle_duel/paddle_duel_presentation.dart';

/// Lets players compare the saved graphics profile with an unsaved candidate.
class GraphicsPreviewScreen extends StatefulWidget {
  const GraphicsPreviewScreen({required this.settings, super.key});
  final AppSettings settings;

  @override
  State<GraphicsPreviewScreen> createState() => _GraphicsPreviewScreenState();
}

class _GraphicsPreviewScreenState extends State<GraphicsPreviewScreen>
    with WidgetsBindingObserver {
  late ResolutionPreset candidateResolution;
  late FrameRatePreset candidateFrameRate;
  late final MatchSession _savedSession;
  late final MatchSession _candidateSession;
  late final PaddleDuelGame _savedGame;
  late final PaddleDuelGame _candidateGame;
  bool saving = false;
  int? _savedEffectiveFps;
  int? _candidateEffectiveFps;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    candidateResolution = widget.settings.resolution;
    candidateFrameRate = widget.settings.frameRate;
    _savedSession = MatchSession(
      options: const MatchOptions.friend(winningScore: 999),
    )..start();
    _candidateSession = MatchSession(
      options: const MatchOptions.friend(winningScore: 999),
    )..start();
    _savedGame = PaddleDuelGame(session: _savedSession);
    _candidateGame = PaddleDuelGame(session: _candidateSession);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _savedSession.pause();
      _candidateSession.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _savedGame.stopMatch();
    _candidateGame.stopMatch();
    _savedSession.dispose();
    _candidateSession.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    setState(() => saving = true);
    try {
      await widget.settings.setResolution(candidateResolution);
      await widget.settings.setFrameRate(candidateFrameRate);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save graphics settings.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Compare graphics')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'The same deterministic Paddle Duel rally is rendered twice. '
            'The game timer is independent of the selected frame rate.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 20),
          _PreviewPane(
            label: 'Saved settings',
            game: _savedGame,
            session: _savedSession,
            resolution: widget.settings.resolution,
            frameRate: widget.settings.frameRate,
            effectiveFps: _savedEffectiveFps,
            onMetrics: (metrics) => _recordMetrics(metrics, saved: true),
          ),
          const SizedBox(height: 20),
          _PreviewPane(
            label: 'Candidate settings',
            game: _candidateGame,
            session: _candidateSession,
            resolution: candidateResolution,
            frameRate: candidateFrameRate,
            effectiveFps: _candidateEffectiveFps,
            onMetrics: (metrics) => _recordMetrics(metrics, saved: false),
          ),
          const SizedBox(height: 20),
          const Text('Candidate resolution'),
          const SizedBox(height: 8),
          SegmentedButton<ResolutionPreset>(
            key: const ValueKey('candidate-resolution-selector'),
            segments: [
              for (final option in ResolutionPreset.values)
                ButtonSegment(
                  value: option,
                  label: Text(
                    '${option.label} ${(option.renderScale * 100).round()}%',
                  ),
                ),
            ],
            selected: {candidateResolution},
            onSelectionChanged: saving
                ? null
                : (value) => setState(() => candidateResolution = value.single),
          ),
          const SizedBox(height: 20),
          const Text('Candidate frame rate'),
          const SizedBox(height: 8),
          SegmentedButton<FrameRatePreset>(
            key: const ValueKey('candidate-fps-selector'),
            segments: [
              for (final option in FrameRatePreset.values)
                ButtonSegment(
                  value: option,
                  label: Text('${option.framesPerSecond} FPS'),
                ),
            ],
            selected: {candidateFrameRate},
            onSelectionChanged: saving
                ? null
                : (value) => setState(() => candidateFrameRate = value.single),
          ),
          const SizedBox(height: 12),
          const Text(
            'Lower resolution renders fewer pixels and can look softer. Lower FPS refreshes motion less often and can look less smooth. Battery use depends on the device and scene.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('apply-graphics-settings'),
            onPressed: saving ? null : _apply,
            child: const Text('Apply candidate settings'),
          ),
          TextButton(
            key: const ValueKey('cancel-graphics-settings'),
            onPressed: saving ? null : () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );

  void _recordMetrics(PresentationMetrics metrics, {required bool saved}) {
    final value = metrics.effectiveFps.round();
    if ((saved ? _savedEffectiveFps : _candidateEffectiveFps) == value ||
        !mounted) {
      return;
    }
    setState(() {
      if (saved) {
        _savedEffectiveFps = value;
      } else {
        _candidateEffectiveFps = value;
      }
    });
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.label,
    required this.game,
    required this.session,
    required this.resolution,
    required this.frameRate,
    required this.effectiveFps,
    required this.onMetrics,
  });
  final String label;
  final PaddleDuelGame game;
  final MatchSession session;
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;
  final int? effectiveFps;
  final ValueChanged<PresentationMetrics> onMetrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final dpr = MediaQuery.devicePixelRatioOf(context);
      final width = constraints.maxWidth;
      final height = width * 600 / 360;
      final targetWidth = (width * dpr * resolution.renderScale).round();
      final targetHeight = (height * dpr * resolution.renderScale).round();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 360 / 600,
              child: PaddleDuelPresentation(
                game: game,
                session: session,
                resolution: resolution,
                frameRate: frameRate,
                onMetrics: onMetrics,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${resolution.label} • $targetWidth × $targetHeight px • requested ${frameRate.framesPerSecond} FPS',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            effectiveFps == null || effectiveFps == 0
                ? 'Measuring effective refresh rate…'
                : 'Measured $effectiveFps FPS; limited by this device display and rendering load.',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ],
      );
    },
  );
}
