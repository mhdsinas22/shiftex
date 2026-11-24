import 'package:flutter_test/flutter_test.dart';
import 'package:shiftex/core/extensions/string_extensions.dart';
import 'package:shiftex/core/utils/validators.dart';

void main() {
  group('Registration Validation Tests', () {
    test('First name and last name are required', () {
      expect(Validators.validateFirstName(''), isNotNull);
      expect(Validators.validateFirstName('A'), isNotNull);
      expect(Validators.validateFirstName('Rahul'), isNull);

      expect(Validators.validateLastName(''), isNotNull);
      expect(Validators.validateLastName('Sharma'), isNull);
    });

    test('Mobile number validates 10-digit Indian numbers for +91', () {
      expect(Validators.validateMobileNumber(''), isNotNull);
      expect(Validators.validateMobileNumber('12345'), isNotNull);
      expect(Validators.validateMobileNumber('1234567890'), isNotNull);
      expect(Validators.validateMobileNumber('9876543210'), isNull);
      expect(
        Validators.validateMobileNumber('4155552671', countryCode: '+1'),
        isNull,
      );
    });

    test('Email validation enforces valid email structure', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('rahul@example'), isNotNull);
      expect(Validators.validateEmail('rahul123@example.com'), isNull);
    });

    test('Password requires minimum 8 characters and at least 1 number', () {
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword('short1'), isNotNull);
      expect(Validators.validatePassword('NoNumbersHere'), isNotNull);
      expect(Validators.validatePassword('SecurePass1'), isNull);
      expect(Validators.isPasswordRuleSatisfied('SecurePass1'), isTrue);
      expect(Validators.isPasswordRuleSatisfied('NoNumber'), isFalse);
    });
  });

  group('Login & Password Reset Validation Tests', () {
    test('Login identifier accepts valid email or valid mobile number', () {
      expect(Validators.validateMobileOrEmail(''), isNotNull);
      expect(Validators.validateMobileOrEmail('bad@'), isNotNull);
      expect(Validators.validateMobileOrEmail('123'), isNotNull);
      expect(Validators.validateMobileOrEmail('rahul@example.com'), isNull);
      expect(Validators.validateMobileOrEmail('9876543210'), isNull);
      expect(Validators.validateMobileOrEmail('+919876543210'), isNull);
    });

    test('Confirm password must match new password', () {
      expect(Validators.validateConfirmPassword('', 'Secret123'), isNotNull);
      expect(
        Validators.validateConfirmPassword('Different123', 'Secret123'),
        isNotNull,
      );
      expect(
        Validators.validateConfirmPassword('Secret123', 'Secret123'),
        isNull,
      );
    });

    test('OTP validator requires exactly 6 digits', () {
      expect(Validators.validateOtp(''), isNotNull);
      expect(Validators.validateOtp('582'), isNotNull);
      expect(Validators.validateOtp('58219a'), isNotNull);
      expect(Validators.validateOtp('582194'), isNull);
    });

    test('Email masking formats email as expected by UI references', () {
      expect('john.doe@example.com'.maskedEmail, 'j••••••••e@example.com');
      expect('9876543210'.normalizeMobile(), '+919876543210');
    });
  });

  group('Change Password Strong Validation Tests', () {
    test('Current password validator rejects empty values', () {
      expect(Validators.validateCurrentPassword(''), isNotNull);
      expect(Validators.validateCurrentPassword(null), isNotNull);
      expect(Validators.validateCurrentPassword('Current1!'), isNull);
    });

    test('Strong password checks all 5 complexity rules individually', () {
      expect(Validators.hasPasswordUppercase('abc123!@'), isFalse);
      expect(Validators.hasPasswordUppercase('Abc123!@'), isTrue);

      expect(Validators.hasPasswordLowercase('ABC123!@'), isFalse);
      expect(Validators.hasPasswordLowercase('ABc123!@'), isTrue);

      expect(Validators.hasPasswordSpecialChar('Abcd1234'), isFalse);
      expect(Validators.hasPasswordSpecialChar('Abcd123 '), isFalse);
      expect(Validators.hasPasswordSpecialChar('Abcd123!'), isTrue);
      expect(Validators.hasPasswordSpecialChar('Abcd123_'), isTrue);

      expect(Validators.isStrongPasswordSatisfied('Abcd123!'), isTrue);
      expect(Validators.isStrongPasswordSatisfied('Abcd1234'), isFalse);
    });

    test('Password strength evaluator returns monotonic tiers', () {
      expect(
        Validators.evaluatePasswordStrength(''),
        PasswordStrengthLevel.empty,
      );
      expect(
        Validators.evaluatePasswordStrength('abc1'),
        PasswordStrengthLevel.weak,
      );
      expect(
        Validators.evaluatePasswordStrength('Abcdefgh'),
        PasswordStrengthLevel.fair,
      );
      expect(
        Validators.evaluatePasswordStrength('Abcdefg1'),
        PasswordStrengthLevel.good,
      );
      expect(
        Validators.evaluatePasswordStrength('Abcdef1!'),
        PasswordStrengthLevel.strong,
      );
    });

    test('New password validator rejects weak and same passwords', () {
      expect(Validators.validateStrongNewPassword(''), isNotNull);
      expect(Validators.validateStrongNewPassword('Short1!'), isNotNull);
      expect(Validators.validateStrongNewPassword('lowercase1!'), isNotNull);
      expect(Validators.validateStrongNewPassword('UPPERCASE1!'), isNotNull);
      expect(Validators.validateStrongNewPassword('NoNumberHere!'), isNotNull);
      expect(Validators.validateStrongNewPassword('NoSpecial1'), isNotNull);
      expect(
        Validators.validateStrongNewPassword(
          'ValidPass1!',
          currentPassword: 'ValidPass1!',
        ),
        'New password must be different from current password',
      );
      expect(
        Validators.validateStrongNewPassword(
          'NewValid1!',
          currentPassword: 'OldValid1!',
        ),
        isNull,
      );
    });

    test('Confirm new password validator checks match cleanly', () {
      expect(
        Validators.validateConfirmNewPassword('', 'NewValid1!'),
        isNotNull,
      );
      expect(
        Validators.validateConfirmNewPassword('Mismatch1!', 'NewValid1!'),
        'Passwords do not match',
      );
      expect(
        Validators.validateConfirmNewPassword('NewValid1!', 'NewValid1!'),
        isNull,
      );
    });
  });
}
