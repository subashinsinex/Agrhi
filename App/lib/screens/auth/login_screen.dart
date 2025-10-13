import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../shared/widgets/language_switcher.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../utils/validators.dart';
import '../../../src/services/language_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (context) => const LoginScreen());

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}



class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _isLoadingTranslations = false;

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

    setState(() => _isLoadingTranslations = true);

    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    final keys = {
      'signIn': 'Sign In',
      'loginSuccessful': 'Login Successful',
      'phoneNumber': 'Phone Number',
      'password': 'Password',
      'dontHaveAccount': "Don't have an account?",
      'signUp': 'Sign Up',
      'agrhi': 'Agrhi',
      'smartFarmApp': 'Smart Farm App',
      'skipForDemo': 'Skip for demo',
    };

    Map<String, String> newTranslated = {};
    for (var entry in keys.entries) {
      newTranslated[entry.key] = await languageService.translate(entry.value);
    }

    if (mounted) {
      setState(() {
        translatedTexts = newTranslated;
        _isLoadingTranslations = false;
      });
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);

    try {
      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(translatedTexts['loginSuccessful'] ?? 'Login Successful'),
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
        Routes.navigateToDashboard(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: AppColors.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      resizeToAvoidBottomInset: true,
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(height: 60),
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 100,
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  translatedTexts['agrhi'] ?? 'Agrhi',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  translatedTexts['SmartFarmApp'] ??
                                      'Smart Farming',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
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
                                ),
                                const SizedBox(height: 16),
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
                                ),
                                const SizedBox(height: 24),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
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
                                            translatedTexts['signIn'] ??
                                                'Sign In',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),
                            GestureDetector(
                              onTap: () => Routes.navigateToSignup(context),
                              child: RichText(
                                text: TextSpan(
                                  text:
                                      translatedTexts['dontHaveAccount'] ??
                                      "Don't have an account? ",
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                  children: [
                                    TextSpan(
                                      text:
                                          translatedTexts['signUp'] ??
                                          'Sign Up',
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
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => Routes.navigateToDashboard(context),
                              child: Text(
                                translatedTexts['skipForDemo'] ??
                                    'Skip for demo',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
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
            // Translation loading overlay
            if (_isLoadingTranslations)
              Container(
                color: Colors.black.withOpacity(0.3),
                child: Center(
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 4,
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.primaryGreen,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Loading translations...',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
