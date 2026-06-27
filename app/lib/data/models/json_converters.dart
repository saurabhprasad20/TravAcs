// Tolerant JSON helpers for values PostgREST may encode inconsistently.

/// Parses a Postgres `numeric` which may arrive as a JSON number or a string.
double doubleFromJson(Object? value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}
