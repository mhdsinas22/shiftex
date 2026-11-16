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
