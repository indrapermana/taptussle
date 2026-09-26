import 'package:flutter/material.dart';

import '../../app/tap_tussle_theme.dart';
import '../../core/app_settings.dart';
import '../../core/game_record_repository.dart';
import '../../core/mini_game.dart';

class GameRecordBestsPanel extends StatelessWidget {
  const GameRecordBestsPanel({
    required this.game,
    required this.settings,
    this.now,
    super.key,
  });

  final MiniGame game;
  final AppSettings settings;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final definition = game.recordDefinition!;
    final preferences = settings.preferencesFor(game.id);
    final variant = game.recordVariantFor(preferences);
    final key = GameRecordKey(
      gameId: game.id,
      recordType: definition.recordType,
      variant: variant,
    );
    return ListenableBuilder(
      listenable: settings.recordRepository,
      builder: (context, _) {
        final bests = settings.recordRepository.bests(
          key: key,
          definition: definition,
          now: now,
        );
        return ArcadePanel(
          key: const ValueKey('game-record-bests'),
          accent: TapTussleColors.gold,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.emoji_events_rounded,
                    color: TapTussleColors.gold,
                  ),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'YOUR BEST',
                      style: TextStyle(
                        fontFamily: 'Lilita One',
                        color: TapTussleColors.gold,
                        fontSize: 20,
                        letterSpacing: .7,
                      ),
                    ),
                  ),
                  Text(
                    variant.toUpperCase(),
                    style: const TextStyle(
                      color: TapTussleColors.mutedText,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .8,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _BestColumn(
                      label: 'DAILY',
                      best: bests.daily,
                      definition: definition,
                    ),
                  ),
                  const _BestDivider(),
                  Expanded(
                    child: _BestColumn(
                      label: 'WEEKLY',
                      best: bests.weekly,
                      definition: definition,
                    ),
                  ),
                  const _BestDivider(),
                  Expanded(
                    child: _BestColumn(
                      label: 'OVERALL',
                      best: bests.overall,
                      definition: definition,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BestColumn extends StatelessWidget {
  const _BestColumn({
    required this.label,
    required this.best,
    required this.definition,
  });

  final String label;
  final RankedGameRecord? best;
  final GameRecordDefinition definition;

  @override
  Widget build(BuildContext context) {
    final record = best?.record;
    final primary = definition.primaryMetric;
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: TapTussleColors.mutedText,
            fontSize: 10,
            fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ),
        ),
        const SizedBox(height: 7),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            record == null
                ? '—'
                : _formatMetric(primary, record.metrics[primary.id]!),
            key: ValueKey('record-$label-primary'),
            style: const TextStyle(
              fontFamily: 'Lilita One',
              color: Colors.white,
              fontSize: 23,
            ),
          ),
        ),
        Text(
          primary.label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: TapTussleColors.mutedText,
            fontSize: 10,
          ),
        ),
        if (record != null)
          for (final metric in definition.tieBreakers) ...[
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${metric.label} ${_formatMetric(metric, record.metrics[metric.id]!)}',
                style: const TextStyle(
                  color: TapTussleColors.text,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
      ],
    );
  }
}

class _BestDivider extends StatelessWidget {
  const _BestDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 72,
    margin: const EdgeInsets.symmetric(horizontal: 9),
    color: TapTussleColors.panelBorder,
  );
}

String _formatMetric(RecordMetricDefinition definition, num value) =>
    switch (definition.format) {
      RecordMetricFormat.integer => value.round().toString(),
      RecordMetricFormat.duration => _formatDuration(value.round()),
    };

String _formatDuration(int milliseconds) {
  final duration = Duration(milliseconds: milliseconds);
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  if (duration.inMinutes > 0) {
    return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
  }
  final tenths = (milliseconds / 100).round();
  return '${(tenths / 10).toStringAsFixed(1)}s';
}
