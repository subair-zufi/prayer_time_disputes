import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../calc/prayer_calculator.dart';

/// Wraps one log line to [width] characters.
///
/// Lines that fit are returned unchanged, so columns stay aligned on wide
/// screens. Longer lines break at column gaps (two or more spaces) first,
/// and only split a column by words when it is wider than a whole line.
/// [first] starts the first line and [next] indents the following ones.
List<String> wrapLogText(
  String text,
  int width, {
  String first = '',
  String next = '    ',
}) {
  if (first.length + text.length <= width || width <= next.length + 8) {
    return ['$first$text'];
  }
  final lead = RegExp(r'^ *').stringMatch(text)!;
  final out = <String>[];
  var line = '$first$lead';
  var start = line.length;
  bool empty() => line.length == start;
  void push() {
    out.add(line.trimRight());
    line = next;
    start = next.length;
  }

  for (final column in text.substring(lead.length).split(RegExp(r' {2,}'))) {
    if (column.isEmpty) continue;
    final gap = empty() ? '' : '  ';
    if (line.length + gap.length + column.length <= width) {
      line += gap + column;
      continue;
    }
    if (!empty()) push();
    if (line.length + column.length <= width) {
      line += column;
      continue;
    }
    for (final word in column.split(' ')) {
      if (!empty() && line.length + 1 + word.length > width) push();
      line += empty() ? word : ' $word';
    }
  }
  if (!empty()) out.add(line.trimRight());
  return out;
}

/// The step-by-step calculation log, in a monospace block that wraps to
/// the screen width.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.result});

  final CalcResult result;

  static const _padding = 12.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.robotoMono(
      fontSize: 12,
      height: 1.45,
      color: scheme.onSurface,
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: Icon(Icons.receipt_long_outlined, color: scheme.primary),
            title: const Text('Calculation log'),
            subtitle: const Text('Every step, with the numbers used'),
            trailing: IconButton(
              tooltip: 'Copy log',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: result.logText));
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Log copied')));
                }
              },
            ),
          ),
          const Divider(height: 1),
          Container(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            padding: const EdgeInsets.all(_padding),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columns = _columns(context, mono, constraints.maxWidth);
                return SelectableText.rich(
                  TextSpan(style: mono, children: _spans(scheme, columns)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// How many monospace characters fit in [width].
  static int _columns(BuildContext context, TextStyle mono, double width) {
    final scaler = MediaQuery.textScalerOf(context);
    final painter = TextPainter(
      text: TextSpan(text: '0000000000', style: mono),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    // Roboto Mono is 0.6 em wide; never assume narrower, in case a
    // fallback font is measured before the web font has loaded.
    final charWidth = math.max(
      painter.width / 10,
      scaler.scale(mono.fontSize!) * 0.6,
    );
    painter.dispose();
    return (width / charWidth).floor() - 1;
  }

  List<TextSpan> _spans(ColorScheme scheme, int columns) {
    final spans = <TextSpan>[];
    for (final l in result.log) {
      switch (l.kind) {
        case LogKind.header:
          final text = wrapLogText('== ${l.text} ==', columns, next: '   ');
          spans.add(
            TextSpan(
              text: '${spans.isEmpty ? '' : '\n'}${text.join('\n')}\n',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          );
        case LogKind.line:
          spans.add(
            TextSpan(text: '${wrapLogText(l.text, columns).join('\n')}\n'),
          );
        case LogKind.note:
          final text = wrapLogText(
            l.text,
            columns,
            first: '   » ',
            next: '     ',
          );
          spans.add(
            TextSpan(
              text: '${text.join('\n')}\n',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
      }
    }
    return spans;
  }
}
