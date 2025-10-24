import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../shared/widgets/language_switcher.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../utils/validators.dart';
import '../../../src/services/language_service.dart';
import '../../utils/constants.dart';

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
  int? _selectedCategoryId;

  // Updated categories: Only Farmer and Expert
  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'Farmer', 'key': 'farmer'},
    {'id': 2, 'name': 'Expert', 'key': 'expert'},
  ];

  Map<String, String> translatedTexts = {};
  String _currentLanguage = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTranslations();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageService = Provider.of<LanguageService>(context);
    if (_currentLanguage != languageService.currentLocale.languageCode) {
      _currentLanguage = languageService.currentLocale.languageCode;
      _loadTranslations();
    }
  }

  Future<void> _loadTranslations() async {
    if (!mounted) return;

    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );
    final languageCode = languageService.currentLocale.languageCode;

    // Try to load from cache first
    final cached = await _getCachedTranslations(languageCode);
    if (cached != null) {
      setState(() => translatedTexts = cached);
    }

    // Fetch fresh translations - ADDED ALL MISSING KEYS
    final keys = {
      'createAccount': 'Create Account',
      'fullName': 'Full Name',
      'phoneNumber': 'Phone Number',
      'email': 'Email Address',
      'password': 'Password',
      'confirmPassword': 'Confirm Password',
      'dateOfBirth': 'Date of Birth',
      'address': 'Address',
      'pincode': 'Pincode',
      'category': 'Category',
      'selectCategory': 'Select Category',
      'accountCreated': 'Account created successfully!',
      'alreadyHaveAccount': 'Already have an account?',
      'signIn': 'Sign In',
      'signUp': 'Sign Up',
      'selectDate': 'Select Date',
      // Category names
      'farmer': 'Farmer',
      'expert': 'Expert',
      // Error messages
      'fillAllFields': 'Please fill all required fields correctly',
      'selectCategoryError': 'Please select a category',
      'enterEmail': 'Please enter your email',
      'validEmail': 'Enter a valid email address',
      'selectDob': 'Please select your date of birth',
      'enterAddress': 'Please enter your address',
      'addressLength': 'Address must be at least 10 characters',
      'enterPincode': 'Please enter pincode',
      'pincodeLength': 'Pincode must be 6 digits',
      'userExists': 'User already exists with this phone number or email',
      'serverError': 'Server error. Please try again later',
      'noInternet': 'No internet connection',
      'requestTimeout': 'Request timeout. Please try again',
    };

    Map<String, String> newTranslated = {};
    for (var entry in keys.entries) {
      newTranslated[entry.key] = await languageService.translate(entry.value);
    }

    // Cache and update
    await _cacheTranslations(languageCode, newTranslated);
    if (mounted) {
      setState(() => translatedTexts = newTranslated);
    }
  }

  Future<Map<String, String>?> _getCachedTranslations(
    String languageCode,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('signup_translations_$languageCode');
      if (cached != null) {
        final Map<String, dynamic> decoded = jsonDecode(cached);
        return decoded.map((key, value) => MapEntry(key, value.toString()));
      }
    } catch (e) {
      debugPrint('Cache read error: $e');
    }
    return null;
  }

  Future<void> _cacheTranslations(
    String languageCode,
    Map<String, String> translations,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'signup_translations_$languageCode',
        jsonEncode(translations),
      );
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
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

  Future<void> _handleSignup() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      _showSnackBar(
        translatedTexts['fillAllFields'] ??
            'Please fill all required fields correctly',
        AppColors.errorColor,
        Icons.error,
      );
      return;
    }

    if (_selectedCategoryId == null) {
      _showSnackBar(
        translatedTexts['selectCategoryError'] ?? 'Please select a category',
        AppColors.errorColor,
        Icons.error,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse(AppConstants.signupEndpoint);

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': _nameController.text.trim(),
              'dob': _dobController.text.trim(),
              'address': _addressController.text.trim(),
              'pincode': _pincodeController.text.trim(),
              'phone_number': _phoneController.text.trim(),
              'email': _emailController.text.trim(),
              'password': _passwordController.text.trim(),
              'category_id': _selectedCategoryId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        _showSnackBar(
          translatedTexts['accountCreated'] ?? 'Account created successfully!',
          AppColors.successColor,
          Icons.check_circle,
        );

        // Delay navigation to show success message
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Routes.navigateToLogin(context);
        }
      } else if (response.statusCode == 409) {
        throw translatedTexts['userExists'] ??
            'User already exists with this phone number or email';
      } else if (response.statusCode >= 500) {
        throw translatedTexts['serverError'] ??
            'Server error. Please try again later';
      } else {
        final responseData = jsonDecode(response.body);
        throw responseData['message'] ??
            'Signup failed: ${response.reasonPhrase}';
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException')) {
        errorMessage =
            translatedTexts['noInternet'] ?? 'No internet connection';
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage =
            translatedTexts['requestTimeout'] ??
            'Request timeout. Please try again';
      }

      _showSnackBar(errorMessage, AppColors.errorColor, Icons.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message, Color color, IconData icon) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: color == AppColors.errorColor ? 4 : 2),
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
                                Text(
                                  translatedTexts['createAccount'] ??
                                      'Create Account',
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
                            Column(
                              children: [
                                // Full Name
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['fullName'] ??
                                        'Full Name',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  validator: Validators.validateName,
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Phone Number
                                TextFormField(
                                  controller: _phoneController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['phoneNumber'] ??
                                        'Phone Number',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.phone,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  validator: Validators.validatePhone,
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Email
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['email'] ??
                                        'Email Address',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.email,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return translatedTexts['enterEmail'] ??
                                          'Please enter your email';
                                    }
                                    final emailRegex = RegExp(
                                      r'^[^@]+@[^@]+\.[^@]+',
                                    );
                                    if (!emailRegex.hasMatch(value)) {
                                      return translatedTexts['validEmail'] ??
                                          'Enter a valid email address';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Date of Birth
                                TextFormField(
                                  controller: _dobController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['dateOfBirth'] ??
                                        'Date of Birth',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      color: AppColors.primaryGreen,
                                    ),
                                    suffixIcon: Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  readOnly: true,
                                  onTap: _isLoading ? null : _selectDate,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return translatedTexts['selectDob'] ??
                                          'Please select your date of birth';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                // Address
                                TextFormField(
                                  controller: _addressController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['address'] ?? 'Address',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.location_on,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  maxLines: 2,
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return translatedTexts['enterAddress'] ??
                                          'Please enter your address';
                                    }
                                    if (value.trim().length < 10) {
                                      return translatedTexts['addressLength'] ??
                                          'Address must be at least 10 characters';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Pincode - FIXED TRANSLATION
                                TextFormField(
                                  controller: _pincodeController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['pincode'] ?? 'Pincode',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.pin_drop,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return translatedTexts['enterPincode'] ??
                                          'Please enter pincode';
                                    }
                                    if (value.length != 6) {
                                      return translatedTexts['pincodeLength'] ??
                                          'Pincode must be 6 digits';
                                    }
                                    return null;
                                  },
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Category Dropdown - FIXED TRANSLATION
                                DropdownButtonFormField<int>(
                                  value: _selectedCategoryId,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['selectCategory'] ??
                                        'Select Category',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.category,
                                      color: AppColors.primaryGreen,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.cardBackgroundGrey,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.cardBackgroundGrey,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: AppColors.primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.cardBackgroundLight,
                                  ),
                                  items: _categories.map((category) {
                                    // USE TRANSLATED TEXT FROM translatedTexts MAP
                                    final categoryKey =
                                        category['key'] as String;
                                    final translatedName =
                                        translatedTexts[categoryKey] ??
                                        category['name'] as String;

                                    return DropdownMenuItem<int>(
                                      value: category['id'] as int,
                                      child: Text(
                                        translatedName,
                                        style: TextStyle(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: _isLoading
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedCategoryId = value;
                                          });
                                        },
                                  validator: (value) {
                                    if (value == null) {
                                      return translatedTexts['selectCategoryError'] ??
                                          'Please select a category';
                                    }
                                    return null;
                                  },
                                  dropdownColor: AppColors.backgroundColor,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: AppColors.primaryGreen,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Password
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['password'] ??
                                        'Password',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock,
                                      color: AppColors.primaryGreen,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword =
                                            !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: Validators.validatePassword,
                                  enabled: !_isLoading,
                                ),
                                const SizedBox(height: 16),
                                // Confirm Password
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    hintText:
                                        translatedTexts['confirmPassword'] ??
                                        'Confirm Password',
                                    hintStyle: TextStyle(
                                      color: AppColors.textSecondary,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.lock_outline,
                                      color: AppColors.primaryGreen,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility
                                            : Icons.visibility_off,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscureConfirmPassword =
                                            !_obscureConfirmPassword,
                                      ),
                                    ),
                                  ),
                                  obscureText: _obscureConfirmPassword,
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
                                    onPressed: _isLoading
                                        ? null
                                        : _handleSignup,
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
                                        : Text(
                                            translatedTexts['signUp'] ??
                                                'Sign Up',
                                            style: const TextStyle(
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
                                    text: TextSpan(
                                      text:
                                          translatedTexts['alreadyHaveAccount'] ??
                                          'Already have an account? ',
                                      style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 16,
                                      ),
                                      children: [
                                        TextSpan(
                                          text:
                                              translatedTexts['signIn'] ??
                                              'Sign In',
                                          style: TextStyle(
                                            color: AppColors.primaryGreen,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 40),
                              ],
                            ),
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
}
