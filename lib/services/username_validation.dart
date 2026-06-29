/// Shared username validation for patient/doctor sign-up screens.
class UsernameValidation {
  static const String lengthMessage =
      'Username must be between 3 and 30 characters long.';

  static const int minLength = 3;
  static const int maxLength = 30;

  /// Returns null when valid; otherwise returns an error message.
  static String? validate(String username) {
    final trimmed = username.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.length < minLength || trimmed.length > maxLength) {
      return lengthMessage;
    }

    return null;
  }
}
