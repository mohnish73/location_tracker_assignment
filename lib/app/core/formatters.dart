String _two(int value) => value.toString().padLeft(2, '0');

/// `2026-10-13 14:05:09` in local time.
String formatTimestamp(int epochMs) {
  final t = DateTime.fromMillisecondsSinceEpoch(epochMs);
  return '${t.year}-${_two(t.month)}-${_two(t.day)} '
      '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';
}

String formatCoordinate(double value) => value.toStringAsFixed(6);

String formatAccuracy(double metres) => '±${metres.toStringAsFixed(metres < 10 ? 1 : 0)} m';

String formatInterval(Duration interval) {
  if (interval.inSeconds < 60) return '${interval.inSeconds} s';
  if (interval.inMinutes < 60) return '${interval.inMinutes} min';
  return '${interval.inHours} h';
}
