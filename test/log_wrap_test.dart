import 'package:darimi_prayer_times/calc/prayer_calculator.dart';
import 'package:darimi_prayer_times/ui/log_view.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  String squash(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  test('lines that fit are left unchanged', () {
    const line = 'Sunni           a = −20.000°  cos H = −0.34209';
    expect(wrapLogText(line, 80), [line]);
  });

  test('long lines break at column gaps with an indent', () {
    const line =
        'Sunni           a = −20.000°  cos H = −0.34209  '
        'H = 110.004°  T = 7:20:01  → 04:58:10';
    final out = wrapLogText(line, 43);
    expect(out, [
      'Sunni  a = −20.000°  cos H = −0.34209',
      '    H = 110.004°  T = 7:20:01  → 04:58:10',
    ]);
  });

  test('notes keep their prefix and indent continuation lines', () {
    final out = wrapLogText(
      'Rafi argues true dawn is nearer 16°–16.5° (Dr. Ilyas).',
      30,
      first: '   » ',
      next: '     ',
    );
    expect(out.first, startsWith('   » '));
    expect(out.skip(1), everyElement(startsWith('     ')));
  });

  test('every log line fits a phone width and no text is lost', () {
    final result = calculatePrayerTimes(
      CalcInput(
        date: DateTime(2026, 9, 28),
        latitude: 11.723456514344237,
        longitude: 75.63203559650596,
        timezone: 5.5,
        elevation: 57,
      ),
    );
    for (final width in [38, 43, 60]) {
      for (final l in result.log) {
        final out = wrapLogText(l.text, width);
        for (final line in out) {
          // Only a single word longer than the width may overflow.
          if (line.length > width) expect(line.trim().contains(' '), isFalse);
        }
        expect(squash(out.join(' ')), squash(l.text));
      }
    }
  });
}
