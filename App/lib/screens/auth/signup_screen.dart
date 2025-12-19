// lib/screens/auth/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../shared/language_switcher.dart';
import '../shared/smart_retranslator.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../utils/validators.dart';
import '../../src/services/language_service.dart';
import '../../src/services/api_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (context) => const SignupScreen());

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  DateTime? _selectedDate;
  String? _selectedCategoryId;

  final List<Map<String, dynamic>> _categories = [
    {
      'id': '582d0c0c-8bf2-4753-8c6c-1a398930b0e7',
      'name': 'Farmer',
      'key': 'farmer',
    },
    {
      'id': 'c944ecb8-524d-483f-9610-ed9e2e985e49',
      'name': 'Expert',
      'key': 'expert',
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _preloadTranslations();
    });
  }

  Future<void> _preloadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    await languageService.preloadTexts([
      'Create Account',
      'Full Name',
      'Phone Number',
      'Email Address',
      'Password',
      'Verify Password',
      'Date of Birth',
      'Address',
      'Postal Code',
      'Category',
      'Select Category',
      'Account created successfully!',
      'Already have an account?',
      'Sign In',
      'Sign Up',
      'Farmer',
      'Expert',
      'Please fill all required fields correctly',
      'Please select a category',
      'Please enter your email',
      'Enter a valid email address',
      'Please select your date of birth',
      'Please enter your address',
      'Address must be at least 10 characters',
      'Please enter Postal Code',
      'Postal Code must be 6 digits',
      'User already exists with this phone number or email',
      'Server error. Please try again later',
      'No internet connection',
      'Request timeout. Please try again',
    ], highPriority: true);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _dobController.dispose();
    _addressController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showErrorSnackBar('Please fill all required fields correctly');
      return;
    }

    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ USE ApiService
      final response = await ApiService.instance.post(
        '/signup',
        body: {
          'name': _nameController.text.trim(),
          'dob': _dobController.text.trim(),
          'address': _addressController.text.trim(),
          'pincode': _pincodeController.text.trim(),
          'phone_number': _phoneController.text.trim(),
          'email': _emailController.text.trim(),
          'password': _passwordController.text.trim(),
          'category_id': _selectedCategoryId,
        },
        requiresAuth: false,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess || response.statusCode == 201) {
        if (!mounted) return;

        _showSuccessSnackBar('Account created successfully!');

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Routes.navigateToLogin(context);
        }
      } else if (response.statusCode == 409) {
        throw 'User already exists with this phone number or email';
      } else if (response.statusCode != null && response.statusCode! >= 500) {
        throw 'Server error. Please try again later';
      } else if (response.isOffline) {
        throw 'No internet connection';
      } else if (response.isTimeout) {
        throw 'Request timeout. Please try again';
      } else {
        final responseData = response.data;
        throw responseData['message'] ?? response.error ?? 'Signup failed';
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException')) {
        errorMessage = 'No internet connection';
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage = 'Request timeout. Please try again';
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          children: [
                            const SizedBox(height: 40),

                            // Header
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 60,
                                  backgroundColor: AppColors.primaryGreen
                                      .withOpacity(0.1),
                                  child: Icon(
                                    Icons.agriculture,
                                    size: 60,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                const SmartReTranslator(
                                  text: 'Create Account',
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Form Fields
                            _FormField(
                              controller: _nameController,
                              labelText: 'Full Name',
                              icon: Icons.person,
                              validator: Validators.validateName,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _FormField(
                              controller: _phoneController,
                              labelText: 'Phone Number',
                              icon: Icons.phone,
                              keyboardType: TextInputType.phone,
                              validator: Validators.validatePhone,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _FormField(
                              controller: _emailController,
                              labelText: 'Email Address',
                              icon: Icons.email,
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _DatePickerField(
                              controller: _dobController,
                              labelText: 'Date of Birth',
                              onTap: _isLoading ? null : _selectDate,
                              validator: _validateDOB,
                            ),
                            const SizedBox(height: 16),

                            _FormField(
                              controller: _addressController,
                              labelText: 'Address',
                              icon: Icons.location_on,
                              maxLines: 2,
                              validator: _validateAddress,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _FormField(
                              controller: _pincodeController,
                              labelText: 'Postal Code',
                              icon: Icons.pin_drop,
                              keyboardType: TextInputType.number,
                              validator: _validatePincode,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _CategoryDropdown(
                              value: _selectedCategoryId,
                              categories: _categories,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedCategoryId = value;
                                      });
                                    },
                              validator: _validateCategory,
                            ),
                            const SizedBox(height: 16),

                            _PasswordField(
                              controller: _passwordController,
                              labelText: 'Password',
                              obscureText: _obscurePassword,
                              onToggle: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                              validator: Validators.validatePassword,
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 16),

                            _PasswordField(
                              controller: _confirmPasswordController,
                              labelText: 'Verify Password',
                              obscureText: _obscureConfirmPassword,
                              icon: Icons.lock_outline,
                              onToggle: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                              validator: (value) =>
                                  Validators.validateConfirmPassword(
                                    value,
                                    _passwordController.text,
                                  ),
                              enabled: !_isLoading,
                            ),
                            const SizedBox(height: 32),

                            // Sign Up Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _handleSignup,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryGreen,
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: AppColors
                                      .primaryGreen
                                      .withOpacity(0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 2,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                Colors.white,
                                              ),
                                        ),
                                      )
                                    : const SmartReTranslator(
                                        text: 'Sign Up',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Sign In Link
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Routes.navigateToLogin(context),
                              child: RichText(
                                text: const TextSpan(
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: SmartReTranslator(
                                        text: 'Already have an account?',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    TextSpan(text: ' '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: SmartReTranslator(
                                        text: 'Sign In',
                                        style: TextStyle(
                                          color: AppColors.primaryGreen,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Language Switcher
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shadowColor.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const LanguageSwitcher(showAsIcon: true),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your email';
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(value)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateDOB(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select your date of birth';
    }
    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your address';
    }
    if (value.trim().length < 10) {
      return 'Address must be at least 10 characters';
    }
    return null;
  }

  String? _validatePincode(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter Postal Code';
    }
    if (value.length != 6) {
      return 'Postal Code must be 6 digits';
    }
    return null;
  }

  String? _validateCategory(String? value) {
    if (value == null) {
      return 'Please select a category';
    }
    return null;
  }
}

// ✅ Reusable form field widget
class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int? maxLines;

  const _FormField({
    required this.controller,
    required this.labelText,
    required this.icon,
    this.keyboardType,
    this.validator,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        label: SmartReTranslator(
          text: labelText,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBackgroundGrey),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBackgroundGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.errorColor),
        ),
      ),
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      maxLines: maxLines,
    );
  }
}

// ✅ Date picker field widget
class _DatePickerField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;

  const _DatePickerField({
    required this.controller,
    required this.labelText,
    this.onTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        label: SmartReTranslator(
          text: labelText,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        prefixIcon: Icon(Icons.calendar_today, color: AppColors.primaryGreen),
        suffixIcon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBackgroundGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      readOnly: true,
      onTap: onTap,
      validator: validator,
    );
  }
}

// ✅ Password field widget
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String labelText;
  final bool obscureText;
  final VoidCallback onToggle;
  final String? Function(String?)? validator;
  final bool enabled;
  final IconData? icon;

  const _PasswordField({
    required this.controller,
    required this.labelText,
    required this.obscureText,
    required this.onToggle,
    this.validator,
    required this.enabled,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        label: SmartReTranslator(
          text: labelText,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        prefixIcon: Icon(icon ?? Icons.lock, color: AppColors.primaryGreen),
        suffixIcon: IconButton(
          icon: Icon(
            obscureText ? Icons.visibility : Icons.visibility_off,
            color: AppColors.textSecondary,
          ),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBackgroundGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      obscureText: obscureText,
      validator: validator,
      enabled: enabled,
    );
  }
}

// ✅ Category dropdown widget
class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final List<Map<String, dynamic>> categories;
  final void Function(String?)? onChanged;
  final String? Function(String?)? validator;

  const _CategoryDropdown({
    this.value,
    required this.categories,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        label: const SmartReTranslator(
          text: 'Select Category',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        prefixIcon: Icon(Icons.category, color: AppColors.primaryGreen),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.cardBackgroundGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        filled: true,
        fillColor: AppColors.cardBackgroundLight,
      ),
      items: categories.map((category) {
        final categoryKey = category['key'] as String;
        return DropdownMenuItem<String>(
          value: category['id'] as String,
          child: SmartReTranslator(
            text: categoryKey == 'farmer' ? 'Farmer' : 'Expert',
            style: const TextStyle(color: AppColors.textPrimary),
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: validator,
      dropdownColor: AppColors.backgroundColor,
      icon: Icon(Icons.arrow_drop_down, color: AppColors.primaryGreen),
    );
  }
}
