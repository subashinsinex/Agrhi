import 'package:agrhi/core/utils/constants.dart';
import 'package:agrhi/core/utils/phone_number_input.dart';
import 'package:agrhi/core/utils/text_input.dart';

class Validators {
  // Phone number validation
  static String? validatePhone(String? value) {
    final v = normalizePhoneNumber(value ?? '');

    if (v.isEmpty) {
      return 'Please enter your phone number';
    }

    if (v.length < AppConstants.minPhoneLength) {
      return 'Phone number must be at least ${AppConstants.minPhoneLength} digits';
    }

    if (v.length > AppConstants.maxPhoneLength) {
      return 'Phone number must not exceed ${AppConstants.maxPhoneLength} digits';
    }

    if (!RegExp(r'^\d+$').hasMatch(v)) {
      return 'Phone number should contain only digits';
    }

    return null;
  }

  // Password validation - UPDATED WITH NEW REQUIREMENTS
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }

    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }

    if (value.length > AppConstants.maxPasswordLength) {
      return 'Password must not exceed ${AppConstants.maxPasswordLength} characters';
    }

    // Check for at least one uppercase letter
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  // Name validation
  static String? validateName(String? value) {
    final v = normalizeTextInput(value ?? '');

    if (v.isEmpty) {
      return 'Please enter your name';
    }

    if (v.length < AppConstants.minNameLength) {
      return 'Name must be at least ${AppConstants.minNameLength} characters';
    }

    if (v.length > AppConstants.maxNameLength) {
      return 'Name must not exceed ${AppConstants.maxNameLength} characters';
    }

    if (!RegExp(
          r"^[\p{L}\p{M}\u200C\u200D .’'\-]+$",
          unicode: true,
        ).hasMatch(v) ||
        !RegExp(r'\p{L}', unicode: true).hasMatch(v)) {
      return 'Enter a valid name using letters, spaces, apostrophes or hyphens';
    }

    return null;
  }

  static String? validateEmail(String? value) {
    final email = normalizeTextInput(value ?? '');
    if (email.isEmpty) return 'Please enter your email';
    final parts = email.split('@');
    if (email.length > 254 || parts.length != 2) {
      return 'Enter a valid email address';
    }
    final local = parts.first;
    final labels = parts.last.split('.');
    if (local.isEmpty ||
        local.length > 64 ||
        local.startsWith('.') ||
        local.endsWith('.') ||
        local.contains('..') ||
        !RegExp(r"^[a-zA-Z0-9.!#$%&'*+/=?^_`{|}~-]+$").hasMatch(local) ||
        labels.length < 2 ||
        labels.any(
          (label) =>
              label.isEmpty ||
              label.length > 63 ||
              !RegExp(
                r'^[a-zA-Z0-9](?:[a-zA-Z0-9-]*[a-zA-Z0-9])?$',
              ).hasMatch(label),
        )) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? validatePincode(String? value) {
    final code = normalizePhoneNumber(value ?? '');
    if (code.isEmpty) return 'Please enter Postal Code';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      return 'Postal Code must be 6 digits';
    }
    return null;
  }

  static String? validateAddress(String? value) {
    final address = normalizeTextInput(value ?? '');
    if (address.isEmpty) return 'Please enter your address';
    if (address.length < 10) return 'Address must be at least 10 characters';
    return null;
  }

  static String? validateLoginPassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    return null;
  }

  static String? validateResetPhone(String? value) {
    if (!RegExp(r'^[0-9]{10}$').hasMatch(normalizePhoneNumber(value ?? ''))) {
      return 'Please enter a valid 10-digit mobile number';
    }
    return null;
  }

  // Confirm password validation
  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }

    if (value != password) {
      return 'Passwords do not match';
    }

    return null;
  }
}
