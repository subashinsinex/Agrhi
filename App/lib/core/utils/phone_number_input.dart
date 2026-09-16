import 'package:flutter/services.dart';

// Clipboard text can contain spaces, zero-width characters and direction marks.
// Keep other non-digits so validation still catches invalid phone numbers.
final _phoneFormatting = RegExp(
  r'[\s\u0085\u00A0\u1680\u180E\u2000-\u200F\u2028-\u202F\u205F\u2060-\u206F\u3000\uFEFF\u061C]',
);

String normalizePhoneNumber(String value) =>
    value.replaceAll(_phoneFormatting, '');

final phoneNumberInputFormatter = FilteringTextInputFormatter.deny(
  _phoneFormatting,
);
