import 'package:agrhi/core/utils/decimal_input.dart';
import 'package:agrhi/core/utils/text_input.dart';
import 'package:agrhi/core/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('names support local languages and common punctuation', () {
    for (final name in [
      'சுபாஷ்',
      'सुभाष',
      'José',
      "O’Connor",
      'Anne-Marie',
      ' A. Kumar\u200E ',
    ]) {
      expect(Validators.validateName(name), isNull, reason: name);
    }
    for (final name in ['  ', '\u200B', '1234', '---', 'User@name']) {
      expect(Validators.validateName(name), isNotNull, reason: name);
    }
  });

  test(
    'email accepts clipboard boundaries but rejects malformed addresses',
    () {
      expect(
        Validators.validateEmail(' \u200Efarmer+tag@example.co.in\u200B '),
        isNull,
      );
      for (final email in [
        'a b@example.com',
        'a@example.com extra',
        'a@@example.com',
        '.a@example.com',
        'a..b@example.com',
        'a@-example.com',
        'a@example..com',
        '',
      ]) {
        expect(Validators.validateEmail(email), isNotNull, reason: email);
      }
      expect(
        normalizeTextInput(' \u200Ea@example.com\u200B '),
        'a@example.com',
      );
    },
  );

  test('postal codes and reset phones require digits after cleanup', () {
    expect(Validators.validatePincode(' 600\u00A0001\u200E '), isNull);
    expect(Validators.validatePincode('ABCDEF'), isNotNull);
    expect(Validators.validatePincode('12345'), isNotNull);
    expect(Validators.validateResetPhone('98675 34210\u200B'), isNull);
    expect(Validators.validateResetPhone('abcdefghij'), isNotNull);
    expect(Validators.validateResetPhone('12345678901'), isNotNull);
  });

  test('password confirmation compares exact values', () {
    expect(Validators.validatePassword(' Admin1234 '), isNull);
    expect(
      Validators.validateConfirmPassword('Admin1234', ' Admin1234 '),
      isNotNull,
    );
    expect(
      Validators.validateConfirmPassword(' Admin1234 ', ' Admin1234 '),
      isNull,
    );
    expect(Validators.validateLoginPassword('abcd'), isNull);
    expect(Validators.validatePassword('abcd'), isNotNull);
  });

  test('addresses reject invisible or short content', () {
    expect(Validators.validateAddress(' \u200B '), isNotNull);
    expect(Validators.validateAddress('short'), isNotNull);
    expect(Validators.validateAddress('  12 Farm Road\u200E '), isNull);
  });

  test('numeric pastes cannot silently truncate malformed values', () {
    const previous = TextEditingValue(text: '12');
    for (final input in ['12.3.4', '20kg', 'NaN', 'Infinity', '-1']) {
      expect(
        decimalInputFormatter.formatEditUpdate(
          previous,
          TextEditingValue(text: input),
        ),
        previous,
      );
    }
    for (final input in ['', '.5', '12.', '12.50', '0']) {
      expect(
        decimalInputFormatter
            .formatEditUpdate(previous, TextEditingValue(text: input))
            .text,
        input,
      );
    }
  });
}
