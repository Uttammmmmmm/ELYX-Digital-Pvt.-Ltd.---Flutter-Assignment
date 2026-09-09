library;

String formatCountdown(Duration d) {
  if (d.inSeconds <= 0) return 'now';
  if (d.inMinutes < 1) return '${d.inSeconds}s';
  if (d.inHours < 1) {
    return '${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s';
  }
  return '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
}

String formatClockTime(DateTime time) {
  final int hour24 = time.hour;
  final int hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour12:$minute ${hour24 < 12 ? 'AM' : 'PM'}';
}
