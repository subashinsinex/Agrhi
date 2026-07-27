import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../shared/language_switcher.dart';
import '../shared/smart_retranslator.dart';
import '../features/about_screen.dart';
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
  bool _agreedToTerms = false;
  DateTime? _selectedDate;
  String? _selectedCategoryId;

  static const Color primaryTextColor = Color(0xFF14332A);
  static const Color secondaryTextColor = Color(0xB214332A);
  static const Color hintTextColor = Color(0x8014332A);

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
    {
      'id': 'c7f2d8e1-9a54-4a6c-8e37-5d2b1f8c4e12',
      'name': 'Retailer',
      'key': 'retailer',
    },
    {
      'id': 'a3e9a9b4-4c2d-4b1f-9b3b-23f5c4a7d901',
      'name': 'Consumer',
      'key': 'consumer',
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
      'Retailer',
      'Consumer',
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
      'Please accept the Terms & Conditions and Privacy Policy',
      'Welcome. Create your AGRHI account.',
      'I have read and agree to the ',
      'Terms & Conditions',
      'Privacy Policy',
      ' of AGRHI.',
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
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryGreen,
              onPrimary: Colors.white,
              onSurface: primaryTextColor,
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

    if (!_agreedToTerms) {
      _showErrorSnackBar(
        'Please accept the Terms & Conditions and Privacy Policy',
      );
      return;
    }

    if (_selectedCategoryId == null) {
      _showErrorSnackBar('Please select a category');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.instance.post(
        '/profile/createUser',
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: SmartReTranslator(
                    text: 'Account created successfully!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.successColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            duration: const Duration(seconds: 2),
          ),
        );

        if (mounted) {
          Routes.navigateToLogin(context);
        }
      } else {
        String errorMessage;

        if (response.statusCode == 409) {
          errorMessage = 'User already exists with this phone number or email';
        } else if (response.statusCode != null && response.statusCode! >= 500) {
          errorMessage = 'Server error. Please try again later';
        } else if (response.isOffline) {
          errorMessage = 'No internet connection';
        } else if (response.isTimeout) {
          errorMessage = 'Request timeout. Please try again';
        } else {
          final responseData = response.data;
          errorMessage =
              (responseData is Map && responseData.containsKey('message'))
              ? responseData['message']
              : (response.error ?? 'Signup failed');
        }

        throw errorMessage;
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();

      if (errorMessage.contains('SocketException')) {
        errorMessage = 'No internet connection';
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage = 'Request timeout. Please try again';
      } else {
        errorMessage = errorMessage
            .replaceFirst('Client error: ', '')
            .replaceAll('{"message":"', '')
            .replaceAll('"}', '')
            .replaceAll('"', '')
            .trim();
      }

      _showErrorSnackBar(errorMessage);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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

  InputDecoration _modernInputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: hintTextColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: secondaryTextColor, size: 20),
      filled: true,
      fillColor: Colors.white.withOpacity(0.22),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.30), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.errorColor, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.errorColor, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: Colors.white.withOpacity(0.18), width: 1),
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

  Widget _buildTermsCheckbox() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreedToTerms,
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _agreedToTerms = value ?? false),
            activeColor: AppColors.primaryGreen,
            fillColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return AppColors.primaryGreen;
              }
              return Colors.white.withOpacity(0.90);
            }),
            checkColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(5),
            ),
            side: BorderSide(
              color: _agreedToTerms
                  ? AppColors.primaryGreen
                  : Colors.white.withOpacity(0.45),
              width: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _isLoading
                ? null
                : () => setState(() => _agreedToTerms = !_agreedToTerms),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I have read and agree to the '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => _openLegalSheet(context, openTerms: true),
                      child: const Text(
                        'Terms & Conditions',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => _openLegalSheet(context, openTerms: false),
                      child: const Text(
                        'Privacy Policy',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.primaryGreen,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ),
                  const TextSpan(text: ' of AGRHI.'),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openLegalSheet(BuildContext context, {required bool openTerms}) {
    if (openTerms) {
      AboutScreen.showTermsSheet(context);
    } else {
      AboutScreen.showPrivacySheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.28),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Container(
                                  width: 92,
                                  height: 92,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.24),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(14),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/logo.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'AGRHI',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.w800,
                                    color: primaryTextColor,
                                    letterSpacing: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const SmartReTranslator(
                                  text: 'Create Account',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const SmartReTranslator(
                                  text: 'Welcome. Create your AGRHI account.',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: secondaryTextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),

                          _ModernFormField(
                            controller: _nameController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.name,
                            validator: Validators.validateName,
                            decoration: _modernInputDecoration(
                              hintText: 'Full Name',
                              icon: Icons.person_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _ModernFormField(
                            controller: _phoneController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.phone,
                            validator: Validators.validatePhone,
                            decoration: _modernInputDecoration(
                              hintText: 'Phone Number',
                              icon: Icons.phone_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _ModernFormField(
                            controller: _emailController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                            decoration: _modernInputDecoration(
                              hintText: 'Email Address',
                              icon: Icons.email_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _DatePickerField(
                            controller: _dobController,
                            enabled: !_isLoading,
                            onTap: _isLoading ? null : _selectDate,
                            validator: _validateDOB,
                            decoration:
                                _modernInputDecoration(
                                  hintText: 'Date of Birth',
                                  icon: Icons.calendar_today_rounded,
                                ).copyWith(
                                  suffixIcon: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                    color: secondaryTextColor,
                                  ),
                                ),
                          ),
                          const SizedBox(height: 16),

                          _ModernFormField(
                            controller: _addressController,
                            enabled: !_isLoading,
                            maxLines: 2,
                            validator: _validateAddress,
                            decoration: _modernInputDecoration(
                              hintText: 'Address',
                              icon: Icons.location_on_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _ModernFormField(
                            controller: _pincodeController,
                            enabled: !_isLoading,
                            keyboardType: TextInputType.number,
                            validator: _validatePincode,
                            decoration: _modernInputDecoration(
                              hintText: 'Postal Code',
                              icon: Icons.pin_drop_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _CategoryDropdown(
                            value: _selectedCategoryId,
                            categories: _categories,
                            enabled: !_isLoading,
                            onChanged: _isLoading
                                ? null
                                : (value) {
                                    setState(() {
                                      _selectedCategoryId = value;
                                    });
                                  },
                            validator: _validateCategory,
                            decoration: _modernInputDecoration(
                              hintText: 'Select Category',
                              icon: Icons.category_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _ModernPasswordField(
                            controller: _passwordController,
                            enabled: !_isLoading,
                            obscureText: _obscurePassword,
                            validator: Validators.validatePassword,
                            onToggle: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            decoration: _modernInputDecoration(
                              hintText: 'Password',
                              icon: Icons.lock_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),

                          _ModernPasswordField(
                            controller: _confirmPasswordController,
                            enabled: !_isLoading,
                            obscureText: _obscureConfirmPassword,
                            validator: (value) =>
                                Validators.validateConfirmPassword(
                                  value,
                                  _passwordController.text,
                                ),
                            onToggle: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                            decoration: _modernInputDecoration(
                              hintText: 'Verify Password',
                              icon: Icons.lock_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 24),

                          _buildTermsCheckbox(),
                          const SizedBox(height: 24),

                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primaryGreen
                                    .withOpacity(0.55),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const SmartReTranslator(
                                      text: 'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          Center(
                            child: GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Routes.navigateToLogin(context),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 15,
                                  ),
                                  children: [
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: SmartReTranslator(
                                        text: 'Already have an account?',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: secondaryTextColor,
                                        ),
                                      ),
                                    ),
                                    TextSpan(text: '  '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.middle,
                                      child: SmartReTranslator(
                                        text: 'Sign In',
                                        style: TextStyle(
                                          color: primaryTextColor,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              top: 16,
              right: 16,
              child: Material(
                color: Colors.transparent,
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: const LanguageSwitcher(showAsIcon: true),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernFormField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;

  const _ModernFormField({
    required this.controller,
    required this.decoration,
    this.keyboardType,
    this.validator,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      decoration: decoration,
      keyboardType: keyboardType,
      validator: validator,
      enabled: enabled,
      maxLines: maxLines,
      style: const TextStyle(
        color: _SignupScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ModernPasswordField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final String? Function(String?)? validator;
  final bool enabled;
  final bool obscureText;
  final VoidCallback onToggle;

  const _ModernPasswordField({
    required this.controller,
    required this.decoration,
    this.validator,
    required this.enabled,
    required this.obscureText,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      enabled: enabled,
      style: const TextStyle(
        color: _SignupScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoration.copyWith(
        suffixIcon: IconButton(
          onPressed: onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: _SignupScreenState.secondaryTextColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final VoidCallback? onTap;
  final String? Function(String?)? validator;
  final bool enabled;

  const _DatePickerField({
    required this.controller,
    required this.decoration,
    required this.onTap,
    required this.validator,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      onTap: onTap,
      validator: validator,
      enabled: enabled,
      style: const TextStyle(
        color: _SignupScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoration,
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String? value;
  final List<Map<String, dynamic>> categories;
  final ValueChanged<String?>? onChanged;
  final String? Function(String?)? validator;
  final InputDecoration decoration;
  final bool enabled;

  const _CategoryDropdown({
    required this.value,
    required this.categories,
    required this.onChanged,
    required this.validator,
    required this.decoration,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      onChanged: enabled ? onChanged : null,
      validator: validator,
      decoration: decoration,
      icon: const Icon(
        Icons.keyboard_arrow_down_rounded,
        color: _SignupScreenState.secondaryTextColor,
      ),
      dropdownColor: const Color(0xFFF1FFF7),
      style: const TextStyle(
        color: _SignupScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      items: categories.map((category) {
        return DropdownMenuItem<String>(
          value: category['id'] as String,
          child: SmartReTranslator(
            text: category['name'] as String,
            style: const TextStyle(
              color: _SignupScreenState.primaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
      }).toList(),
    );
  }
}
