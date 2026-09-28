import 'package:flutter/material.dart';

import '../calc/prayer_calculator.dart';
import '../calc/time_format.dart';

/// Darimi vs Karachi/Mujahid times; tap a row to see why they differ.
class PrayerTable extends StatelessWidget {
  const PrayerTable({super.key, required this.rows});

  final List<PrayerRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final head = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(flex: 4, child: Text('Prayer', style: head)),
                Expanded(
                  flex: 3,
                  child: Text('Darimi',
                      style: head?.copyWith(color: theme.colorScheme.primary)),
                ),
                Expanded(flex: 3, child: Text('Karachi / Mujahid', style: head)),
                Expanded(
                  flex: 3,
                  child: Text('Δ', style: head, textAlign: TextAlign.end),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows) _PrayerTile(row: row),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Tap a prayer to see why. Δ = Darimi − Karachi. '
              'Prayer times round up to the minute, sunrise rounds down.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrayerTile extends StatefulWidget {
  const _PrayerTile({required this.row});

  final PrayerRow row;

  @override
  State<_PrayerTile> createState() => _PrayerTileState();
}

class _PrayerTileState extends State<_PrayerTile> {
  bool _open = false;

  String _time(double? v) =>
      v == null ? '—' : hm(v, roundUp: widget.row.prayer.roundUp);

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final theme = Theme.of(context);
    final exact = 'Darimi ${row.darimi == null ? '—' : hms(row.darimi!)}  ·  '
        'Karachi ${row.karachi == null ? '—' : hms(row.karachi!)}';

    return InkWell(
      onTap: () => setState(() => _open = !_open),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(row.prayer.label,
                              style: theme.textTheme.titleSmall),
                        ),
                        Icon(
                          _open ? Icons.expand_less : Icons.expand_more,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _time(row.darimi),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      _time(row.karachi),
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _DiffChip(seconds: row.diffSeconds),
                    ),
                  ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(row.rule, style: theme.textTheme.labelSmall),
                    ),
                    Text(exact, style: theme.textTheme.bodySmall),
                  ],
                ),
                const SizedBox(height: 6),
                Text(row.reason, style: theme.textTheme.bodySmall),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  const _DiffChip({required this.seconds});

  final int? seconds;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = seconds;
    final (bg, fg, label) = switch (s) {
      null => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, '—'),
      0 => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant, 'same'),
      < 0 => (scheme.tertiaryContainer, scheme.onTertiaryContainer, signedDiff(s)),
      _ => (scheme.secondaryContainer, scheme.onSecondaryContainer, signedDiff(s)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
      ),
    );
  }
}
