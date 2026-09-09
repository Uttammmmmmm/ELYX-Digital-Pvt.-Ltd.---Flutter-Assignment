/// Human-readable durations.
///
/// Hand-rolled rather than via `intl`: the GitHub spec's dependency list has
/// no intl, and these two cases do not justify adding a localisation stack.
/// If the app is ever localised, replace these with `DateFormat`/plural rules.
library;

/// Formats time remaining, e.g. `42m 30s`, `2h 05m`, `now`.
///
/// Used for the rate-limit countdown, so it degrades to `now` rather than
/// showing a negative value when the reset time passes mid-tick.
String formatCountdown(Duration d) {
  if (d.inSeconds <= 0) return 'now';
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) {
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
}

/// Formats age, e.g. `just now`, `5 minutes ago`, `3 hours ago`.
///
/// Used for the "showing saved data" banner.
String formatAge(Duration d) {
  if (d.inSeconds < 45) return 'just now';
  if (d.inMinutes < 60) {
    final int m = d.inMinutes.clamp(1, 59);
    return '$m ${m == 1 ? 'minute' : 'minutes'} ago';
  }
  if (d.inHours < 24) {
    final int h = d.inHours;
    return '$h ${h == 1 ? 'hour' : 'hours'} ago';
  }
  final int days = d.inDays;
  return '$days ${days == 1 ? 'day' : 'days'} ago';
}
