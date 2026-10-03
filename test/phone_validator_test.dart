import 'package:flutter_test/flutter_test.dart';
import 'package:axisvtu_flutter/utils/phone_validator.dart';

void main() {
  group('Phase 1 Acceptance Criteria: Phone Validation', () {
    test('Accepts valid 11-digit numbers starting with 0', () {
      final res1 = PhoneValidator.validate('08012345678');
      expect(res1.isValid, isTrue);
      expect(res1.cleanPhone, '08012345678');
      expect(res1.error, isNull);

      final res2 = PhoneValidator.validate('07033334444');
      expect(res2.isValid, isTrue);
      expect(res2.cleanPhone, '07033334444');

      final res3 = PhoneValidator.validate('09011112222');
      expect(res3.isValid, isTrue);
      expect(res3.cleanPhone, '09011112222');

      final res4 = PhoneValidator.validate('09122223333');
      expect(res4.isValid, isTrue);
      expect(res4.cleanPhone, '09122223333');
    });

    test('Rejects numbers starting with +234 or 234 with exact "start with 0" message', () {
      final res1 = PhoneValidator.validate('+2348012345678');
      expect(res1.isValid, isFalse);
      expect(res1.error, 'Enter your number starting with 0');

      final res2 = PhoneValidator.validate('2348012345678');
      expect(res2.isValid, isFalse);
      expect(res2.error, 'Enter your number starting with 0');

      final res3 = PhoneValidator.validate('+234 801 234 5678');
      expect(res3.isValid, isFalse);
      expect(res3.error, 'Enter your number starting with 0');
    });

    test('Cleans spaces, dashes, and parentheses to 11 digits before validation', () {
      final res1 = PhoneValidator.validate('0801 234 5678');
      expect(res1.isValid, isTrue);
      expect(res1.cleanPhone, '08012345678');

      final res2 = PhoneValidator.validate('0801-234-5678');
      expect(res2.isValid, isTrue);
      expect(res2.cleanPhone, '08012345678');

      final res3 = PhoneValidator.validate('(0801) 234 5678');
      expect(res3.isValid, isTrue);
      expect(res3.cleanPhone, '08012345678');
    });

    test('Rejects numbers with invalid length', () {
      final short = PhoneValidator.validate('080123456');
      expect(short.isValid, isFalse);
      expect(short.error, contains('must be 11 digits'));

      final long = PhoneValidator.validate('0801234567899');
      expect(long.isValid, isFalse);
      expect(long.error, contains('must be exactly 11 digits'));
    });

    test('Rejects invalid network prefixes (e.g. 060, 050)', () {
      final invalidPrefix = PhoneValidator.validate('06012345678');
      expect(invalidPrefix.isValid, isFalse);
      expect(invalidPrefix.error, contains('valid Nigerian network number'));
    });

    test('Rejects empty or non-numeric input', () {
      final empty = PhoneValidator.validate('');
      expect(empty.isValid, isFalse);

      final letters = PhoneValidator.validate('08012abc678');
      expect(letters.isValid, isFalse);
    });
  });
}
