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

/// Formats a wall-clock time as `4:35 PM`.
///
/// Hand-rolled for the same reason as the rest of this file: no `intl` in the
/// dependency list. A localised build would replace this with
/// `DateFormat.jm()`, which also respects the device's 24-hour preference --
/// this does not, and that is the known limitation.
String formatClockTime(DateTime time) {
  final int hour24 = time.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
}
