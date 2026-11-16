extension StringExtensions on String {
  /// Masks an email address as shown in the UI reference:
  /// e.g. `john.doe@example.com` -> `j••••••••e@example.com`
  String get maskedEmail {
    final trimmed = trim();
    final parts = trimmed.split('@');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      return trimmed;
    }

    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) {
      return '${local[0]}••••••@$domain';
    }
    final first = local[0];
    final last = local[local.length - 1];
    return '$first••••••••$last@$domain';
  }

  /// Normalizes a mobile number with country code into E.164 format.
  String normalizeMobile({String defaultCountryCode = '+91'}) {
    final digitsAndPlus = replaceAll(RegExp(r'[^0-9+]'), '');
    if (digitsAndPlus.isEmpty) return '';
    if (digitsAndPlus.startsWith('+')) {
      return digitsAndPlus;
    }
    final cleanCode =
        defaultCountryCode.startsWith('+')
            ? defaultCountryCode
            : '+$defaultCountryCode';
    if (digitsAndPlus.length == 10) {
      return '$cleanCode$digitsAndPlus';
    }
    if (digitsAndPlus.length == 12 && digitsAndPlus.startsWith('91')) {
      return '+$digitsAndPlus';
    }
    return '$cleanCode$digitsAndPlus';
  }

  bool get looksLikeEmail => contains('@');
}
