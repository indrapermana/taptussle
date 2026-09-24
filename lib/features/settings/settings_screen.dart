import 'package:flutter/material.dart';

import '../../core/app_settings.dart';
import '../../core/sound_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double volume;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    volume = widget.settings.effectsVolume;
  }

  Future<void> _saveVolume(double value) async {
    setState(() => saving = true);
    try {
      await widget.settings.setEffectsVolume(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save effects volume.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Sound',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            volume == 0
                ? 'Effects are muted.'
                : '${(volume * 100).round()}% effects volume • 20% steps',
            style: const TextStyle(color: Colors.white70),
          ),
          Slider(
            key: const ValueKey('effects-volume-slider'),
            value: volume,
            divisions: 5,
            label: '${(volume * 100).round()}%',
            onChanged: saving
                ? null
                : (value) {
                    setState(() => volume = value);
                    SoundEffects.setVolume(value);
                  },
            onChangeEnd: saving ? null : _saveVolume,
          ),
          OutlinedButton.icon(
            key: const ValueKey('preview-sound'),
            onPressed: volume == 0
                ? null
                : () => SoundEffects.play(SoundEffect.click),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Preview sound'),
          ),
          const SizedBox(height: 36),
          const Text(
            'Paddle Duel',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('Points to win', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 10),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => SegmentedButton<int>(
              segments: [
                for (final score in AppSettings.allowedScores)
                  ButtonSegment(value: score, label: Text('$score')),
              ],
              selected: {widget.settings.winningScore},
              onSelectionChanged: saving
                  ? null
                  : (selection) async {
                      SoundEffects.play(SoundEffect.click);
                      await widget.settings.setWinningScore(selection.single);
                    },
            ),
          ),
        ],
      ),
    ),
  );
}
