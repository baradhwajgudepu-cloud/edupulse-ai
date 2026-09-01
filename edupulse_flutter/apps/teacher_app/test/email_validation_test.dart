import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_app/core/utils/email_validator.dart';

void main() {
  group('EmailValidator tests', () {
    test('Valid internal .local email: teacher.t101@edupulse.local should be valid', () {
      expect(EmailValidator.validate('teacher.t101@edupulse.local'), isTrue);
    });

    test('Valid internal .local email: principal.a2707e@edupulse.local should be valid', () {
      expect(EmailValidator.validate('principal.a2707e@edupulse.local'), isTrue);
    });

    test('Valid public domain email: test@gmail.com should be valid', () {
      expect(EmailValidator.validate('test@gmail.com'), isTrue);
    });

    test('Invalid email: invalid-email should be invalid', () {
      expect(EmailValidator.validate('invalid-email'), isFalse);
    });

    test('Invalid email: testgmail.com should be invalid', () {
      expect(EmailValidator.validate('testgmail.com'), isFalse);
    });

    test('Invalid email: test@ should be invalid', () {
      expect(EmailValidator.validate('test@'), isFalse);
    });

    test('Invalid email: @edupulse.local should be invalid', () {
      expect(EmailValidator.validate('@edupulse.local'), isFalse);
    });

    test('Invalid email: test@.local should be invalid', () {
      expect(EmailValidator.validate('test@.local'), isFalse);
    });

    test('Leading/trailing whitespace around a valid email should be valid', () {
      expect(EmailValidator.validate('  teacher.t101@edupulse.local  '), isTrue);
      expect(EmailValidator.validate('\ntest@gmail.com\t'), isTrue);
    });
  });
}
