class EmailValidator {
  static bool validate(String email) {
    final trimmed = email.trim();
    // Accept standard emails and .local TLD (length 2 to 6)
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,6}$').hasMatch(trimmed);
  }
}
