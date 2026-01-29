import 'constants.dart';

class Validators {
  // Phone number validation
  static String? validatePhone(String? value) {
    final v = value?.trim() ?? '';

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
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter your name';
    }

    if (v.length < AppConstants.minNameLength) {
      return 'Name must be at least ${AppConstants.minNameLength} characters';
    }

    if (v.length > AppConstants.maxNameLength) {
      return 'Name must not exceed ${AppConstants.maxNameLength} characters';
    }

    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(v)) {
      return 'Name should contain only letters and spaces';
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
