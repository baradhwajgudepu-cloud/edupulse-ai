/// Safe numeric deserialization utilities for EduPulse AI.
/// Prevents runtime [TypeError]s when numeric or Decimal fields are returned
/// as Strings (e.g. "500.00"), integers, or doubles from the backend.
library;

double safeParseDouble(dynamic value, [double defaultValue = 0.0]) {
  if (value == null) return defaultValue;
  if (value is num) return value.toDouble();
  if (value is String) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return defaultValue;
    return double.tryParse(cleaned) ?? defaultValue;
  }
  return defaultValue;
}

int safeParseInt(dynamic value, [int defaultValue = 0]) {
  if (value == null) return defaultValue;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return defaultValue;
    final parsedInt = int.tryParse(cleaned);
    if (parsedInt != null) return parsedInt;
    final parsedDouble = double.tryParse(cleaned);
    if (parsedDouble != null) return parsedDouble.toInt();
  }
  return defaultValue;
}
