import 'package:flutter/services.dart';

// Validate the entire edit so a malformed paste cannot become another number.
final decimalInputFormatter = TextInputFormatter.withFunction((
  oldValue,
  newValue,
) {
  return RegExp(r'^[0-9]*\.?[0-9]*$').hasMatch(newValue.text)
      ? newValue
      : oldValue;
});
