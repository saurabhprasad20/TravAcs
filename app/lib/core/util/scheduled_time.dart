/// Combines a date-only [date] with an `"HH:mm"` [time] string into an absolute
/// local DateTime (the auto-start anchor for a trip, M12). Tolerant of malformed
/// input — falls back to midnight on [date].
DateTime combineDateAndTime(DateTime date, String time) {
  final parts = time.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, h, m);
}

/// Formats a 24-hour `"HH:mm"` [time] string as a 12-hour clock label
/// (e.g. `"14:30"` → `"2:30 PM"`). Falls back to the original string if it
/// cannot be parsed. Used everywhere a trip time is shown so Users and
/// TravAcsers always read a familiar AM/PM time.
String formatTime12h(String time) {
  final parts = time.split(':');
  if (parts.isEmpty) return time;
  final h = int.tryParse(parts[0]);
  final m = parts.length > 1 ? int.tryParse(parts[1]) : 0;
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return time;
  final period = h < 12 ? 'AM' : 'PM';
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  final mm = m.toString().padLeft(2, '0');
  return '$hour12:$mm $period';
}
