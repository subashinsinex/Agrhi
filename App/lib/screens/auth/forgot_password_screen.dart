// lib/screens/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';

import '../shared/smart_retranslator.dart';
import '../shared/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../src/services/api_service.dart';
import 'login_screen.dart';

import '../../utils/page_transitions.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static Route<void> route() {
    return smoothPageRoute(const ForgotPasswordScreen());
  }

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _mobileController = TextEditingController();

  bool _isLoading = false;
  bool _requestSent = false;
  String? _emailHint;

  int _attemptsRemaining = 3;
  bool _canRequest = true;

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _checkRequestStatus() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    try {
      final response = await ApiService.instance.get(
        '/forgot-password/status/$mobile',
        requiresAuth: false,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;

      if (response.isSuccess) {
        final data = response.data;

        setState(() {
          _canRequest = data['canRequest'] ?? true;
          _attemptsRemaining = data['attemptsRemaining'] ?? 3;
        });

        if (!_canRequest) {
          _showError('Too many attempts. Please try again later.');
        }
      }
    } catch (e) {
      debugPrint('❌ Status check error: $e');
    }
  }

  Future<void> _sendResetRequest() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      /*
       * Check request status first.
       *
       * IMPORTANT:
       * We don't call _checkRequestStatus() here because that method
       * does not control the loading state.
       */
      final statusResponse = await ApiService.instance.get(
        '/forgot-password/status/$mobile',
        requiresAuth: false,
        timeout: const Duration(seconds: 15),
      );

      if (!mounted) return;

      if (statusResponse.isSuccess) {
        final statusData = statusResponse.data;

        setState(() {
          _canRequest = statusData['canRequest'] ?? true;
          _attemptsRemaining = statusData['attemptsRemaining'] ?? 3;
        });

        if (!_canRequest) {
          _showError('Too many attempts. Please try again later.');

          setState(() {
            _isLoading = false;
          });

          return;
        }
      }

      final response = await ApiService.instance.post(
        '/forgot-password/request',
        body: {'mobile': int.parse(mobile)},
        requiresAuth: false,
        timeout: const Duration(seconds: 30),
      );

      if (!mounted) return;

      final data = response.data;

      if (response.isSuccess && data['success'] == true) {
        setState(() {
          _requestSent = true;
          _emailHint = data['emailHint'];
        });

        _showSuccess(
          data['message'] ?? 'Reset link sent to your registered email address',
        );
      } else if (response.statusCode == 429) {
        setState(() {
          _canRequest = false;
          _attemptsRemaining = 0;
        });

        _showError(data['message'] ?? 'Too many requests. Try again later.');
      } else if (response.statusCode == 404) {
        _showError('Mobile number not found');
      } else {
        _showError(data['message'] ?? 'Failed to send reset link');
      }
    } catch (e) {
      debugPrint('❌ Reset request error: $e');

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
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
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
              size: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SmartReTranslator(
                text: message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  Widget _buildHeaderIcon() {
    final bool success = _requestSent;

    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: success
            ? AppColors.successColor.withOpacity(0.10)
            : AppColors.primaryGreen.withOpacity(0.10),
      ),
      child: Center(
        child: Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: success
                ? AppColors.successColor.withOpacity(0.15)
                : AppColors.primaryGreen.withOpacity(0.15),
          ),
          child: Icon(
            success ? Icons.mark_email_read_rounded : Icons.lock_reset_rounded,
            size: 38,
            color: success ? AppColors.successColor : AppColors.primaryGreen,
          ),
        ),
      ),
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      enabled: !_isLoading,
      textInputAction: TextInputAction.done,
      decoration: InputDecoration(
        counterText: '',
        label: const SmartReTranslator(
          text: 'Mobile Number',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        prefixIcon: const Icon(
          Icons.phone_outlined,
          color: AppColors.primaryGreen,
        ),
        filled: true,
        fillColor: AppColors.primaryGreen.withOpacity(0.025),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primaryGreen.withOpacity(0.20),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primaryGreen.withOpacity(0.20),
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _canRequest && !_isLoading ? _sendResetRequest : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          disabledBackgroundColor: AppColors.primaryGreen.withOpacity(0.45),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.email_outlined, size: 20),
            SizedBox(width: 9),
            SmartReTranslator(
              text: 'Send Reset Link',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessContent() {
    return Column(
      children: [
        const SmartReTranslator(
          text: 'A password reset link has been sent to',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        if (_emailHint != null) ...[
          const SizedBox(height: 14),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.email_outlined,
                  size: 18,
                  color: AppColors.primaryGreen,
                ),
                const SizedBox(width: 9),
                Flexible(
                  child: Text(
                    _emailHint!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryGreen,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 18),

        const SmartReTranslator(
          text:
              'Please check your email and follow the instructions to reset your password.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: () {
              Navigator.of(
                context,
              ).pushAndRemoveUntil(LoginScreen.route(), (route) => false);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.successColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, size: 20),
                SizedBox(width: 9),
                SmartReTranslator(
                  text: 'Back to Login',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequestContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SmartReTranslator(
          text:
              'Enter your registered mobile number to receive a password reset link via email.',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 28),

        _buildMobileField(),

        if (_attemptsRemaining < 3) ...[
          const SizedBox(height: 14),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.25)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: SmartReTranslator(
                    text: '$_attemptsRemaining attempts remaining',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 22),

        _buildPrimaryButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: BackAppBar(
        title: 'Forgot Password',
        onBackPressed: () {
          Navigator.of(context).pop();
        },
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.8,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    SmartReTranslator(
                      text: 'Processing...',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 36, 24, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Column(
                      children: [
                        _buildHeaderIcon(),

                        const SizedBox(height: 24),

                        SmartReTranslator(
                          text: _requestSent
                              ? 'Reset Link Sent!'
                              : 'Reset Your Password',
                          style: const TextStyle(
                            fontSize: 25,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 9),

                        if (_requestSent)
                          _buildSuccessContent()
                        else
                          _buildRequestContent(),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
