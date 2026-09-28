import 'package:flutter/material.dart';

import '../calc/prayer_calculator.dart';
import '../calc/time_format.dart';

/// Sunni, Karachi and Mujahid times side by side; tap a row for details.
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
                for (final m in Method.values)
                  Expanded(
                    flex: 3,
                    child: Text(
                      m.label,
                      style:
                          m == Method.sunni
                              ? head?.copyWith(color: theme.colorScheme.primary)
                              : head,
                    ),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          for (final row in rows) _PrayerTile(row: row),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Text(
              'Small figures: later (+) or earlier (−) than Sunni. Tap a '
              'prayer for each method\'s rule and source. Prayer times round '
              'up to the minute, sunrise rounds down.',
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

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final theme = Theme.of(context);
    const tabular = [FontFeature.tabularFigures()];

    String time(Method m) {
      final t = row[m].time;
      return t == null ? '—' : hm(t, roundUp: row.prayer.roundUp);
    }

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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 4,
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.prayer.label,
                            style: theme.textTheme.titleSmall,
                          ),
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
                      time(Method.sunni),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                        fontFeatures: tabular,
                      ),
                    ),
                  ),
                  for (final m in [Method.karachi, Method.mujahid])
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            time(m),
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontFeatures: tabular,
                            ),
                          ),
                          const SizedBox(height: 2),
                          _DiffChip(seconds: row.diffFromSunni(m)),
                        ],
                      ),
                    ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 8),
                for (final m in Method.values)
                  _MethodDetail(row: row, method: m),
                if (row.note != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      row.note!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One method's rule, exact time and reason inside an opened row.
class _MethodDetail extends StatelessWidget {
  const _MethodDetail({required this.row, required this.method});

  final PrayerRow row;
  final Method method;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mt = row[method];
    final diff = row.diffFromSunni(method);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                method.label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color:
                      method == Method.sunni ? theme.colorScheme.primary : null,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(mt.rule, style: theme.textTheme.labelSmall),
              ),
              Text(
                mt.time == null ? '—' : hms(mt.time!),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (method != Method.sunni && diff != null && diff != 0)
                Text(
                  signedDiff(diff),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            mt.reason[0].toUpperCase() + mt.reason.substring(1),
            style: theme.textTheme.bodySmall,
          ),
        ],
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
      < 0 => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
        signedDiff(s),
      ),
      _ => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
        signedDiff(s),
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
