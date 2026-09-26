import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_settings.dart';
import '../core/haptic_service.dart';
import '../core/sound_service.dart';
import 'tap_tussle_app.dart';

typedef PreferencesLoader = Future<SharedPreferences> Function();

/// Displays the branded startup experience while application services load.
class TapTussleBootstrap extends StatefulWidget {
  const TapTussleBootstrap({
    this.minimumDisplayDuration = const Duration(seconds: 2),
    this.preferencesLoader,
    super.key,
  });

  final Duration minimumDisplayDuration;
  final PreferencesLoader? preferencesLoader;

  @override
  State<TapTussleBootstrap> createState() => _TapTussleBootstrapState();
}

class _TapTussleBootstrapState extends State<TapTussleBootstrap> {
  AppSettings? _settings;
  SoundService? _sounds;
  HapticService? _haptics;
  Object? _error;
  double _progress = .06;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final started = Stopwatch()..start();
    _setProgress(.18);
    try {
      final preferences =
          await (widget.preferencesLoader?.call() ??
              SharedPreferences.getInstance());
      if (!mounted) return;
      _setProgress(.52);

      final settings = AppSettings(preferences);
      final sounds = SoundService()..setVolume(settings.effectsVolume);
      final haptics = HapticService(enabled: settings.vibrationEnabled);
      SoundEffects.configure(sounds);
      HapticEffects.configure(haptics);
      settings.addListener(_applyFeedbackSettings);
      _settings = settings;
      _sounds = sounds;
      _haptics = haptics;
      _setProgress(.78);

      _setProgress(.92);

      final remaining = widget.minimumDisplayDuration - started.elapsed;
      if (remaining > Duration.zero) await Future<void>.delayed(remaining);
      if (!mounted) return;
      setState(() => _progress = 1);
      await Future<void>.delayed(const Duration(milliseconds: 180));
      if (mounted) setState(() => _ready = true);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _setProgress(double value) {
    if (mounted) setState(() => _progress = value);
  }

  void _applyFeedbackSettings() {
    final settings = _settings;
    if (settings == null) return;
    _sounds?.setVolume(settings.effectsVolume);
    _haptics?.setEnabled(settings.vibrationEnabled);
  }

  void _retry() {
    _settings?.removeListener(_applyFeedbackSettings);
    _sounds?.dispose();
    setState(() {
      _settings = null;
      _sounds = null;
      _haptics = null;
      _error = null;
      _progress = .06;
      _ready = false;
    });
    _initialize();
  }

  @override
  void dispose() {
    _settings?.removeListener(_applyFeedbackSettings);
    _sounds?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_settings != null && _ready) {
      return TapTussleApp(settings: _settings!);
    }
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _StartupScreen(
        progress: _progress,
        failed: _error != null,
        onRetry: _retry,
      ),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen({
    required this.progress,
    required this.failed,
    required this.onRetry,
  });

  final double progress;
  final bool failed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF07123F),
    body: Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/branding/splash_screen.png',
          fit: BoxFit.cover,
          alignment: Alignment.center,
        ),
        SafeArea(
          child: Align(
            alignment: const Alignment(0, .88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 42),
              child: failed
                  ? FilledButton(
                      key: const ValueKey('startup-retry'),
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Semantics(
                          label: 'Loading Tap Tussle',
                          value: '${(progress * 100).round()}%',
                          child: TweenAnimationBuilder<double>(
                            tween: Tween(end: progress),
                            duration: Duration(
                              milliseconds: progress == 1 ? 160 : 1600,
                            ),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, _) =>
                                LinearProgressIndicator(
                                  key: const ValueKey('startup-progress'),
                                  value: value,
                                  minHeight: 8,
                                  borderRadius: BorderRadius.circular(8),
                                  backgroundColor: Colors.black45,
                                  color: const Color(0xFFFFD32A),
                                ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'LOADING…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                            shadows: [
                              Shadow(color: Colors.black, blurRadius: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    ),
  );
}
