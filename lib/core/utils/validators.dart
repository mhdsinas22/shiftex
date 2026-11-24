class Validators {
  const Validators._();

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp _digitsOnlyRegExp = RegExp(r'^\d+$');
  static final RegExp _hasNumberRegExp = RegExp(r'\d');

  static String? validateFirstName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'First name is required';
    }
    if (trimmed.length < 2) {
      return 'Enter at least 2 characters';
    }
    return null;
  }

  static String? validateLastName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Last name is required';
    }
    return null;
  }

  static String? validateMobileNumber(
    String? value, {
    String countryCode = '+91',
  }) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) {
      return 'Mobile number is required';
    }
    final digits = raw.replaceAll(RegExp(r'[\s\-()]'), '');
    if (!_digitsOnlyRegExp.hasMatch(digits)) {
      return 'Enter a valid numeric mobile number';
    }
    if (countryCode == '+91') {
      if (digits.length != 10 || !RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
        return 'Enter a valid 10-digit mobile number';
      }
    } else if (digits.length < 7 || digits.length > 15) {
      return 'Enter a valid mobile number';
    }
    return null;
  }

  /// Extracts a normalized 10-digit phone number from a stored phone string
  /// (e.g. `+919876543210` -> `9876543210`) for comparison and display.
  static String extractTenDigitPhone(String? value) {
    final trimmed = (value ?? '').trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('+91') && trimmed.length == 13) {
      return trimmed.substring(3);
    }
    if (trimmed.startsWith('91') &&
        trimmed.length == 12 &&
        _digitsOnlyRegExp.hasMatch(trimmed)) {
      return trimmed.substring(2);
    }
    return trimmed;
  }

  /// Strictly validates a 10-digit numeric phone number for Change Phone Number:
  /// - Trims leading/trailing whitespace.
  /// - Rejects empty input.
  /// - Allows only numeric digits (0-9), rejecting letters, spaces, and symbols.
  /// - Requires exactly 10 digits.
  /// - Rejects entering the same phone number as [currentPhoneNumber].
  static String? validateNewPhoneNumber(
    String? value, {
    String? currentPhoneNumber,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Phone number is required';
    }
    if (!_digitsOnlyRegExp.hasMatch(trimmed)) {
      return 'Only numeric digits (0-9) are allowed';
    }
    if (trimmed.length != 10) {
      return 'Phone number must be exactly 10 digits';
    }
    final currentTenDigits = extractTenDigitPhone(currentPhoneNumber);
    if (currentTenDigits.isNotEmpty && trimmed == currentTenDigits) {
      return 'New phone number must be different from your current phone number';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Email address is required';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  /// Validates a new email address for Change Email and ensures it differs
  /// from [currentEmail].
  static String? validateNewEmail(
    String? value, {
    String? currentEmail,
  }) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'New email address is required';
    }
    if (!_emailRegExp.hasMatch(trimmed)) {
      return 'Enter a valid email address';
    }
    final normalizedCurrent = (currentEmail ?? '').trim().toLowerCase();
    if (normalizedCurrent.isNotEmpty &&
        trimmed.toLowerCase() == normalizedCurrent) {
      return 'New email must be different from your current email';
    }
    return null;
  }

  /// Validates that confirmation email matches [newEmail] case-insensitively.
  static String? validateConfirmNewEmail(
    String? value,
    String newEmail,
  ) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Please confirm your new email address';
    }
    if (trimmed.toLowerCase() != newEmail.trim().toLowerCase()) {
      return 'Email addresses do not match';
    }
    return null;
  }

  static String? validateMobileOrEmail(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return 'Mobile number or email is required';
    }
    if (trimmed.contains('@')) {
      return validateEmail(trimmed);
    }
    final cleaned = trimmed.replaceAll(RegExp(r'[\s\-()]'), '');
    final withoutPlus =
        cleaned.startsWith('+91')
            ? cleaned.substring(3)
            : (cleaned.startsWith('91') && cleaned.length == 12
                ? cleaned.substring(2)
                : (cleaned.startsWith('+') ? cleaned.substring(1) : cleaned));
    if (!_digitsOnlyRegExp.hasMatch(withoutPlus) ||
        withoutPlus.length < 7 ||
        withoutPlus.length > 15) {
      return 'Enter a valid mobile number or email address';
    }
    return null;
  }

  static bool hasPasswordMinLength(String value) => value.length >= 8;

  static bool hasPasswordNumber(String value) =>
      _hasNumberRegExp.hasMatch(value);

  static bool isPasswordRuleSatisfied(String value) =>
      hasPasswordMinLength(value) && hasPasswordNumber(value);

  static String? validatePassword(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Password is required';
    }
    if (raw.length < 8) {
      return 'Password must be at least 8 characters';
    }
    if (!_hasNumberRegExp.hasMatch(raw)) {
      return 'Password must contain at least 1 number';
    }
    return null;
  }

  static String? validateLoginPassword(String? value) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  static final RegExp _changePasswordUpperRegExp = RegExp(r'[A-Z]');
  static final RegExp _changePasswordLowerRegExp = RegExp(r'[a-z]');
  static final RegExp _changePasswordSpecialRegExp = RegExp(r'[^\w\s]|_');

  /// Checks whether [value] contains at least one uppercase ASCII letter.
  static bool hasPasswordUppercase(String value) =>
      _changePasswordUpperRegExp.hasMatch(value);

  /// Checks whether [value] contains at least one lowercase ASCII letter.
  static bool hasPasswordLowercase(String value) =>
      _changePasswordLowerRegExp.hasMatch(value);

  /// Checks whether [value] contains at least one special punctuation/symbol character.
  static bool hasPasswordSpecialChar(String value) =>
      _changePasswordSpecialRegExp.hasMatch(value);

  /// Counts how many of the 5 Change Password security rules [value] satisfies.
  static int countSatisfiedStrongPasswordRules(String value) {
    var count = 0;
    if (hasPasswordMinLength(value)) count++;
    if (hasPasswordUppercase(value)) count++;
    if (hasPasswordLowercase(value)) count++;
    if (hasPasswordNumber(value)) count++;
    if (hasPasswordSpecialChar(value)) count++;
    return count;
  }

  /// Returns `true` only when [value] satisfies all 5 strong password criteria.
  static bool isStrongPasswordSatisfied(String value) =>
      countSatisfiedStrongPasswordRules(value) == 5;

  /// Evaluates password strength across 5 discrete levels for Change Password UI.
  static PasswordStrengthLevel evaluatePasswordStrength(String value) {
    if (value.isEmpty) {
      return PasswordStrengthLevel.empty;
    }
    final score = countSatisfiedStrongPasswordRules(value);
    if (!hasPasswordMinLength(value) || score <= 2) {
      return PasswordStrengthLevel.weak;
    }
    if (score == 3) {
      return PasswordStrengthLevel.fair;
    }
    if (score == 4) {
      return PasswordStrengthLevel.good;
    }
    return PasswordStrengthLevel.strong;
  }

  /// Validates the current password input for Change Password.
  static String? validateCurrentPassword(String? value) {
    if ((value ?? '').isEmpty) {
      return 'Current password is required';
    }
    return null;
  }

  /// Validates a password against all 5 strong password security criteria.
  static String? validateStrongPassword(
    String? value, {
    String emptyMessage = 'Password is required',
  }) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return emptyMessage;
    }
    if (!hasPasswordMinLength(raw)) {
      return 'Password must be at least 8 characters';
    }
    if (!hasPasswordUppercase(raw)) {
      return 'Include at least 1 uppercase letter';
    }
    if (!hasPasswordLowercase(raw)) {
      return 'Include at least 1 lowercase letter';
    }
    if (!hasPasswordNumber(raw)) {
      return 'Include at least 1 number';
    }
    if (!hasPasswordSpecialChar(raw)) {
      return 'Include at least 1 special character';
    }
    return null;
  }

  /// Validates the new password against strong password rules and distinctness.
  static String? validateStrongNewPassword(
    String? value, {
    String? currentPassword,
  }) {
    final strongError = validateStrongPassword(
      value,
      emptyMessage: 'New password is required',
    );
    if (strongError != null) {
      return strongError;
    }
    final raw = value ?? '';
    if (currentPassword != null &&
        currentPassword.isNotEmpty &&
        raw == currentPassword) {
      return 'New password must be different from current password';
    }
    return null;
  }

  /// Validates that confirmation matches [newPassword] cleanly.
  static String? validateConfirmNewPassword(
    String? value,
    String newPassword,
  ) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Please confirm your new password';
    }
    if (raw != newPassword) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    final raw = value ?? '';
    if (raw.isEmpty) {
      return 'Please confirm your password';
    }
    if (raw != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length != 6 || !_digitsOnlyRegExp.hasMatch(trimmed)) {
      return 'Please enter the 6-digit verification code';
    }
    return null;
  }
}

/// Strength tiers shown on the Change Password indicator.
enum PasswordStrengthLevel { empty, weak, fair, good, strong }
