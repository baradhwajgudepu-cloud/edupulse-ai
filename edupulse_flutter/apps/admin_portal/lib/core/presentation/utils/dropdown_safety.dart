import 'package:flutter/material.dart';

/// Reusable option model with code and display label.
class DropdownOption<T> {
  final T value;
  final String label;
  final Widget? customWidget;

  const DropdownOption({
    required this.value,
    required this.label,
    this.customWidget,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DropdownOption<T> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Centralized utility for crash-proof DropdownButton / DropdownButtonFormField rendering.
///
/// Prevents the Flutter framework assertion:
/// "There should be exactly one item with [DropdownButton]'s value: X.
/// Either zero or 2 or more [DropdownMenuItem]s were detected with the same value."
class DropdownSafety {
  DropdownSafety._();

  /// Canonical attendance reasons supported by backend schema and PostgreSQL enum.
  static const String reasonUnknown = 'UNKNOWN';
  static const String reasonSick = 'SICK';
  static const String reasonPersonal = 'PERSONAL';
  static const String reasonSports = 'SPORTS';
  static const String reasonOfficial = 'OFFICIAL';

  /// Standard user-facing labels for canonical attendance reasons.
  static const Map<String, String> attendanceReasonLabels = {
    reasonUnknown: 'Not Specified',
    reasonSick: 'Sick / Medical',
    reasonPersonal: 'Personal / Family',
    reasonSports: 'Sports / Activities',
    reasonOfficial: 'Official School Duty',
  };

  /// Status-specific allowed reasons.
  static const Map<String, List<String>> statusAllowedReasons = {
    'PRESENT': [reasonUnknown],
    'ABSENT': [reasonUnknown, reasonSick, reasonPersonal],
    'LATE': [reasonUnknown, reasonPersonal, reasonOfficial],
    'HALF_DAY': [reasonUnknown, reasonSick, reasonPersonal, reasonOfficial],
    'EXCUSED': [reasonUnknown, reasonSick, reasonSports, reasonOfficial, reasonPersonal],
  };

  /// Normalizes any raw attendance reason string into a canonical enum value.
  /// Handles case differences ('sick', 'Sick', 'SICK'), whitespace, and legacy synonyms ('SICKNESS', 'MEDICAL_LEAVE').
  static String normalizeAttendanceReason(String? raw) {
    if (raw == null) return reasonUnknown;
    final trimmed = raw.trim().toUpperCase();
    if (trimmed.isEmpty) return reasonUnknown;

    switch (trimmed) {
      case 'SICK':
      case 'SICKNESS':
      case 'ILLNESS':
      case 'MEDICAL':
      case 'MEDICAL_LEAVE':
        return reasonSick;
      case 'PERSONAL':
      case 'FAMILY':
      case 'FAMILY_EMERGENCY':
      case 'APPOINTMENT':
      case 'TRANSPORT_DELAY':
      case 'TRAFFIC':
        return reasonPersonal;
      case 'SPORTS':
      case 'ATHLETICS':
      case 'EVENT':
      case 'TOURNAMENT':
        return reasonSports;
      case 'OFFICIAL':
      case 'OFFICIAL_DUTY':
      case 'SCHOOL_DUTY':
      case 'COMPETITION':
        return reasonOfficial;
      case 'UNKNOWN':
      case 'UNEXCUSED':
      case 'OTHER':
      default:
        return reasonUnknown;
    }
  }

  /// Returns user-friendly display label for canonical attendance reason.
  static String getReasonLabel(String reasonCode) {
    final canonical = normalizeAttendanceReason(reasonCode);
    return attendanceReasonLabels[canonical] ?? 'Other / Not Specified';
  }

  /// Returns the allowed canonical reasons for an attendance status.
  static List<String> getReasonsForStatus(String status) {
    final upperStatus = status.trim().toUpperCase();
    return statusAllowedReasons[upperStatus] ?? [reasonUnknown, reasonSick, reasonPersonal, reasonSports, reasonOfficial];
  }

  /// Deduplicates items by a key extractor function while preserving insertion order.
  /// If [keyNormalizer] is provided, it normalizes keys for comparison (e.g. trimming or casing).
  static List<T> deduplicateBy<T, K>({
    required Iterable<T> items,
    required K Function(T item) valueExtractor,
    K Function(K rawKey)? keyNormalizer,
  }) {
    final seen = <K>{};
    final result = <T>[];
    for (final item in items) {
      var key = valueExtractor(item);
      if (keyNormalizer != null) {
        key = keyNormalizer(key);
      }
      if (seen.add(key)) {
        result.add(item);
      }
    }
    return result;
  }

  /// Sanitizes a list of [DropdownMenuItem]s so that every item value is unique.
  /// If duplicate values (including duplicate nulls) exist, only the first occurrence is kept.
  static List<DropdownMenuItem<T>> safeMenuItems<T>({
    required Iterable<DropdownMenuItem<T>> items,
  }) {
    final seen = <T?>{};
    final result = <DropdownMenuItem<T>>[];
    for (final item in items) {
      if (seen.add(item.value)) {
        result.add(item);
      }
    }
    return result;
  }

  /// Validates [selectedValue] against [validValues].
  ///
  /// - If [selectedValue] is null: returns [fallback] (default null).
  /// - If [selectedValue] exists in [validValues]: returns [selectedValue].
  /// - If [selectedValue] is NOT in [validValues]: returns [fallback] (default null).
  ///
  /// This prevents Flutter from asserting when the selected value is missing from the items list.
  static T? safeValue<T>({
    required T? selectedValue,
    required Iterable<T?> validValues,
    T? fallback,
  }) {
    if (selectedValue == null) return fallback;
    final set = validValues.toSet();
    if (set.contains(selectedValue)) {
      return selectedValue;
    }
    return fallback;
  }

  /// Convenience builder that transforms an arbitrary collection of data [D]
  /// into a deduplicated, guaranteed-safe list of [DropdownMenuItem<T>].
  static List<DropdownMenuItem<T>> buildSafeItems<T, D>({
    required Iterable<D> data,
    required T Function(D item) valueExtractor,
    required Widget Function(D item) childBuilder,
    DropdownMenuItem<T>? leadingItem,
  }) {
    final items = <DropdownMenuItem<T>>[];
    if (leadingItem != null) {
      items.add(leadingItem);
    }
    for (final d in data) {
      items.add(
        DropdownMenuItem<T>(
          value: valueExtractor(d),
          child: childBuilder(d),
        ),
      );
    }
    return safeMenuItems(items: items);
  }
}
