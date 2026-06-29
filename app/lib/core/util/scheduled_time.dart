/// Combines a date-only [date] with an `"HH:mm"` [time] string into an absolute
/// local DateTime (the auto-start anchor for a trip, M12). Tolerant of malformed
/// input — falls back to midnight on [date].
DateTime combineDateAndTime(DateTime date, String time) {
  final parts = time.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return DateTime(date.year, date.month, date.day, h, m);
}
