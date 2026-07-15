// lib/screens/auth/email_verify_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../shared/smart_retranslator.dart';
import '../../utils/colors.dart';
import '../../utils/constants.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (context) => const EmailVerifyScreen());

  @override
  State<EmailVerifyScreen> createState() => _EmailVerifyScreenState();
}

class _EmailVerifyScreenState extends State<EmailVerifyScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  final List<TextEditingController> _otpControllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSendingOTP = false;
  String? _emailHint;
  String? _fullEmail;
  bool _emailVerified = false;
  bool _hasPendingOTP = false;
  bool _otpSent = false;
  int _attemptsRemaining = 5;
  int _cooldownSeconds = 0;
  int _expiresIn = 0;
  Timer? _cooldownTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadEmailFromStorage();
    _checkVerificationStatus();
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _expiryTimer?.cancel();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  Future<void> _loadEmailFromStorage() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;
        setState(() {
          _fullEmail = profileData['email'];
          _emailVerified = profileData['email_verified'] ?? false;
        });
        debugPrint('📧 Loaded email: $_fullEmail');
        debugPrint('✅ Verified: $_emailVerified');
      }
    } catch (e) {
      debugPrint('❌ Error loading email: $e');
    }
  }

  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) return value;
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (e) {
        debugPrint('Storage retry ${i + 1}: $e');
        if (i == maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  Future<void> _checkVerificationStatus() async {
    setState(() => _isLoading = true);

    try {
      final token = await _readWithRetry('access_token');
      if (token == null || token.isEmpty) {
        _showError('Please log in again');
        return;
      }

      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/email-verification/status'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _emailVerified = data['emailVerified'] ?? false;
          _emailHint = data['emailHint'];
          _hasPendingOTP = data['hasPendingOTP'] ?? false;
          _attemptsRemaining = data['attemptsRemaining'] ?? 5;
          _cooldownSeconds = data['cooldownSeconds'] ?? 0;
        });

        if (_emailVerified) {
          await _updateStorageVerificationStatus(true);
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) Navigator.of(context).pop(true);
        } else if (_hasPendingOTP) {
          setState(() => _otpSent = true);
          _startCooldownTimer();
          _calculateExpiry(data['otpExpiresAt']);
        }
      }
    } catch (e) {
      debugPrint('❌ Status check error: $e');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendOTP() async {
    setState(() => _isSendingOTP = true);

    try {
      final token = await _readWithRetry('access_token');
      if (token == null) {
        _showError('Please log in again');
        return;
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/email-verification/send-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _emailHint = data['emailHint'];
          _expiresIn = data['expiresIn'] ?? 600;
          _hasPendingOTP = true;
          _otpSent = true;
          _cooldownSeconds = 60;
        });

        _showSuccess('OTP sent to $_emailHint');
        _startCooldownTimer();
        _startExpiryTimer();

        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) _otpFocusNodes[0].requestFocus();
      } else {
        _showError(data['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      debugPrint('❌ Send OTP error: $e');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isSendingOTP = false);
    }
  }

  Future<void> _resendOTP() async {
    if (_cooldownSeconds > 0) {
      _showError('Please wait $_cooldownSeconds seconds');
      return;
    }

    setState(() => _isSendingOTP = true);

    try {
      final token = await _readWithRetry('access_token');
      if (token == null) {
        _showError('Please log in again');
        return;
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/email-verification/resend-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        setState(() {
          _expiresIn = data['expiresIn'] ?? 600;
          _cooldownSeconds = 60;
        });

        _showSuccess('OTP resent to $_emailHint');
        _startCooldownTimer();
        _startExpiryTimer();

        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      } else {
        _showError(data['message'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      debugPrint('❌ Resend error: $e');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isSendingOTP = false);
    }
  }

  Future<void> _verifyOTP() async {
    final otp = _otpControllers.map((c) => c.text).join();

    if (otp.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _readWithRetry('access_token');
      if (token == null) {
        _showError('Please log in again');
        return;
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/email-verification/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(const Duration(seconds: 30));

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        _showSuccess('Email verified successfully!');
        setState(() => _emailVerified = true);

        await _updateStorageVerificationStatus(true);

        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.of(context).pop(true);
      } else {
        _showError(data['message'] ?? 'Invalid OTP');
        setState(() {
          _attemptsRemaining = (_attemptsRemaining - 1).clamp(0, 5);
        });

        for (var controller in _otpControllers) {
          controller.clear();
        }
        _otpFocusNodes[0].requestFocus();
      }
    } catch (e) {
      debugPrint('❌ Verify error: $e');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStorageVerificationStatus(bool verified) async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson != null) {
        final profileData = jsonDecode(profileJson);
        profileData['email_verified'] = verified;
        await _storage.write(
          key: 'user_profile',
          value: jsonEncode(profileData),
        );
        debugPrint('✅ Updated email_verified: $verified');
      }
    } catch (e) {
      debugPrint('❌ Update error: $e');
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldownSeconds > 0) {
        setState(() => _cooldownSeconds--);
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();
    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_expiresIn > 0) {
        setState(() => _expiresIn--);
      } else {
        timer.cancel();
        setState(() => _hasPendingOTP = false);
      }
    });
  }

  void _calculateExpiry(String? expiresAtString) {
    if (expiresAtString == null) return;

    try {
      final expiresAt = DateTime.parse(expiresAtString);
      final now = DateTime.now();
      final difference = expiresAt.difference(now).inSeconds;
      setState(() => _expiresIn = difference > 0 ? difference : 0);
      _startExpiryTimer();
    } catch (e) {
      debugPrint('❌ Expiry calc error: $e');
    }
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: const SmartReTranslator(
          text: 'Email Verification',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SmartReTranslator(
                    text: _emailVerified ? 'Verified!' : 'Loading...',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _emailVerified
                            ? [
                                AppColors.successColor.withOpacity(0.2),
                                AppColors.successColor.withOpacity(0.1),
                              ]
                            : [
                                AppColors.primaryGreen.withOpacity(0.15),
                                AppColors.primaryGreen.withOpacity(0.05),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _emailVerified
                          ? Icons.verified
                          : _otpSent
                          ? Icons.mark_email_read
                          : Icons.email_outlined,
                      size: 70,
                      color: _emailVerified
                          ? AppColors.successColor
                          : AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SmartReTranslator(
                    text: _emailVerified
                        ? 'Email Verified!'
                        : _otpSent
                        ? 'Enter Verification Code'
                        : 'Verify Your Email',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  if (_otpSent && !_emailVerified) ...[
                    const SmartReTranslator(
                      text: 'We\'ve sent a 6-digit code to',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _emailHint ?? _fullEmail ?? 'your email',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryGreen,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ] else if (!_emailVerified) ...[
                    SmartReTranslator(
                      text: _fullEmail != null
                          ? 'Click below to send verification code to\n$_fullEmail'
                          : 'Verify your email to secure your account',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  if (_emailVerified) ...[
                    const SmartReTranslator(
                      text: 'Your email has been successfully verified!',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColors.successColor,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (!_emailVerified) ...[
                    // ✅ Send OTP Button with text wrapping
                    if (!_hasPendingOTP && !_otpSent) ...[
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isSendingOTP ? null : _sendOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: AppColors.primaryGreen.withOpacity(
                                  0.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: _isSendingOTP
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.send, size: 18),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: SmartReTranslator(
                                            text: 'Send Verification Code',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            textAlign: TextAlign.center,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    if (_hasPendingOTP || _otpSent) ...[
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 350),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: SizedBox(
                                  width: 45,
                                  child: TextFormField(
                                    controller: _otpControllers[index],
                                    focusNode: _otpFocusNodes[index],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppColors.primaryGreen
                                              .withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(
                                          color: AppColors.primaryGreen
                                              .withOpacity(0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(
                                          color: AppColors.primaryGreen,
                                          width: 2.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            vertical: 14,
                                          ),
                                    ),
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                    keyboardType: TextInputType.number,
                                    maxLength: 1,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    onChanged: (value) {
                                      if (value.isNotEmpty && index < 5) {
                                        _otpFocusNodes[index + 1]
                                            .requestFocus();
                                      } else if (value.isEmpty && index > 0) {
                                        _otpFocusNodes[index - 1]
                                            .requestFocus();
                                      }

                                      if (index == 5 && value.isNotEmpty) {
                                        FocusScope.of(context).unfocus();
                                        _verifyOTP();
                                      }
                                    },
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: _expiresIn < 60
                                          ? AppColors.errorColor
                                          : AppColors.primaryGreen,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      _formatTime(_expiresIn),
                                      style: TextStyle(
                                        color: _expiresIn < 60
                                            ? AppColors.errorColor
                                            : AppColors.textPrimary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  width: 1,
                                  height: 18,
                                  color: Colors.grey.shade300,
                                ),
                                Flexible(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.refresh,
                                        size: 16,
                                        color: _attemptsRemaining < 2
                                            ? AppColors.errorColor
                                            : AppColors.primaryGreen,
                                      ),
                                      const SizedBox(width: 5),
                                      Flexible(
                                        child: SmartReTranslator(
                                          text:
                                              '$_attemptsRemaining tries left',
                                          style: TextStyle(
                                            color: _attemptsRemaining < 2
                                                ? AppColors.errorColor
                                                : AppColors.textPrimary,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ✅ Verify Button with text wrapping
                      Center(
                        child: FractionallySizedBox(
                          widthFactor: 0.75,
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _verifyOTP,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: AppColors.primaryGreen.withOpacity(
                                  0.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: SmartReTranslator(
                                      text: 'Verify Code',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      Center(
                        child: TextButton.icon(
                          onPressed: _cooldownSeconds > 0 || _isSendingOTP
                              ? null
                              : _resendOTP,
                          icon: Icon(
                            _cooldownSeconds > 0 ? Icons.timer : Icons.refresh,
                            size: 16,
                          ),
                          label: _cooldownSeconds > 0
                              ? SmartReTranslator(
                                  text: '$_cooldownSeconds seconds',
                                  style: const TextStyle(fontSize: 14),
                                )
                              : const SmartReTranslator(
                                  text: 'Resend Code',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                          style: TextButton.styleFrom(
                            foregroundColor: _cooldownSeconds > 0
                                ? AppColors.textSecondary
                                : AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],

                  // ✅ Continue Button with text wrapping
                  if (_emailVerified) ...[
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.successColor,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shadowColor: AppColors.successColor.withOpacity(
                                0.4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.arrow_forward, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: SmartReTranslator(
                                    text: 'Continue',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
