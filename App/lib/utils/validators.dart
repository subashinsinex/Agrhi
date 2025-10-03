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

  // Password validation
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

  // Email validation (for future use)
  static String? validateEmail(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter your email';
    }

    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
      return 'Please enter a valid email address';
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

  // Plot area validation
  static String? validatePlotArea(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter plot area';
    }

    final area = double.tryParse(v);
    if (area == null) {
      return 'Please enter a valid number';
    }

    if (area <= 0) {
      return 'Plot area must be greater than 0';
    }

    return null;
  }

  // Generic required field validation
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }
    return null;
  }

  // Numeric validation
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName';
    }

    if (double.tryParse(value.trim()) == null) {
      return '$fieldName must be a valid number';
    }

    return null;
  }

  // Additional validators you might need:

  // OTP validation
  static String? validateOTP(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter OTP';
    }

    if (v.length != 6) {
      return 'OTP must be 6 digits';
    }

    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      return 'OTP should contain only digits';
    }

    return null;
  }

  // Farm name validation
  static String? validateFarmName(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter farm name';
    }

    if (v.length < 2) {
      return 'Farm name must be at least 2 characters';
    }

    if (v.length > 50) {
      return 'Farm name must not exceed 50 characters';
    }

    return null;
  }

  // Location validation
  static String? validateLocation(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter location';
    }

    if (v.length < 2) {
      return 'Location must be at least 2 characters';
    }

    return null;
  }

  // Crop type validation
  static String? validateCropType(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select crop type';
    }
    return null;
  }

  // Soil type validation
  static String? validateSoilType(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select soil type';
    }
    return null;
  }

  // Age validation
  static String? validateAge(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter age';
    }

    final age = int.tryParse(v);
    if (age == null) {
      return 'Please enter a valid age';
    }

    if (age < 18) {
      return 'Age must be at least 18 years';
    }

    if (age > 100) {
      return 'Please enter a valid age';
    }

    return null;
  }

  // Price validation
  static String? validatePrice(String? value) {
    final v = value?.trim() ?? '';

    if (v.isEmpty) {
      return 'Please enter price';
    }

    final price = double.tryParse(v);
    if (price == null) {
      return 'Please enter a valid price';
    }

    if (price <= 0) {
      return 'Price must be greater than 0';
    }

    return null;
  }
}
