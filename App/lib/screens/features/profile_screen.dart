// lib/screens/profile/profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../shared/smart_retranslator.dart';
import '../auth/email_verify_screen.dart';
import '../../utils/colors.dart';
import '../../src/services/api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  bool _isLoading = true;
  bool _emailVerified = false;
  bool _isEditing = false;
  bool _isSaving = false;

  // User data (display)
  String _name = '';
  String _email = '';
  String _phone = '';
  String _category = '';
  String _address = '';
  String _pincode = '';
  String _dob = '';

  // Controllers for edit mode
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _dobCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _pincodeCtrl = TextEditingController();
    _dobCtrl = TextEditingController();

    // Fast: only read from secure storage; SyncService keeps it fresh.
    _loadUserProfile();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _pincodeCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      final profileJson = await _storage.read(key: 'user_profile');
      debugPrint('📦 user_profile from storage: $profileJson');

      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

        setState(() {
          _name = profileData['name'] ?? '';
          _email = profileData['email'] ?? '';
          _phone = profileData['phone_number'] ?? '';
          _category = profileData['user_category'] ?? '';
          _address = profileData['address'] ?? '';

          final pincodeValue = profileData['pincode'];
          _pincode = pincodeValue?.toString() ?? '';

          final dobValue = profileData['dob'];
          if (dobValue != null && dobValue.toString().isNotEmpty) {
            try {
              final dobDate = DateTime.parse(dobValue.toString());
              _dob = DateFormat('dd MMM yyyy').format(dobDate);
            } catch (_) {
              _dob = dobValue.toString();
            }
          } else {
            _dob = '';
          }

          _emailVerified = profileData['email_verified'] ?? false;

          // sync controllers
          _nameCtrl.text = _name;
          _emailCtrl.text = _email;
          _addressCtrl.text = _address;
          _pincodeCtrl.text = _pincode;
          _dobCtrl.text = _dob;
        });
      } else {
        _showError('Profile data not found');
      }
    } catch (e) {
      debugPrint('Error loading profile from storage: $e');
      _showError('Failed to load profile');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SmartReTranslator(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SmartReTranslator(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: AppColors.successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveProfile() async {
    // Build minimal payload with changed fields only
    final Map<String, dynamic> body = {};

    if (_nameCtrl.text.trim() != _name.trim()) {
      body['name'] = _nameCtrl.text.trim();
    }

    // Email editable only when not verified
    if (!_emailVerified &&
        _emailCtrl.text.trim().isNotEmpty &&
        _emailCtrl.text.trim() != _email.trim()) {
      body['email'] = _emailCtrl.text.trim();
    }

    if (_addressCtrl.text.trim() != _address.trim()) {
      body['address'] = _addressCtrl.text.trim();
    }

    if (_pincodeCtrl.text.trim() != _pincode.trim()) {
      body['pincode'] = _pincodeCtrl.text.trim();
    }

    if (_dobCtrl.text.trim() != _dob.trim()) {
      String? dobIso;
      if (_dobCtrl.text.isNotEmpty) {
        try {
          final parsed = DateFormat('dd MMM yyyy').parse(_dobCtrl.text.trim());
          dobIso = parsed.toIso8601String();
        } catch (_) {
          dobIso = _dobCtrl.text.trim();
        }
      }
      body['dob'] = dobIso;
    }

    // nothing changed
    if (body.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      // get user id from storage
      final userId = await _storage.read(key: 'user_id');
      final response = await ApiService.instance.put(
        '/profile/updateUser/$userId',
        body: body,
        requiresAuth: true,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess || response.statusCode == 200) {
        // Backend only returns { message: ... }, so use body + existing profile
        final currentJson = await _storage.read(key: 'user_profile');
        Map<String, dynamic> current =
            currentJson != null && currentJson.isNotEmpty
            ? jsonDecode(currentJson) as Map<String, dynamic>
            : <String, dynamic>{};

        // Apply local changes to stored profile
        if (body.containsKey('name')) current['name'] = body['name'];
        if (body.containsKey('email')) current['email'] = body['email'];
        if (body.containsKey('address')) current['address'] = body['address'];
        if (body.containsKey('pincode')) current['pincode'] = body['pincode'];
        if (body.containsKey('dob')) current['dob'] = body['dob'];

        await _storage.write(key: 'user_profile', value: jsonEncode(current));

        await _loadUserProfile();

        setState(() {
          _isEditing = false;
        });

        _showSuccess('Profile updated successfully');
      } else if (response.isOffline) {
        _showError('No internet connection');
      } else if (response.isTimeout) {
        _showError('Request timeout. Please try again');
      } else {
        final data = response.data;
        final msg = (data is Map && data['message'] != null)
            ? data['message'].toString()
            : (response.error ?? 'Failed to update profile');
        _showError(msg);
      }
    } catch (e) {
      _showError('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            if (_isEditing) {
              setState(() {
                _isEditing = false;
                _nameCtrl.text = _name;
                _emailCtrl.text = _email;
                _addressCtrl.text = _address;
                _pincodeCtrl.text = _pincode;
                _dobCtrl.text = _dob;
              });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const SmartReTranslator(
          text: 'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      _isEditing ? Icons.check : Icons.edit,
                      color: Colors.white,
                    ),
              onPressed: _isSaving
                  ? null
                  : () async {
                      if (_isEditing) {
                        await _saveProfile();
                      } else {
                        setState(() => _isEditing = true);
                      }
                    },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    const SizedBox(height: 16),
                    if (!_emailVerified) _buildVerificationBanner(),
                    const SizedBox(height: 8),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: SmartReTranslator(
                          text: 'Personal Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildProfileDetails(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.primaryGreen,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.only(top: 20, bottom: 40),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                    style: const TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ),
              if (_emailVerified)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.successColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                    ),
                    child: const Icon(
                      Icons.verified,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _name.isNotEmpty ? _name : 'Guest User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (_category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondaryGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _category,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 28),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange.shade700,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartReTranslator(
                  text: 'Email Not Verified',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade900,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                SmartReTranslator(
                  text: 'Verify your email to secure your account',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade800),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () async {
              final verified = await Navigator.of(
                context,
              ).push(EmailVerifyScreen.route());

              if (verified == true && mounted) {
                try {
                  final profileJson = await _storage.read(key: 'user_profile');
                  if (profileJson != null) {
                    final profileData = jsonDecode(profileJson);
                    profileData['email_verified'] = true;
                    await _storage.write(
                      key: 'user_profile',
                      value: jsonEncode(profileData),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating verification status: $e');
                }

                setState(() => _emailVerified = true);
                _showSuccess('Email verified successfully!');
              }
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const SmartReTranslator(
              text: 'Verify',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetails() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _buildDetailCard(
            icon: Icons.email_outlined,
            title: 'Email',
            value: _email,
            controller: _emailCtrl,
            verified: _emailVerified,
            isEditing: _isEditing,
            enabledWhenEditing: !_emailVerified,
          ),
          const SizedBox(height: 10),
          _buildDetailCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: _phone,
            isEditing: false,
          ),
          const SizedBox(height: 10),
          _buildDetailCard(
            icon: Icons.cake_outlined,
            title: 'Date of Birth',
            value: _dob,
            controller: _dobCtrl,
            isEditing: _isEditing,
            isDate: true,
          ),
          const SizedBox(height: 10),
          _buildDetailCard(
            icon: Icons.location_on_outlined,
            title: 'Address',
            value: _address,
            controller: _addressCtrl,
            isEditing: _isEditing,
          ),
          const SizedBox(height: 10),
          _buildDetailCard(
            icon: Icons.pin_drop_outlined,
            title: 'Postal Code',
            value: _pincode,
            controller: _pincodeCtrl,
            isEditing: _isEditing,
            keyboardType: TextInputType.number,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String value,
    bool verified = false,
    bool isEditing = false,
    TextEditingController? controller,
    bool enabledWhenEditing = true,
    bool isDate = false,
    TextInputType? keyboardType,
  }) {
    final showField = isEditing && controller != null;

    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
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
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (!showField)
                    Text(
                      value.isNotEmpty ? value : 'Not provided',
                      style: TextStyle(
                        fontSize: 14,
                        color: value.isNotEmpty
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  else
                    GestureDetector(
                      onTap: isDate
                          ? () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: now,
                                firstDate: DateTime(1900),
                                lastDate: now,
                              );
                              if (picked != null) {
                                controller!.text = DateFormat(
                                  'dd MMM yyyy',
                                ).format(picked);
                              }
                            }
                          : null,
                      child: AbsorbPointer(
                        absorbing: isDate,
                        child: TextField(
                          controller: controller,
                          enabled: enabledWhenEditing,
                          keyboardType: keyboardType,
                          decoration: InputDecoration(
                            isDense: true,
                            border: const OutlineInputBorder(),
                            hintText: 'Enter $title',
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (verified)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withOpacity(0.1),
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
      ),
    );
  }
}
