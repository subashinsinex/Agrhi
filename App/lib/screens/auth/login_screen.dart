import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import '../shared/language_switcher.dart';
import '../shared/smart_retranslator.dart';
import '../../utils/colors.dart';
import '../../utils/routes.dart';
import '../../utils/validators.dart';
import '../../utils/constants.dart';
import '../../src/services/language_service.dart';
import '../../src/services/api_service.dart';
import '../../src/services/farm_store_service.dart';
import '../../src/database/database_helper.dart';
import '../../src/services/connectivity_manager.dart';
import 'forgot_password_screen.dart';

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

  static const Color primaryTextColor = Color(0xFF14332A);
  static const Color secondaryTextColor = Color(0xB214332A);
  static const Color hintTextColor = Color(0x8014332A);

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

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
      'Sign In',
      'Login Successful',
      'Phone Number',
      'Password',
      "Don't have an account?",
      'Sign Up',
      'Smart Farm Assistant',
      'Invalid phone number or password',
      'Server error. Please try again later',
      'Login failed',
      'No internet connection',
      'Request timeout. Please try again',
      'Enter a valid phone number',
      'Password must be at least 6 characters',
      'Forgot Password?',
      'Welcome back. Please enter your details.',
      'Password is required',
    ], highPriority: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _fetchUserProfile(
    String accessToken,
    String userId,
  ) async {
    try {
      final response = await ApiService.instance.get(
        '/profile/getUserDetails/$userId',
        requiresAuth: true,
        timeout: const Duration(seconds: 15),
      );

      if (response.isSuccess) {
        return response.data;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching profile: $e');
      return null;
    }
  }

  Future<void> _storeUserProfile(Map<String, dynamic> profileData) async {
    await _storage.write(key: 'user_profile', value: jsonEncode(profileData));
    debugPrint('💾 Profile data stored in secure storage');
  }

  Future<void> _downloadAndSaveProfilePicture(
    String picUrl,
    String accessToken,
  ) async {
    try {
      if (picUrl == 'no-image' || picUrl.isEmpty) {
        debugPrint('ℹ️ No profile picture to download');
        return;
      }

      String fullUrl;
      if (picUrl.startsWith('http')) {
        fullUrl = picUrl;
      } else {
        final baseUrl = AppConstants.baseUrl.replaceAll('/api', '');
        fullUrl = '$baseUrl$picUrl';
      }

      final response = await http
          .get(
            Uri.parse(fullUrl),
            headers: {'Authorization': 'Bearer $accessToken'},
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to download: ${response.statusCode}');
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${directory.path}/profile_pictures');

      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      await _deleteOldProfilePictures(profileDir);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = picUrl.split('.').last.split('?').first;
      final localPath = '${profileDir.path}/profile_$timestamp.$extension';

      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);

      await _storage.write(key: 'profile_image_local_path', value: localPath);
      await _storage.write(key: 'profile_image_server_url', value: picUrl);
    } catch (e) {
      debugPrint('⚠️ Profile picture download failed: $e');
    }
  }

  Future<void> _deleteOldProfilePictures(Directory profileDir) async {
    try {
      if (await profileDir.exists()) {
        final files = profileDir.listSync();
        for (var file in files) {
          if (file is File && file.path.contains('profile_')) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error deleting old profile pictures: $e');
    }
  }

  Future<void> _handleLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
      final phone = _phoneController.text.trim();
      final password = _passwordController.text.trim();

      final response = await ApiService.instance.post(
        '/login',
        body: {
          'phone_number': phone,
          'password': password,
          'platform': 'mobile',
        },
        requiresAuth: false,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess) {
        final responseData = response.data;
        final accessToken = responseData['access_token'] as String;
        final refreshToken = responseData['refresh_token'] as String;

        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);

        String? userId;
        String? userCategory;

        try {
          final decodedToken = JwtDecoder.decode(accessToken);
          userId = decodedToken['user_id']?.toString();
          await _storage.write(key: 'user_id', value: userId);
          await _storage.write(
            key: 'phone_number',
            value: decodedToken['phone_number']?.toString(),
          );
          await _storage.write(
            key: 'email',
            value: decodedToken['email']?.toString(),
          );
        } catch (e) {
          debugPrint('❌ Token decode error: $e');
        }

        try {
          final expiryDate = JwtDecoder.getExpirationDate(accessToken);
          await _storage.write(
            key: 'token_expiry',
            value: expiryDate.toIso8601String(),
          );
        } catch (e) {
          debugPrint('❌ Token expiry decode error: $e');
        }

        if (userId != null) {
          final profileData = await _fetchUserProfile(accessToken, userId);

          if (profileData != null) {
            await _storeUserProfile(profileData);

            userCategory = profileData['user_category']
                ?.toString()
                .toLowerCase();

            final picUrl = profileData['pic_url'] as String?;
            if (picUrl != null && picUrl != 'no-image' && picUrl.isNotEmpty) {
              await _downloadAndSaveProfilePicture(picUrl, accessToken);
            }
          }
        }

        final syncResult = await DatabaseHelper.instance.smartSyncCatalogs(
          accessToken,
        );

        if (syncResult['success']) {
          debugPrint('✅ Synced ${syncResult['updated']} tables');
        } else {
          debugPrint('⚠️ ${syncResult['message']}');
        }

        try {
          if (mounted) {
            final connectivityManager = context.read<ConnectivityManager>();
            final fullSyncResult = await connectivityManager.performManualSync(
              isBootSync: true,
            );
            debugPrint('Full sync after login: $fullSyncResult');
          }
        } catch (e) {
          debugPrint('Full sync after login failed: $e');
        }

        if (userCategory == 'farmer' || userCategory == 'admin') {
          await _checkAndStoreFarmerShopStatus();
        }

        if (!mounted) return;

        _showSuccessSnackBar('Login Successful');
        Routes.navigateToDashboard(context);
      } else if (response.isUnauthorized) {
        throw 'Invalid phone number or password';
      } else if (response.statusCode != null && response.statusCode! >= 500) {
        throw 'Server error. Please try again later';
      } else if (response.isOffline) {
        throw 'No internet connection';
      } else if (response.isTimeout) {
        throw 'Request timeout. Please try again';
      } else {
        throw response.error ?? 'Login failed';
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

  Future<void> _checkAndStoreFarmerShopStatus() async {
    try {
      final result = await FarmStoreService.getMyShopPlace();

      if (result['success'] == true && result['hasLocation'] == true) {
        await _storage.write(key: 'has_shop_place', value: 'true');
        await _storage.write(
          key: 'shop_place_data',
          value: jsonEncode(result['shopPlace']),
        );
      } else {
        await _storage.write(key: 'has_shop_place', value: 'false');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking shop place: $e');
      await _storage.write(key: 'has_shop_place', value: 'false');
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
                  constraints: const BoxConstraints(maxWidth: 430),
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
                                  text: 'Smart Farm Assistant',
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
                          const SmartReTranslator(
                            text: 'Sign In',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const SmartReTranslator(
                            text: 'Welcome back. Please enter your details.',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _PhoneNumberField(
                            controller: _phoneController,
                            enabled: !_isLoading,
                            decoration: _modernInputDecoration(
                              hintText: 'Phone Number',
                              icon: Icons.phone_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _PasswordField(
                            controller: _passwordController,
                            obscurePassword: _obscurePassword,
                            enabled: !_isLoading,
                            onToggleVisibility: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                            decoration: _modernInputDecoration(
                              hintText: 'Password',
                              icon: Icons.lock_rounded,
                            ),
                            onSubmit: _handleLogin,
                          ),
                          const SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).push(ForgotPasswordScreen.route()),
                              style: TextButton.styleFrom(
                                foregroundColor: primaryTextColor,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 6,
                                ),
                              ),
                              child: const SmartReTranslator(
                                text: 'Forgot Password?',
                                style: TextStyle(
                                  color: primaryTextColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
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
                                      text: 'Sign In',
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
                                  : () => Routes.navigateToSignup(context),
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
                                        text: "Don't have an account?",
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
                                        text: 'Sign Up',
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

class _PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final InputDecoration decoration;

  const _PhoneNumberField({
    required this.controller,
    required this.enabled,
    required this.decoration,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      validator: Validators.validatePhone,
      enabled: enabled,
      style: const TextStyle(
        color: _LoginScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: decoration,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final bool enabled;
  final VoidCallback onToggleVisibility;
  final InputDecoration decoration;
  final Future<void> Function() onSubmit;

  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.enabled,
    required this.onToggleVisibility,
    required this.decoration,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscurePassword,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        if (enabled) {
          onSubmit();
        }
      },
      enabled: enabled,
      style: const TextStyle(
        color: _LoginScreenState.primaryTextColor,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Password is required';
        }
        if (value.trim().length < 4) {
          return 'Password must be at least 4 characters';
        }
        return null;
      },
      decoration: decoration.copyWith(
        suffixIcon: IconButton(
          onPressed: onToggleVisibility,
          icon: Icon(
            obscurePassword
                ? Icons.visibility_rounded
                : Icons.visibility_off_rounded,
            color: _LoginScreenState.secondaryTextColor,
            size: 20,
          ),
        ),
      ),
    );
  }
}
