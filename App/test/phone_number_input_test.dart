import 'package:agrhi/core/utils/phone_number_input.dart';
import 'package:agrhi/core/utils/validators.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pasted phone number removes whitespace and invisible formatting', () {
    const pasted = '\u200E98675\u00A034210\u200B\n';
    final result = phoneNumberInputFormatter.formatEditUpdate(
      TextEditingValue.empty,
      const TextEditingValue(
        text: pasted,
        selection: TextSelection.collapsed(offset: pasted.length),
      ),
    );
    expect(result.text, '9867534210');
    expect(result.selection.baseOffset, 10);
    expect(normalizePhoneNumber(pasted), result.text);
    expect(Validators.validatePhone(pasted), isNull);
  });

  test('invalid content and length are still rejected', () {
    expect(Validators.validatePhone('98675abc210'), isNotNull);
    expect(Validators.validatePhone('123\u200B'), isNotNull);
    expect(Validators.validatePhone(' \u200E'), isNotNull);
    expect(Validators.validatePhone('1234567890123456'), isNotNull);
    expect(normalizePhoneNumber('+91-9867534210'), '+91-9867534210');
  });
}
