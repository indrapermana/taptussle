import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';

enum LegalDocument { terms, privacy }

class LegalDocumentScreen extends StatelessWidget {
  const LegalDocumentScreen({required this.document, super.key});

  final LegalDocument document;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = document == LegalDocument.privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(isPrivacy ? 'Privacy Policy' : 'Terms of Use'),
      ),
      body: TapTussleBackdrop(
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                children: [
                  ArcadePanel(
                    accent: isPrivacy
                        ? TapTussleColors.electricBlue
                        : TapTussleColors.gold,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          isPrivacy
                              ? Icons.shield_rounded
                              : Icons.gavel_rounded,
                          color: isPrivacy
                              ? TapTussleColors.electricBlue
                              : TapTussleColors.gold,
                          size: 38,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isPrivacy ? 'Privacy Policy' : 'Terms of Use',
                          style: const TextStyle(
                            fontFamily: 'Lilita One',
                            fontSize: 30,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Effective 24 September 2026',
                          style: TextStyle(color: TapTussleColors.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (isPrivacy) ...const [
                    _LegalSection(
                      title: 'Your data stays on your device',
                      body:
                          'TapTussle has no account, advertising, analytics, or online gameplay. Game preferences such as favourites, game setup, volume, and vibration are stored locally on your device.',
                    ),
                    _LegalSection(
                      title: 'No collection or sharing',
                      body:
                          'The app does not collect, transmit, sell, or share personal information. Removing the app or clearing its data removes its locally stored preferences.',
                    ),
                    _LegalSection(
                      title: 'Changes',
                      body:
                          'If a future version adds features that handle personal data, this policy will be updated before those features are released.',
                    ),
                  ] else ...const [
                    _LegalSection(
                      title: 'Using TapTussle',
                      body:
                          'TapTussle is an offline, same-device game collection. Use it lawfully and safely, and take breaks when needed.',
                    ),
                    _LegalSection(
                      title: 'Availability',
                      body:
                          'The app is provided as available. Game rules, features, and supported devices may change in future versions.',
                    ),
                    _LegalSection(
                      title: 'Contact',
                      body:
                          'Before public release, this section will be updated with a support contact and the final publisher details.',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LegalSection extends StatelessWidget {
  const _LegalSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: ArcadePanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontFamily: 'Lilita One', fontSize: 20),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: const TextStyle(
              color: TapTussleColors.mutedText,
              height: 1.55,
            ),
          ),
        ],
      ),
    ),
  );
}
