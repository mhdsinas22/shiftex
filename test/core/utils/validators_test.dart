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
}
