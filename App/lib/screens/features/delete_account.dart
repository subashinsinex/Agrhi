// lib/screens/features/delete_account.dart

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../../utils/page_transitions.dart';
import '../auth/email_verify_screen.dart';
import '../shared/custom_app_bar.dart';
import '../shared/smart_retranslator.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  static Route<bool> route() =>
      smoothPageRoute<bool>(const DeleteAccountScreen());

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
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

  bool _isInitializing = true;
  bool _isSendingOTP = false;
  bool _isVerifyingOTP = false;
  bool _isSubmittingRequest = false;

  bool _emailVerified = false;
  bool _otpSent = false;
  bool _otpVerified = false;
  bool _requestSubmitted = false;

  String? _fullEmail;
  String? _emailHint;
  String? _deletionVerificationToken;
  String? _scheduledDeletionAt;

  int _attemptsRemaining = 5;
  int _cooldownSeconds = 0;
  int _expiresIn = 0;

  Timer? _cooldownTimer;
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    _loadAccount();
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

  Future<void> _loadAccount() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson == null || profileJson.isEmpty) {
        if (mounted) {
          _showError('Account information could not be loaded.');
        }
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
      debugPrint('DELETE_ACCOUNT_PROFILE_ERROR: $e');

      if (mounted) {
        _showError('Unable to load your account information.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  Future<String?> _readToken() async {
    try {
      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        _showError('Please log in again.');
        return null;
      }

      return token;
    } catch (e) {
      debugPrint('DELETE_ACCOUNT_TOKEN_ERROR: $e');
      _showError('Unable to access your login session.');
      return null;
    }
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    try {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}

    return <String, dynamic>{};
  }

  Future<void> _sendOTP() async {
    if (_isSendingOTP || !_emailVerified) return;

    setState(() {
      _isSendingOTP = true;
    });

    try {
      final token = await _readToken();
      if (token == null) return;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/account-deletion/send-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        setState(() {
          _emailHint = data['emailHint']?.toString();
          _expiresIn = _readInt(data['expiresIn'], 600);
          _cooldownSeconds = _readInt(data['cooldownSeconds'], 60);
          _attemptsRemaining = _readInt(data['attemptsRemaining'], 5);
          _otpSent = true;
          _otpVerified = false;
          _deletionVerificationToken = null;
        });

        _clearOTP();
        _startCooldownTimer();
        _startExpiryTimer();

        _showSuccess('Verification code sent to $_displayEmail.');

        await Future.delayed(const Duration(milliseconds: 250));

        if (mounted) {
          _otpFocusNodes.first.requestFocus();
        }
      } else {
        _showError(
          data['message']?.toString() ??
              'Unable to send the verification code.',
        );
      }
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } catch (e) {
      debugPrint('DELETE_ACCOUNT_SEND_OTP_ERROR: $e');
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_isSendingOTP || _cooldownSeconds > 0 || _otpVerified) return;

    setState(() {
      _isSendingOTP = true;
    });

    try {
      final token = await _readToken();
      if (token == null) return;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/account-deletion/resend-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        setState(() {
          _emailHint = data['emailHint']?.toString() ?? _emailHint;
          _expiresIn = _readInt(data['expiresIn'], 600);
          _cooldownSeconds = _readInt(data['cooldownSeconds'], 60);
          _attemptsRemaining = _readInt(data['attemptsRemaining'], 5);
          _otpSent = true;
          _otpVerified = false;
          _deletionVerificationToken = null;
        });

        _clearOTP();
        _startCooldownTimer();
        _startExpiryTimer();

        _showSuccess('A new verification code was sent to $_displayEmail.');

        await Future.delayed(const Duration(milliseconds: 200));

        if (mounted) {
          _otpFocusNodes.first.requestFocus();
        }
      } else {
        _showError(
          data['message']?.toString() ??
              'Unable to resend the verification code.',
        );
      }
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } catch (e) {
      debugPrint('DELETE_ACCOUNT_RESEND_OTP_ERROR: $e');
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isSendingOTP = false;
        });
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_isVerifyingOTP || _otpVerified || _expiresIn <= 0) return;

    final otp = _otpControllers.map((controller) => controller.text).join();

    if (otp.length != 6) {
      _showError('Please enter all 6 digits.');
      return;
    }

    setState(() {
      _isVerifyingOTP = true;
    });

    try {
      final token = await _readToken();
      if (token == null) return;

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/account-deletion/verify-otp'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'otp': otp}),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeResponse(response);

      if (response.statusCode == 200 && data['success'] == true) {
        if (!mounted) return;

        _cooldownTimer?.cancel();
        _expiryTimer?.cancel();

        setState(() {
          _otpVerified = true;
          _attemptsRemaining = _readInt(
            data['attemptsRemaining'],
            _attemptsRemaining,
          );
          _deletionVerificationToken =
              data['verificationToken']?.toString() ??
              data['deletionToken']?.toString();
        });

        FocusScope.of(context).unfocus();
        _showSuccess('Identity verified successfully.');
      } else {
        if (!mounted) return;

        setState(() {
          _attemptsRemaining = _readInt(
            data['attemptsRemaining'],
            (_attemptsRemaining - 1).clamp(0, 5),
          );
        });

        _clearOTP();
        _showError(data['message']?.toString() ?? 'Invalid verification code.');

        if (_attemptsRemaining > 0) {
          _otpFocusNodes.first.requestFocus();
        }
      }
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } catch (e) {
      debugPrint('DELETE_ACCOUNT_VERIFY_OTP_ERROR: $e');
      _showError('Connection error. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifyingOTP = false;
        });
      }
    }
  }

  Future<void> _confirmAndSubmitRequest() async {
    if (!_otpVerified || _isSubmittingRequest) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.errorColor,
                size: 25,
              ),
              SizedBox(width: 10),
              Expanded(
                child: SmartReTranslator(
                  text: 'Confirm Account Deletion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: const SmartReTranslator(
            text:
                'Your account will enter a 30-day deletion period. '
                'Normal account access will be unavailable during this period. '
                'You can cancel the deletion request before the scheduled deletion date.',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const SmartReTranslator(
                text: 'Keep Account',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.errorColor,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const SmartReTranslator(
                text: 'Submit Request',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await _submitDeletionRequest();
    }
  }

  Future<void> _submitDeletionRequest() async {
    if (!_otpVerified || _isSubmittingRequest) return;

    setState(() {
      _isSubmittingRequest = true;
    });

    try {
      final token = await _readToken();
      if (token == null) return;

      final body = <String, dynamic>{};

      if (_deletionVerificationToken != null &&
          _deletionVerificationToken!.isNotEmpty) {
        body['verificationToken'] = _deletionVerificationToken;
      }

      final response = await http
          .post(
            Uri.parse('${AppConstants.baseUrl}/account-deletion/request'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));

      final data = _decodeResponse(response);

      if ((response.statusCode == 200 || response.statusCode == 201) &&
          data['success'] == true) {
        if (!mounted) return;

        _cooldownTimer?.cancel();
        _expiryTimer?.cancel();
        FocusScope.of(context).unfocus();

        setState(() {
          _requestSubmitted = true;
          _scheduledDeletionAt =
              data['scheduledDeletionAt']?.toString() ??
              data['scheduled_deletion_at']?.toString();
          _deletionVerificationToken = null;
        });

        _clearOTP();

        _showSuccess(
          data['message']?.toString() ??
              'Your account deletion request has been submitted.',
        );
      } else {
        _showError(
          data['message']?.toString() ??
              'Unable to submit your account deletion request right now. Please try again later.',
        );
      }
    } on TimeoutException {
      _showError('The request timed out. Please try again.');
    } catch (e) {
      debugPrint('DELETE_ACCOUNT_REQUEST_ERROR: $e');
      _showError(
        'Unable to submit your account deletion request right now. Please try again later.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmittingRequest = false;
        });
      }
    }
  }

  Future<void> _openEmailVerification() async {
    final verified = await Navigator.of(
      context,
    ).push(EmailVerifyScreen.route());

    if (verified == true && mounted) {
      setState(() {
        _emailVerified = true;
      });

      await _loadAccount();
    }
  }

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
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    if (_cooldownSeconds <= 0) return;

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
    if (_expiresIn <= 0) return;

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
          _otpVerified = false;
          _deletionVerificationToken = null;
        });
        _clearOTP();
      }
    });
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  String get _displayEmail {
    if (_emailHint != null && _emailHint!.trim().isNotEmpty) {
      return _emailHint!.trim();
    }

    if (_fullEmail == null || _fullEmail!.trim().isEmpty) {
      return 'your verified email';
    }

    return _maskEmail(_fullEmail!.trim());
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2 || parts[0].isEmpty) return email;

    final name = parts[0];
    final domain = parts[1];

    if (name.length <= 2) {
      return '${name[0]}***@$domain';
    }

    return '${name.substring(0, 2)}***@$domain';
  }

  String _formatTime(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final minutes = safeSeconds ~/ 60;
    final remaining = safeSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${remaining.toString().padLeft(2, '0')}';
  }

  String _formatDeletionDate() {
    if (_scheduledDeletionAt == null || _scheduledDeletionAt!.isEmpty) {
      return '30 days from the request date';
    }

    final parsed = DateTime.tryParse(_scheduledDeletionAt!);
    if (parsed == null) return _scheduledDeletionAt!;

    final local = parsed.toLocal();

    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${local.day} ${months[local.month - 1]} ${local.year}';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Delete Account',
        backgroundColor: Colors.transparent,
        elevation: 0,
        showOnlineStatus: true,
        onBackPressed: () => Navigator.of(context).pop(_requestSubmitted),
      ),
      body: _isInitializing
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),
              child: Column(
                children: [
                  _buildHeader(),
                  const SizedBox(height: 18),
                  _buildAccountCard(),
                  const SizedBox(height: 12),
                  _buildProcessCard(),
                  const SizedBox(height: 12),
                  if (_requestSubmitted)
                    _buildSubmittedSection()
                  else if (!_emailVerified)
                    _buildEmailRequiredSection()
                  else if (_otpVerified)
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

  Widget _buildHeader() {
    final Color iconColor;
    final IconData icon;
    final String title;
    final String subtitle;

    if (_requestSubmitted) {
      iconColor = AppColors.successColor;
      icon = Icons.schedule_rounded;
      title = 'Deletion Request Submitted';
      subtitle = 'Your account is now in the 30-day account deletion period.';
    } else if (_otpVerified) {
      iconColor = AppColors.successColor;
      icon = Icons.verified_user_rounded;
      title = 'Identity Verified';
      subtitle =
          'Review the deletion information before submitting your request.';
    } else if (_otpSent) {
      iconColor = AppColors.primaryGreen;
      icon = Icons.mark_email_read_rounded;
      title = 'Verify Your Identity';
      subtitle =
          'Enter the 6-digit code sent to your registered email address.';
    } else {
      iconColor = AppColors.errorColor;
      icon = Icons.delete_forever_outlined;
      title = 'Delete Your Account';
      subtitle =
          'Verify your identity before requesting permanent account deletion.';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Column(
        children: [
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: iconColor.withOpacity(0.20),
                width: 1.5,
              ),
            ),
            child: Icon(icon, size: 42, color: iconColor),
          ),
          const SizedBox(height: 14),
          SmartReTranslator(
            text: title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SmartReTranslator(
            text: subtitle,
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

  Widget _buildAccountCard() {
    return _SectionCard(
      padding: const EdgeInsets.all(14),
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
                  text: 'Registered Email',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _fullEmail?.isNotEmpty == true
                      ? _fullEmail!
                      : 'Email not available',
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _emailVerified
                  ? AppColors.successColor.withOpacity(0.10)
                  : AppColors.errorColor.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _emailVerified
                  ? Icons.verified_rounded
                  : Icons.error_outline_rounded,
              color: _emailVerified
                  ? AppColors.successColor
                  : AppColors.errorColor,
              size: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcessCard() {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppColors.primaryGreen,
                size: 21,
              ),
              SizedBox(width: 9),
              Expanded(
                child: SmartReTranslator(
                  text: 'How account deletion works',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildProcessStep(
            number: '1',
            title: 'Verify your identity',
            description:
                'A one-time verification code is sent to your verified email.',
          ),
          _processDivider(),
          _buildProcessStep(
            number: '2',
            title: 'Submit deletion request',
            description:
                'After verification, confirm that you want to delete your account.',
          ),
          _processDivider(),
          _buildProcessStep(
            number: '3',
            title: '30-day cancellation period',
            description:
                'You can cancel the deletion request before the scheduled deletion date.',
          ),
          _processDivider(),
          _buildProcessStep(
            number: '4',
            title: 'Permanent deletion',
            description:
                'If the request is not cancelled, your account and applicable data are permanently deleted.',
            danger: true,
          ),
        ],
      ),
    );
  }

  Widget _buildProcessStep({
    required String number,
    required String title,
    required String description,
    bool danger = false,
  }) {
    final color = danger ? AppColors.errorColor : AppColors.primaryGreen;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartReTranslator(
                text: title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: danger ? AppColors.errorColor : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 3),
              SmartReTranslator(
                text: description,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _processDivider() {
    return Container(
      margin: const EdgeInsets.only(left: 14),
      width: 1,
      height: 14,
      color: Colors.black.withOpacity(0.08),
    );
  }

  Widget _buildEmailRequiredSection() {
    return _SectionCard(
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.mark_email_unread_outlined,
            iconColor: Colors.orange.shade700,
            title: 'Verified email required',
            description:
                'Your registered email must be verified before an account deletion request can be created.',
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.verified_outlined,
            text: 'Verify Email',
            backgroundColor: AppColors.primaryGreen,
            loading: false,
            onPressed: _openEmailVerification,
          ),
        ],
      ),
    );
  }

  Widget _buildSendSection() {
    return _SectionCard(
      child: Column(
        children: [
          _buildWarningBox(
            icon: Icons.security_rounded,
            title: 'Security verification',
            message:
                'For your protection, we will send a new verification code to $_displayEmail. This code is only for confirming this account deletion request.',
            color: AppColors.primaryGreen,
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.mark_email_read_outlined,
            text: 'Send Verification Code',
            backgroundColor: AppColors.primaryGreen,
            loading: _isSendingOTP,
            onPressed: _isSendingOTP ? null : _sendOTP,
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

  Widget _buildOTPSection() {
    final otpExpired = _expiresIn <= 0;

    return _SectionCard(
      child: Column(
        children: [
          _buildInfoRow(
            icon: Icons.lock_outline_rounded,
            iconColor: AppColors.primaryGreen,
            title: 'Enter verification code',
            description: 'Enter the 6-digit code sent to $_displayEmail.',
          ),
          const SizedBox(height: 20),
          _buildOTPFields(),
          const SizedBox(height: 16),
          _buildOTPStatus(),
          if (otpExpired) ...[
            const SizedBox(height: 12),
            _buildWarningBox(
              icon: Icons.timer_off_outlined,
              title: 'Verification code expired',
              message: 'Request a new verification code to continue.',
              color: AppColors.errorColor,
            ),
          ],
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.verified_user_outlined,
            text: 'Verify Identity',
            backgroundColor: AppColors.primaryGreen,
            loading: _isVerifyingOTP,
            onPressed: _isVerifyingOTP || otpExpired || _attemptsRemaining <= 0
                ? null
                : _verifyOTP,
          ),
          const SizedBox(height: 6),
          _buildResendButton(),
        ],
      ),
    );
  }

  Widget _buildOTPFields() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final spacing = constraints.maxWidth < 340 ? 3.0 : 5.0;
        final availableWidth = constraints.maxWidth - (spacing * 12);
        final fieldWidth = (availableWidth / 6).clamp(38.0, 50.0);

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
                  enabled: !_isVerifyingOTP,
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
                  onChanged: (value) => _onOTPChanged(index, value),
                  onFieldSubmitted: (_) {
                    if (index == 5) _verifyOTP();
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

  Widget _buildResendButton() {
    final canResend = _cooldownSeconds <= 0 && !_isSendingOTP && !_otpVerified;

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

  Widget _buildVerifiedSection() {
    return _SectionCard(
      child: Column(
        children: [
          _buildWarningBox(
            icon: Icons.verified_user_rounded,
            title: 'Identity verified',
            message:
                'Your identity has been confirmed using your registered email address.',
            color: AppColors.successColor,
          ),
          const SizedBox(height: 12),
          _buildWarningBox(
            icon: Icons.schedule_rounded,
            title: '30-day cancellation period',
            message:
                'After submitting this request, normal account access will be unavailable. You may cancel the deletion request within 30 days. If it is not cancelled, your account and applicable data will be permanently deleted.',
            color: Colors.orange.shade800,
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.delete_forever_rounded,
            text: 'Submit Account Deletion Request',
            backgroundColor: AppColors.errorColor,
            loading: _isSubmittingRequest,
            onPressed: _isSubmittingRequest ? null : _confirmAndSubmitRequest,
          ),
          const SizedBox(height: 10),
          const SmartReTranslator(
            text:
                'Submitting the request does not immediately delete your account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.4,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedSection() {
    return _SectionCard(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.successColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.successColor,
              size: 34,
            ),
          ),
          const SizedBox(height: 14),
          const SmartReTranslator(
            text: 'Request Submitted Successfully',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const SmartReTranslator(
            text:
                'Your account deletion request has been received. You can cancel the request before the scheduled deletion date.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAF7),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.event_rounded,
                  color: AppColors.primaryGreen,
                  size: 21,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SmartReTranslator(
                        text: 'Scheduled deletion',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDeletionDate(),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _PrimaryActionButton(
            icon: Icons.check_rounded,
            text: 'Done',
            backgroundColor: AppColors.primaryGreen,
            loading: false,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
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
                  height: 1.45,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWarningBox({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartReTranslator(
                  text: title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                SmartReTranslator(
                  text: message,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _SectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
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

class _PrimaryActionButton extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color backgroundColor;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryActionButton({
    required this.icon,
    required this.text,
    required this.backgroundColor,
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
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: backgroundColor.withOpacity(0.50),
          disabledForegroundColor: Colors.white70,
          elevation: 2,
          shadowColor: backgroundColor.withOpacity(0.20),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

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
