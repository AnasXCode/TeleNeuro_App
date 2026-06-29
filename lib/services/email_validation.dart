/// Shared Gmail validation for patient/doctor login and sign-up screens.
class EmailValidation {
  static const String gmailOnlyMessage = 'Only @gmail.com emails are allowed';
  static const String letterRequiredMessage =
      'Email must contain at least one letter before @ (e.g. john@gmail.com)';
  static const String localPartLengthMessage =
      'The email username (before @) must be between 6 and 30 characters long.';

  static const int localPartMinLength = 6;
  static const int localPartMaxLength = 30;

  static final RegExp _gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');

  /// Returns null when valid; otherwise returns an error message.
  static String? validateGmail(String email) {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;

    if (!_gmailRegex.hasMatch(trimmed)) {
      return gmailOnlyMessage;
    }

    final localPart = trimmed.split('@').first;
    if (!RegExp(r'[a-zA-Z]').hasMatch(localPart)) {
      return letterRequiredMessage;
    }

    return null;
  }

  /// Sign-up validation: [validateGmail] plus local-part length (6–30).
  static String? validateGmailForSignup(String email) {
    final baseError = validateGmail(email);
    if (baseError != null) return baseError;

    final trimmed = email.trim();
    if (trimmed.isEmpty) return null;

    final localPart = trimmed.split('@').first;
    if (localPart.length < localPartMinLength || localPart.length > localPartMaxLength) {
      return localPartLengthMessage;
    }

    return null;
  }
}
