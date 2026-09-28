import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../calc/prayer_calculator.dart';

/// The step-by-step calculation log, in a monospace block.
class LogView extends StatelessWidget {
  const LogView({super.key, required this.result});

  final CalcResult result;

  /// Wraps long notes so the block only scrolls sideways for formula lines.
  static List<String> _wrap(String text, int width) {
    final lines = <String>[];
    var current = '';
    for (final word in text.split(' ')) {
      if (current.isNotEmpty && current.length + 1 + word.length > width) {
        lines.add(current);
        current = word;
      } else {
        current = current.isEmpty ? word : '$current $word';
      }
    }
    if (current.isNotEmpty) lines.add(current);
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mono = GoogleFonts.robotoMono(
      fontSize: 12,
      height: 1.45,
      color: scheme.onSurface,
    );

    final spans = <TextSpan>[];
    for (final l in result.log) {
      switch (l.kind) {
        case LogKind.header:
          spans.add(
            TextSpan(
              text: '${spans.isEmpty ? '' : '\n'}== ${l.text} ==\n',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          );
        case LogKind.line:
          spans.add(TextSpan(text: '${l.text}\n'));
        case LogKind.note:
          final wrapped = _wrap(l.text, 72);
          spans.add(
            TextSpan(
              text: '   » ${wrapped.join('\n     ')}\n',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
      }
    }

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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(12),
              child: SelectableText.rich(
                TextSpan(style: mono, children: spans),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
