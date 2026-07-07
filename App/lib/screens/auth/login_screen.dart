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
    ], highPriority: true);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// ✅ Fetch user profile from server
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

  /// ✅ Store user profile in secure storage
  Future<void> _storeUserProfile(Map<String, dynamic> profileData) async {
    await _storage.write(key: 'user_profile', value: jsonEncode(profileData));
    debugPrint('💾 Profile data stored in secure storage');
  }

  /// ✅ Download and save profile picture to local storage
  Future<void> _downloadAndSaveProfilePicture(
    String picUrl,
    String accessToken,
  ) async {
    try {
      // Skip if no image or default image
      if (picUrl == 'no-image' || picUrl.isEmpty) {
        debugPrint('ℹ️ No profile picture to download');
        return;
      }

      debugPrint('📥 Downloading profile picture: $picUrl');

      // Construct full URL
      String fullUrl;
      if (picUrl.startsWith('http')) {
        fullUrl = picUrl;
      } else {
        final baseUrl = AppConstants.baseUrl.replaceAll('/api', '');
        fullUrl = '$baseUrl$picUrl';
      }

      debugPrint('🌐 Full URL: $fullUrl');

      // Download image
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

      // Get app directory for storing images
      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${directory.path}/profile_pictures');

      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      // Delete old profile pictures (keep only latest)
      await _deleteOldProfilePictures(profileDir);

      // Generate local filename based on current timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = picUrl.split('.').last.split('?').first;
      final localPath = '${profileDir.path}/profile_$timestamp.$extension';

      // Save image to local file
      final file = File(localPath);
      await file.writeAsBytes(response.bodyBytes);

      debugPrint('💾 Profile picture saved: $localPath');
      debugPrint('📊 File size: ${await file.length()} bytes');

      // Store local path and server URL in secure storage
      await _storage.write(key: 'profile_image_local_path', value: localPath);
      await _storage.write(key: 'profile_image_server_url', value: picUrl);

      debugPrint('✅ Profile picture downloaded and saved successfully');
    } catch (e) {
      debugPrint('⚠️ Profile picture download failed: $e');
      // Don't fail login if profile picture download fails
    }
  }

  /// ✅ Delete old profile pictures to save space
  Future<void> _deleteOldProfilePictures(Directory profileDir) async {
    try {
      if (await profileDir.exists()) {
        final files = profileDir.listSync();
        for (var file in files) {
          if (file is File && file.path.contains('profile_')) {
            await file.delete();
            debugPrint('🗑️ Deleted old profile picture: ${file.path}');
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
            } else {
              debugPrint('ℹ️ No profile picture available');
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
      debugPrint('🔍 Checking farmer shop place status...');

      final result = await FarmStoreService.getMyShopPlace();

      if (result['success'] == true && result['hasLocation'] == true) {
        await _storage.write(key: 'has_shop_place', value: 'true');
        await _storage.write(
          key: 'shop_place_data',
          value: jsonEncode(result['shopPlace']),
        );
        debugPrint('✅ Farmer has shop place set');
      } else {
        await _storage.write(key: 'has_shop_place', value: 'false');
        debugPrint('ℹ️ Farmer needs to set shop place');
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
                        autovalidateMode: AutovalidateMode.disabled,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            const SizedBox(height: 60),

                            // Logo Section
                            Column(
                              children: [
                                CircleAvatar(
                                  radius: 80,
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/logo.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  'AGRHI',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryGreen,
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const SmartReTranslator(
                                  text: 'Smart Farm Assistant',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),

                            // Form Section
                            Column(
                              children: [
                                _PhoneNumberField(
                                  controller: _phoneController,
                                  enabled: !_isLoading,
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
                                ),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _isLoading
                                        ? null
                                        : () => Navigator.of(
                                            context,
                                          ).push(ForgotPasswordScreen.route()),
                                    child: const SmartReTranslator(
                                      text: 'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.primaryGreen,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _handleLogin,
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
                                            text: 'Sign In',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1,
                                            ),
                                          ),
                                  ),
                                ),
                              ],
                            ),

                            // Sign Up Link
                            GestureDetector(
                              onTap: _isLoading
                                  ? null
                                  : () => Routes.navigateToSignup(context),
                              child: RichText(
                                text: TextSpan(
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 16,
                                  ),
                                  children: [
                                    const WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: SmartReTranslator(
                                        text: "Don't have an account?",
                                        style: TextStyle(fontSize: 16),
                                      ),
                                    ),
                                    const TextSpan(text: ' '),
                                    WidgetSpan(
                                      alignment: PlaceholderAlignment.baseline,
                                      baseline: TextBaseline.alphabetic,
                                      child: SmartReTranslator(
                                        text: 'Sign Up',
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

// ✅ Phone Number Field with label above
class _PhoneNumberField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const _PhoneNumberField({required this.controller, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: const SmartReTranslator(
            text: 'Phone Number',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.phone, color: AppColors.primaryGreen),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          keyboardType: TextInputType.phone,
          validator: Validators.validatePhone,
          enabled: enabled,
        ),
      ],
    );
  }
}

// ✅ Password Field with label above
class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final bool enabled;
  final VoidCallback onToggleVisibility;

  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.enabled,
    required this.onToggleVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: const SmartReTranslator(
            text: 'Password',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.lock, color: AppColors.primaryGreen),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility : Icons.visibility_off,
                color: AppColors.textSecondary,
              ),
              onPressed: onToggleVisibility,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey,
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: AppColors.cardBackgroundGrey.withOpacity(0.5),
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
          obscureText: obscurePassword,
          enabled: enabled,
        ),
      ],
    );
  }
}
