/// Standard helper to format and resolve subject display names.
///
/// Fallback hierarchy:
/// 1. [subjectName] if non-null and not blank.
/// 2. [subjectCode] if non-null and not blank.
/// 3. Fallback default ('Subject').
///
/// Internal UUIDs in [subjectId] are ignored and never displayed as subject names.
String displaySubjectName({
  String? subjectName,
  String? subjectCode,
  String? subjectId,
}) {
  if (subjectName != null && subjectName.trim().isNotEmpty) {
    return subjectName.trim();
  }
  if (subjectCode != null && subjectCode.trim().isNotEmpty) {
    return subjectCode.trim();
  }
  return 'Subject';
}
