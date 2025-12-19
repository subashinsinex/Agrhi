// lib/screens/profile/profile_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../shared/smart_retranslator.dart';
import '../auth/email_verify_screen.dart';
import '../../utils/colors.dart';

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

  // User data
  String _name = '';
  String _email = '';
  String _phone = '';
  String _category = '';
  String _address = '';
  String _pincode = '';
  String _dob = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      // Read user profile from secure storage
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

        setState(() {
          _name = profileData['name'] ?? '';
          _email = profileData['email'] ?? '';
          _phone = profileData['phone_number'] ?? '';
          _category = profileData['user_category'] ?? '';
          _address = profileData['address'] ?? '';

          // Handle pincode (can be int or string)
          final pincodeValue = profileData['pincode'];
          _pincode = pincodeValue?.toString() ?? '';

          // Format DOB from ISO string to readable date
          final dobValue = profileData['dob'];
          if (dobValue != null && dobValue.isNotEmpty) {
            try {
              final dobDate = DateTime.parse(dobValue);
              _dob = DateFormat('dd MMM yyyy').format(dobDate);
            } catch (e) {
              _dob = dobValue.toString();
            }
          } else {
            _dob = '';
          }

          // Get email verification status from storage
          _emailVerified = profileData['email_verified'] ?? false;
        });
      } else {
        _showError('Profile data not found');
      }
    } catch (e) {
      debugPrint('Error loading profile from storage: $e');
      _showError('Failed to load profile');
    } finally {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const SmartReTranslator(
          text: 'Profile',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserProfile,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Profile Header
                    _buildProfileHeader(),

                    const SizedBox(height: 16),

                    // Email Verification Banner
                    if (!_emailVerified) _buildVerificationBanner(),

                    const SizedBox(height: 8),

                    // Profile Details Section Title
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

                    // Profile Details
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
          // Avatar with verification badge
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
              // Email verification badge
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

          // Name
          Text(
            _name.isNotEmpty ? _name : 'Guest User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),

          // Category Badge
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
                // Update storage with verified status
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
          // Email
          _buildDetailCard(
            icon: Icons.email_outlined,
            title: 'Email',
            value: _email,
            verified: _emailVerified,
          ),
          const SizedBox(height: 10),

          // Phone
          _buildDetailCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: _phone,
          ),
          const SizedBox(height: 10),

          // Date of Birth
          _buildDetailCard(
            icon: Icons.cake_outlined,
            title: 'Date of Birth',
            value: _dob,
          ),
          const SizedBox(height: 10),

          // Address
          _buildDetailCard(
            icon: Icons.location_on_outlined,
            title: 'Address',
            value: _address,
          ),
          const SizedBox(height: 10),

          // Pincode
          _buildDetailCard(
            icon: Icons.pin_drop_outlined,
            title: 'Postal Code',
            value: _pincode,
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
  }) {
    return Card(
      elevation: 2,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Icon container
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primaryGreen, size: 20),
            ),
            const SizedBox(width: 14),

            // Title and value
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
                  Text(
                    value.isNotEmpty ? value : 'Not provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: value.isNotEmpty
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Verification badge
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
