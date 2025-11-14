import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../shared/widgets/language_switcher.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/routes.dart';
import '../../utils/validators.dart';
import '../../../src/services/language_service.dart';
import '../../src/database/database_helper.dart';

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

  Map<String, String> translatedTexts = {
    'signIn': 'Sign In',
    'loginSuccessful': 'Login Successful',
    'phoneNumber': 'Phone Number',
    'password': 'Password',
    'dontHaveAccount': "Don't have an account?",
    'signUp': 'Sign Up',
    'skipForDemo': 'Skip for demo',
  };

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

    // Fetch fresh translations in background
    final keys = {
      'signIn': 'Sign In',
      'loginSuccessful': 'Login Successful',
      'phoneNumber': 'Phone Number',
      'password': 'Password',
      'dontHaveAccount': "Don't have an account?",
      'signUp': 'Sign Up',
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
      final cached = prefs.getString('translations_$languageCode');
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
        'translations_$languageCode',
        jsonEncode(translations),
      );
    } catch (e) {
      debugPrint('Cache write error: $e');
    }
  }

  // Fetch user profile from server
  Future<Map<String, dynamic>?> _fetchUserProfile(
    String accessToken,
    String userId,
  ) async {
    try {
      final url = Uri.parse(
        '${AppConstants.baseUrl}/profile/getUserDetails/$userId',
      );

      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching profile: $e');
      return null;
    }
  }

  // Store user profile in secure storage
  Future<void> _storeUserProfile(Map<String, dynamic> profileData) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 'user_profile', value: jsonEncode(profileData));
  }

  Future<void> clearAllSecureStorage() async {
    const storage = FlutterSecureStorage();

    await storage.deleteAll();

    print('✅ All secure storage data deleted');
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
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();

      final url = Uri.parse(AppConstants.loginEndpoint);

      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone_number': phone,
              'password': password,
              'platform': 'mobile',
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final accessToken = responseData['access_token'] as String;
        final refreshToken = responseData['refresh_token'] as String;

        // Store tokens with expiration check
        final storage = const FlutterSecureStorage();
        await storage.write(key: 'access_token', value: accessToken);
        await storage.write(key: 'refresh_token', value: refreshToken);

        String? userId;
        try {
          final decodedToken = JwtDecoder.decode(accessToken);
          userId = decodedToken['user_id']?.toString();
          await storage.write(key: 'user_id', value: userId);
        } catch (e) {
          debugPrint('Token decode error: $e');
        }
        // Fetch and store user profile if userId is available
        if (userId != null) {
          final profileData = await _fetchUserProfile(accessToken, userId);
          if (profileData != null) {
            await _storeUserProfile(profileData);
          }
        }

        // Store expiration time
        try {
          final expiryDate = JwtDecoder.getExpirationDate(accessToken);
          await storage.write(
            key: 'token_expiry',
            value: expiryDate.toIso8601String(),
          );
        } catch (e) {
          debugPrint('Token decode error: $e');
        }

        final syncResult = await DatabaseHelper.instance.smartSyncCatalogs(
          accessToken);
          
        if (syncResult['success']) {
          print('✅ Synced ${syncResult['updated']} tables');
        } else {
          print('⚠️ ${syncResult['message']}');
        }

        if (!mounted) return;
        _showSnackBar(
          translatedTexts['loginSuccessful'] ?? 'Login Successful',
          AppColors.successColor,
          Icons.check_circle,
        );
        Routes.navigateToDashboard(context);
      } else if (response.statusCode == 401) {
        throw 'Invalid phone number or password';
      } else if (response.statusCode >= 500) {
        throw 'Server error. Please try again later';
      } else {
        throw 'Login failed: ${response.reasonPhrase}';
      }
    } catch (e) {
      if (!mounted) return;

      String errorMessage = e.toString();
      if (errorMessage.contains('SocketException')) {
        errorMessage = 'No internet connection';
      } else if (errorMessage.contains('TimeoutException')) {
        errorMessage = 'Request timeout. Please try again';
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
                                  'Agrhi',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Smart Farm App',
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
                                  enabled: !_isLoading,
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
                                  enabled: !_isLoading,
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
                              onTap: _isLoading
                                  ? null
                                  : () => Routes.navigateToSignup(context),
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
          ],
        ),
      ),
    );
  }
}
