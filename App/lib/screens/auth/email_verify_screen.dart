// lib/screens/auth/email_verify_screen.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../shared/custom_app_bar.dart';
import '../shared/smart_retranslator.dart';

class EmailVerifyScreen extends StatefulWidget {
  const EmailVerifyScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (_) => const EmailVerifyScreen());

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
  bool _emailVerified = false;
  bool _hasPendingOTP = false;
  bool _otpSent = false;

  String? _emailHint;
  String? _fullEmail;

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

    for (final controller in _otpControllers) {
      controller.dispose();
    }

    for (final node in _otpFocusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  // ===========================================================================
  // STORAGE
  // ===========================================================================

  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);

        if (value != null && value.isNotEmpty) {
          return value;
        }

        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (e) {
        debugPrint('Storage retry ${i + 1}: $e');

        if (i == maxRetries - 1) {
          rethrow;
        }
      }
    }

    return null;
  }

  Future<void> _loadEmailFromStorage() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson == null || profileJson.isEmpty) {
        return;
      }

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

      if (!mounted) return;

      setState(() {
        _fullEmail = profileData['email']?.toString();

        _emailVerified =
            profileData['email_verified'] == true ||
            profileData['emailverified'] == true;
      });
    } catch (e) {
      debugPrint('EMAIL_STORAGE_LOAD_ERROR: $e');
    }
  }

  Future<void> _updateStorageVerificationStatus(bool verified) async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson == null || profileJson.isEmpty) {
        return;
      }

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

      profileData['email_verified'] = verified;

      await _storage.write(key: 'user_profile', value: jsonEncode(profileData));
    } catch (e) {
      debugPrint('EMAIL_VERIFICATION_STORAGE_ERROR: $e');
    }
  }

  // ===========================================================================
  // STATUS
  // ===========================================================================

  Future<void> _checkVerificationStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

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

      if (response.statusCode != 200) {
        return;
      }

      final data = jsonDecode(response.body);

      if (!mounted) return;

      setState(() {
        _emailVerified = data['emailVerified'] == true;

        _emailHint = data['emailHint']?.toString();

        _hasPendingOTP = data['hasPendingOTP'] == true;

        _attemptsRemaining = data['attemptsRemaining'] ?? 5;

        _cooldownSeconds = data['cooldownSeconds'] ?? 0;
      });

      if (_emailVerified) {
        await _updateStorageVerificationStatus(true);

        if (!mounted) return;

        await Future.delayed(const Duration(milliseconds: 400));

        if (mounted) {
          Navigator.of(context).pop(true);
        }

        return;
      }

      if (_hasPendingOTP) {
        setState(() {
          _otpSent = true;
        });

        _startCooldownTimer();
        _calculateExpiry(data['otpExpiresAt']);
      }
    } catch (e) {
      debugPrint('EMAIL_STATUS_ERROR: $e');

      if (mounted) {
        _showError('Connection error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // SEND OTP
  // ===========================================================================

  Future<void> _sendOTP() async {
    if (_isSendingOTP) return;

    setState(() {
      _isSendingOTP = true;
    });

    try {
      final token = await _readWithRetry('access_token');

      if (token == null || token.isEmpty) {
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
        if (!mounted) return;

        setState(() {
          _emailHint = data['emailHint']?.toString();

          _expiresIn = data['expiresIn'] ?? 600;

          _hasPendingOTP = true;
          _otpSent = true;
          _cooldownSeconds = 60;
        });

        _clearOTP();

        _showSuccess(
          'Verification code sent to '
          '${_emailHint ?? 'your email'}',
        );

        _startCooldownTimer();
        _startExpiryTimer();

        await Future.delayed(const Duration(milliseconds: 250));

        if (mounted) {
          _otpFocusNodes.first.requestFocus();
        }
      } else {
        _showError(data['message'] ?? 'Failed to send OTP');
      }
    } catch (e) {
      debugPrint('SEND_OTP_ERROR: $e');

      if (mounted) {
        _showError('Connection error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  // ===========================================================================
  // RESEND OTP
  // ===========================================================================

  Future<void> _resendOTP() async {
    if (_cooldownSeconds > 0 || _isSendingOTP) {
      return;
    }

    setState(() {
      _isSendingOTP = true;
    });

    try {
      final token = await _readWithRetry('access_token');

      if (token == null || token.isEmpty) {
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
        if (!mounted) return;

        setState(() {
          _expiresIn = data['expiresIn'] ?? 600;

          _cooldownSeconds = 60;
          _hasPendingOTP = true;
          _otpSent = true;
        });

        _clearOTP();

        _showSuccess(
          'Verification code resent to '
          '${_emailHint ?? 'your email'}',
        );

        _startCooldownTimer();
        _startExpiryTimer();

        _otpFocusNodes.first.requestFocus();
      } else {
        _showError(data['message'] ?? 'Failed to resend OTP');
      }
    } catch (e) {
      debugPrint('RESEND_OTP_ERROR: $e');

      if (mounted) {
        _showError('Connection error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  // ===========================================================================
  // VERIFY OTP
  // ===========================================================================

  Future<void> _verifyOTP() async {
    if (_isLoading) return;

    final otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      _showError('Please enter all 6 digits');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _readWithRetry('access_token');

      if (token == null || token.isEmpty) {
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
        if (!mounted) return;

        setState(() {
          _emailVerified = true;
          _hasPendingOTP = false;
        });

        _cooldownTimer?.cancel();
        _expiryTimer?.cancel();

        await _updateStorageVerificationStatus(true);

        _showSuccess('Email verified successfully!');

        await Future.delayed(const Duration(milliseconds: 900));

        if (mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        if (!mounted) return;

        setState(() {
          _attemptsRemaining = (_attemptsRemaining - 1).clamp(0, 5);
        });

        _clearOTP();

        _showError(data['message'] ?? 'Invalid verification code');

        _otpFocusNodes.first.requestFocus();
      }
    } catch (e) {
      debugPrint('VERIFY_OTP_ERROR: $e');

      if (mounted) {
        _showError('Connection error. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ===========================================================================
  // OTP HELPERS
  // ===========================================================================

  void _clearOTP() {
    for (final controller in _otpControllers) {
      controller.clear();
    }
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
      return;
    }

    if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
      return;
    }

    if (index == 5 && value.isNotEmpty) {
      FocusScope.of(context).unfocus();

      final otp = _otpControllers.map((controller) => controller.text).join();

      if (otp.length == 6) {
        _verifyOTP();
      }
    }
  }

  // ===========================================================================
  // TIMERS
  // ===========================================================================

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();

    if (_cooldownSeconds <= 0) {
      return;
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_cooldownSeconds > 0) {
        setState(() {
          _cooldownSeconds--;
        });
      } else {
        timer.cancel();
      }
    });
  }

  void _startExpiryTimer() {
    _expiryTimer?.cancel();

    if (_expiresIn <= 0) {
      return;
    }

    _expiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (_expiresIn > 0) {
        setState(() {
          _expiresIn--;
        });
      } else {
        timer.cancel();

        setState(() {
          _hasPendingOTP = false;
        });
      }
    });
  }

  void _calculateExpiry(String? expiresAtString) {
    if (expiresAtString == null) {
      return;
    }

    try {
      final expiresAt = DateTime.parse(expiresAtString);

      final difference = expiresAt.difference(DateTime.now()).inSeconds;

      if (!mounted) return;

      setState(() {
        _expiresIn = difference > 0 ? difference : 0;
      });

      _startExpiryTimer();
    } catch (e) {
      debugPrint('OTP_EXPIRY_ERROR: $e');
    }
  }

  // ===========================================================================
  // SNACKBARS
  // ===========================================================================

  void _showSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.successColor,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.errorColor,
        duration: const Duration(seconds: 3),
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;

    final remaining = seconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  // ===========================================================================
  // BUILD
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Email Verification',
        backgroundColor: Colors.transparent,
        elevation: 0,
        showOnlineStatus: true,
        onBackPressed: () => Navigator.of(context).pop(false),
      ),
      body: _isLoading && !_otpSent
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                children: [
                  _buildVerificationHeader(),
                  const SizedBox(height: 18),
                  _buildEmailCard(),
                  const SizedBox(height: 12),
                  if (_emailVerified)
                    _buildVerifiedSection()
                  else if (_otpSent)
                    _buildOTPSection()
                  else
                    _buildSendSection(),
                ],
              ),
            ),
    );
  }

  // ===========================================================================
  // VERIFICATION HEADER
  // ===========================================================================

  Widget _buildVerificationHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: _emailVerified
                  ? AppColors.successColor.withOpacity(0.10)
                  : AppColors.primaryGreen.withOpacity(0.10),
              shape: BoxShape.circle,
              border: Border.all(
                color: _emailVerified
                    ? AppColors.successColor.withOpacity(0.25)
                    : AppColors.primaryGreen.withOpacity(0.20),
                width: 1.5,
              ),
            ),
            child: Icon(
              _emailVerified
                  ? Icons.verified_rounded
                  : _otpSent
                  ? Icons.mark_email_read_rounded
                  : Icons.email_outlined,
              size: 42,
              color: _emailVerified
                  ? AppColors.successColor
                  : AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 14),
          SmartReTranslator(
            text: _emailVerified
                ? 'Email Verified!'
                : _otpSent
                ? 'Enter Verification Code'
                : 'Verify Your Email',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SmartReTranslator(
            text: _emailVerified
                ? 'Your email has been successfully verified.'
                : _otpSent
                ? 'Enter the 6-digit code sent to your email address.'
                : 'Verify your email to keep your Agrhi account secure.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // EMAIL CARD
  // ===========================================================================

  Widget _buildEmailCard() {
    final email = _emailHint ?? _fullEmail;

    if (email == null || email.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.email_outlined,
              color: AppColors.primaryGreen,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartReTranslator(
                  text: 'Email Address',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_emailVerified)
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.successColor.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified,
                color: AppColors.successColor,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // SEND SECTION
  // ===========================================================================

  Widget _buildSendSection() {
    return _SectionCard(
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.security_outlined,
            title: 'Secure your account',
            description: 'Verify your email to protect your Agrhi account.',
          ),
          const SizedBox(height: 16),
          _PrimaryButton(
            icon: Icons.mark_email_read_outlined,
            text: 'Send Verification Code',
            loading: _isSendingOTP,
            onPressed: _sendOTP,
          ),
          const SizedBox(height: 10),
          const SmartReTranslator(
            text: 'The verification code will be valid for 10 minutes.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // OTP SECTION
  // ===========================================================================

  Widget _buildOTPSection() {
    return _SectionCard(
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.lock_outline_rounded,
            title: 'Enter your verification code',
            description: 'We sent a 6-digit code to the email address above.',
          ),
          const SizedBox(height: 20),
          _buildOTPFields(),
          const SizedBox(height: 16),
          _buildOTPStatus(),
          const SizedBox(height: 16),
          _PrimaryButton(
            icon: Icons.verified_outlined,
            text: 'Verify Code',
            loading: _isLoading,
            onPressed: _isLoading ? null : _verifyOTP,
          ),
          const SizedBox(height: 6),
          _buildResendButton(),
        ],
      ),
    );
  }

  // ===========================================================================
  // INFO ROW
  // ===========================================================================

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartReTranslator(
                text: title,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              SmartReTranslator(
                text: description,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // OTP FIELDS
  // ===========================================================================

  Widget _buildOTPFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 340 ? 4.0 : 6.0;

        final availableWidth = constraints.maxWidth - (spacing * 12);

        final fieldWidth = (availableWidth / 6).clamp(40.0, 50.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(6, (index) {
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: spacing),
              child: SizedBox(
                width: fieldWidth,
                height: 54,
                child: TextFormField(
                  controller: _otpControllers[index],
                  focusNode: _otpFocusNodes[index],
                  keyboardType: TextInputType.number,
                  textInputAction: index == 5
                      ? TextInputAction.done
                      : TextInputAction.next,
                  textAlign: TextAlign.center,
                  maxLength: 1,
                  cursorColor: AppColors.primaryGreen,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: const Color(0xFFF8FAF7),
                    contentPadding: EdgeInsets.zero,
                    border: _otpBorder(),
                    enabledBorder: _otpBorder(),
                    focusedBorder: _otpFocusedBorder(),
                  ),
                  onChanged: (value) {
                    _onOTPChanged(index, value);
                  },
                ),
              ),
            );
          }),
        );
      },
    );
  }

  OutlineInputBorder _otpBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: Colors.black.withOpacity(0.08), width: 1),
    );
  }

  OutlineInputBorder _otpFocusedBorder() {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
    );
  }

  // ===========================================================================
  // OTP STATUS
  // ===========================================================================

  Widget _buildOTPStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAF7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _StatusItem(
              icon: Icons.timer_outlined,
              value: _formatTime(_expiresIn),
              label: 'Expires',
              danger: _expiresIn < 60,
            ),
          ),
          Container(
            width: 1,
            height: 30,
            color: Colors.black.withOpacity(0.08),
          ),
          Expanded(
            child: _StatusItem(
              icon: Icons.lock_outline_rounded,
              value: '$_attemptsRemaining',
              label: 'Attempts',
              danger: _attemptsRemaining < 2,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // RESEND BUTTON
  // ===========================================================================

  Widget _buildResendButton() {
    final canResend = _cooldownSeconds <= 0 && !_isSendingOTP;

    return TextButton(
      onPressed: canResend ? _resendOTP : null,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreen,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _cooldownSeconds > 0 ? Icons.timer_outlined : Icons.refresh_rounded,
            size: 17,
          ),
          const SizedBox(width: 6),
          SmartReTranslator(
            text: _cooldownSeconds > 0
                ? 'Resend in ${_cooldownSeconds}s'
                : 'Resend Code',
            style: TextStyle(
              color: canResend
                  ? AppColors.primaryGreen
                  : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // VERIFIED SECTION
  // ===========================================================================

  Widget _buildVerifiedSection() {
    return _SectionCard(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.successColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.successColor.withOpacity(0.18),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.successColor,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: SmartReTranslator(
                    text: 'Your email is verified and your account is secure.',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SuccessButton(onPressed: () => Navigator.of(context).pop(true)),
        ],
      ),
    );
  }
}

// =============================================================================
// SECTION CARD
// =============================================================================

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.94),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================================
// PRIMARY BUTTON
// =============================================================================

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.text,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.55),
          disabledForegroundColor: Colors.white70,
          elevation: 2,
          shadowColor: AppColors.primaryGreen.withOpacity(0.22),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 19),
                  const SizedBox(width: 9),
                  Flexible(
                    child: SmartReTranslator(
                      text: text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// =============================================================================
// SUCCESS BUTTON
// =============================================================================

class _SuccessButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _SuccessButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.successColor,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: AppColors.successColor.withOpacity(0.20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.arrow_forward_rounded, size: 19),
            SizedBox(width: 8),
            SmartReTranslator(
              text: 'Continue',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// STATUS ITEM
// =============================================================================

class _StatusItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final bool danger;

  const _StatusItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.danger,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.errorColor : AppColors.primaryGreen;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                color: danger ? AppColors.errorColor : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
