// lib/screens/auth/forgot_password_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../shared/smart_retranslator.dart';
import '../shared/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../src/services/api_service.dart';
import 'login_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  static MaterialPageRoute route() =>
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen());

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

    if (mobile.isEmpty || mobile.length < 7 || mobile.length > 15) {
      _showError('Please enter a valid mobile number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // ✅ USE ApiService
      final response = await ApiService.instance.get(
        '/forgot-password/status/$mobile',
        requiresAuth: false,
        timeout: const Duration(seconds: 15),
      );

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
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendResetRequest() async {
    final mobile = _mobileController.text.trim();

    if (mobile.isEmpty || mobile.length != 10) {
      _showError('Please enter a valid 10-digit mobile number');
      return;
    }

    // Check status first
    await _checkRequestStatus();

    if (!_canRequest) return;

    setState(() => _isLoading = true);

    try {
      // ✅ USE ApiService
      final response = await ApiService.instance.post(
        '/forgot-password/request',
        body: {'mobile': int.parse(mobile)},
        requiresAuth: false,
        timeout: const Duration(seconds: 30),
      );

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
        _showError(data['message'] ?? 'Too many requests. Try again later.');
        setState(() {
          _canRequest = false;
          _attemptsRemaining = 0;
        });
      } else if (response.statusCode == 404) {
        _showError('Mobile number not found');
      } else {
        _showError(data['message'] ?? 'Failed to send reset link');
      }
    } catch (e) {
      debugPrint('❌ Reset request error: $e');
      _showError('Connection error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: BackAppBar(
        title: 'Forgot Password',
        onBackPressed: () => Navigator.of(context).pop(),
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primaryGreen,
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _requestSent
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
                      _requestSent ? Icons.mark_email_read : Icons.lock_reset,
                      size: 70,
                      color: _requestSent
                          ? AppColors.successColor
                          : AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Title
                  SmartReTranslator(
                    text: _requestSent
                        ? 'Reset Link Sent!'
                        : 'Reset Your Password',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),

                  // Description
                  if (_requestSent) ...[
                    const SmartReTranslator(
                      text: 'A password reset link has been sent to',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    if (_emailHint != null)
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
                          _emailHint!,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryGreen,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 16),
                    const SmartReTranslator(
                      text:
                          'Please check your email and follow the instructions to reset your password.',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const SmartReTranslator(
                      text:
                          'Enter your registered mobile number to receive a password reset link via email',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],

                  const SizedBox(height: 32),

                  if (!_requestSent) ...[
                    // Mobile Number Input at 75% width
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: TextFormField(
                          controller: _mobileController,
                          decoration: InputDecoration(
                            labelText: null,
                            hintText: null,
                            label: const SmartReTranslator(
                              text: 'Mobile Number',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                            prefixIcon: const Icon(
                              Icons.phone,
                              color: AppColors.primaryGreen,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: AppColors.primaryGreen.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 2,
                              ),
                            ),
                            counterText: '',
                          ),
                          keyboardType: TextInputType.phone,
                          maxLength: 10,
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Attempts Info
                    if (_attemptsRemaining < 3)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.orange.shade300,
                              width: 1.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 18,
                                color: Colors.orange.shade700,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: SmartReTranslator(
                                  text:
                                      '$_attemptsRemaining attempts remaining',
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
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
                      ),
                    const SizedBox(height: 24),

                    // Send Request Button
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: _canRequest ? _sendResetRequest : null,
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
                                const Icon(Icons.send, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: SmartReTranslator(
                                    text: 'Send Reset Link',
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

                  // Back to Login Button
                  if (_requestSent) ...[
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.75,
                        child: SizedBox(
                          height: 52,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                LoginScreen.route(),
                                (route) => false,
                              );
                            },
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
                                const Icon(Icons.login, size: 18),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: SmartReTranslator(
                                    text: 'Back to Login',
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
