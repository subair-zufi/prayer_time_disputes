/// Helpers for turning decimal hours into clock strings.
library;

String _two(int n) => n.toString().padLeft(2, '0');

/// Decimal hours → whole seconds (rounded).
int toSeconds(double hours) => (hours * 3600).round();

/// Clock time with seconds, e.g. 04:58:10.
String hms(double hours) {
  final s = toSeconds(hours) % 86400;
  return '${_two(s ~/ 3600)}:${_two(s % 3600 ~/ 60)}:${_two(s % 60)}';
}

/// Clock time rounded to a minute, e.g. 04:59.
/// Prayer start times round up (safe side); sunrise rounds down.
String hm(double hours, {required bool roundUp}) {
  final s = toSeconds(hours);
  final minutes = (roundUp ? (s + 59) ~/ 60 : s ~/ 60) % 1440;
  return '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';
}

/// A span of hours as h:mm:ss, e.g. 7:20:01.
String span(double hours) {
  final s = toSeconds(hours.abs());
  return '${s ~/ 3600}:${_two(s % 3600 ~/ 60)}:${_two(s % 60)}';
}

/// Signed difference in seconds, e.g. −8m 10s, +1m 40s, 0.
String signedDiff(int seconds) {
  if (seconds == 0) return '0';
  final sign = seconds < 0 ? '−' : '+';
  final a = seconds.abs();
  return a >= 60 ? '$sign${a ~/ 60}m ${_two(a % 60)}s' : '$sign${a}s';
}

/// Number with a proper minus sign and fixed decimals.
String fmt(double v, [int decimals = 4]) {
  final s = v.abs().toStringAsFixed(decimals);
  return v < 0 && double.parse(s) != 0 ? '−$s' : s;
}
