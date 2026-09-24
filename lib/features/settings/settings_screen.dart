import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_settings.dart';
import '../../core/haptic_service.dart';
import '../../core/sound_service.dart';
import 'graphics_preview_screen.dart';
import 'legal_document_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double volume;
  late bool vibrationEnabled;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    volume = widget.settings.effectsVolume;
    vibrationEnabled = widget.settings.vibrationEnabled;
  }

  Future<void> _saveVibration(bool value) async {
    setState(() => saving = true);
    try {
      await widget.settings.setVibrationEnabled(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save vibration setting.')),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _openLegal(LegalDocument document) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(document: document),
    ),
  );

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
            'Graphics',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Resolution controls the number of pixels rendered before the game is displayed. FPS controls how often that image is refreshed; match timing stays the same.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
          const SizedBox(height: 16),
          ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) => _GraphicsPreview(
              resolution: widget.settings.resolution,
              frameRate: widget.settings.frameRate,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            key: const ValueKey('open-graphics-preview'),
            onPressed: () {
              SoundEffects.play(SoundEffect.click);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      GraphicsPreviewScreen(settings: widget.settings),
                ),
              );
            },
            icon: const Icon(Icons.compare_rounded),
            label: const Text('Compare and change graphics'),
          ),
          const SizedBox(height: 36),
          const Text(
            'Vibration',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Vibration feedback'),
            subtitle: const Text('Feel paddle hits during Paddle Duel.'),
            value: vibrationEnabled,
            onChanged: saving
                ? null
                : (value) {
                    setState(() => vibrationEnabled = value);
                    HapticEffects.setEnabled(value);
                    _saveVibration(value);
                  },
          ),
          OutlinedButton.icon(
            key: const ValueKey('preview-vibration'),
            onPressed: vibrationEnabled ? HapticEffects.preview : null,
            icon: const Icon(Icons.vibration_rounded),
            label: const Text('Test vibration'),
          ),
          const SizedBox(height: 36),
          const Text(
            'Match rules',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Points to win in score-based games',
            style: TextStyle(color: Colors.white70),
          ),
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
          const SizedBox(height: 36),
          const Text(
            'Legal',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Terms of Use'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openLegal(LegalDocument.terms),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Privacy Policy'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => _openLegal(LegalDocument.privacy),
          ),
          const SizedBox(height: 28),
          Center(
            child: FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final info = snapshot.data;
                if (info == null) {
                  return const Text(
                    'Version',
                    style: TextStyle(color: Colors.white60),
                  );
                }
                return Text(
                  info.buildSignature.isEmpty
                      ? info.version
                      : '${info.version} ${info.buildSignature}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, height: 1.5),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _GraphicsPreview extends StatelessWidget {
  const _GraphicsPreview({required this.resolution, required this.frameRate});
  final ResolutionPreset resolution;
  final FrameRatePreset frameRate;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFF142333),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF304253)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _PreviewColumn(
              title: 'Render target',
              value: '${(resolution.renderScale * 100).round()}%',
              caption: switch (resolution) {
                ResolutionPreset.economy => 'Fewer pixels; lighter GPU load',
                ResolutionPreset.balanced => 'Three quarters of native pixels',
                ResolutionPreset.native => 'Full device pixel density',
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _PreviewColumn(
              title: 'Frame refresh',
              value: '${frameRate.framesPerSecond} FPS',
              caption: frameRate == FrameRatePreset.fps30
                  ? 'One new frame about every 33 ms'
                  : 'One new frame about every 17 ms',
            ),
          ),
        ],
      ),
    ),
  );
}

class _PreviewColumn extends StatelessWidget {
  const _PreviewColumn({
    required this.title,
    required this.value,
    required this.caption,
  });
  final String title;
  final String value;
  final String caption;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      Text(
        caption,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ],
  );
}
