// lib/screens/profile/profile_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sqflite/sqflite.dart';
import '../shared/smart_retranslator.dart';
import '../auth/email_verify_screen.dart';
import '../../utils/colors.dart';
import '../../src/services/api_service.dart';
import '../../src/database/database_helper.dart';

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
  bool _isUploadingImage = false;

  // User data (display)
  String _name = '';
  String _email = '';
  String _phone = '';
  String _category = '';
  String _address = '';
  String _pincode = '';
  String _dob = '';
  String? _profileImagePath;

  // Controllers for edit mode
  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _pincodeCtrl;
  late TextEditingController _dobCtrl;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _addressCtrl = TextEditingController();
    _pincodeCtrl = TextEditingController();
    _dobCtrl = TextEditingController();

    _loadUserProfile();

    // ✅ Check for pending uploads after profile loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncPendingProfilePicture();
    });
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

  /// ✅ Load user profile from secure storage
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

        // ✅ Load profile picture
        await _loadProfilePicture();
      } else {
        _showError('Profile data not found');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile from storage: $e');
      _showError('Failed to load profile');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// ✅ Load profile picture from database
  Future<void> _loadProfilePicture() async {
    try {
      final imageId = await _storage.read(key: 'profile_image_id');
      if (imageId == null || imageId.isEmpty) {
        debugPrint('ℹ️ No profile image_id found');
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'images',
        where: 'image_id = ?',
        whereArgs: [imageId],
        limit: 1,
      );

      if (results.isNotEmpty) {
        final localPath = results.first['local_path'] as String?;
        final isUploaded = results.first['is_uploaded'] as int? ?? 0;

        if (localPath != null && localPath.isNotEmpty) {
          final file = File(localPath);
          if (await file.exists()) {
            setState(() {
              _profileImagePath = localPath;
            });

            if (isUploaded == 0) {
              debugPrint('⚠️ Profile picture pending upload to server');
            } else {
              debugPrint('✅ Profile picture loaded: $localPath');
            }
          } else {
            debugPrint('⚠️ Profile picture file not found: $localPath');
          }
        }
      } else {
        debugPrint('ℹ️ No profile picture in database');
      }
    } catch (e) {
      debugPrint('❌ Error loading profile picture: $e');
    }
  }

  /// ✅ Show image picker bottom sheet (WhatsApp style)
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SmartReTranslator(
                text: 'Profile Photo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryGreen,
                ),
                title: const SmartReTranslator(text: 'Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: AppColors.primaryGreen,
                ),
                title: const SmartReTranslator(text: 'Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              if (_profileImagePath != null)
                ListTile(
                  leading: const Icon(
                    Icons.delete,
                    color: AppColors.errorColor,
                  ),
                  title: const SmartReTranslator(
                    text: 'Remove Photo',
                    style: TextStyle(color: AppColors.errorColor),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePicture();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Pick image from camera or gallery
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final file = File(pickedFile.path);
      await _updateProfilePicture(file);
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      _showError('Failed to pick image');
    }
  }

  /// ✅ Update profile picture - reuse existing image_id
  Future<void> _updateProfilePicture(File image) async {
    try {
      setState(() => _isUploadingImage = true);

      // 1️⃣ Get existing profile data and image_id
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) {
        throw 'Profile data not found';
      }

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;
      String imageId = profileData['image_id']?.toString() ?? '';

      // If no existing image_id, create one (first-time upload)
      if (imageId.isEmpty) {
        imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
        debugPrint('🆕 Creating new image_id: $imageId');
      } else {
        debugPrint('🔄 Reusing existing image_id: $imageId');
      }

      // 2️⃣ Get app directory
      final directory = await getApplicationDocumentsDirectory();
      final profileDir = Directory('${directory.path}/profile_pictures');
      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final extension = image.path.split('.').last;
      final localPath = '${profileDir.path}/profile_$imageId.$extension';

      // 3️⃣ Delete old image file if exists
      final db = await DatabaseHelper.instance.database;
      final existingResults = await db.query(
        'images',
        where: 'image_id = ?',
        whereArgs: [imageId],
        limit: 1,
      );

      if (existingResults.isNotEmpty) {
        final oldLocalPath = existingResults.first['local_path'] as String?;
        if (oldLocalPath != null && oldLocalPath.isNotEmpty) {
          final oldFile = File(oldLocalPath);
          if (await oldFile.exists()) {
            await oldFile.delete();
            debugPrint('🗑️ Deleted old image: $oldLocalPath');
          }
        }
      }

      // 4️⃣ Save new image locally
      await image.copy(localPath);
      debugPrint('💾 New image saved: $localPath');

      // 5️⃣ Update database with pending sync flag
      await db.insert('images', {
        'image_id': imageId,
        'local_path': localPath,
        'server_image_url': '', // Will be updated after upload
        'is_uploaded': 0, // Mark as NOT uploaded (pending sync)
        'created_at': DateTime.now().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // 6️⃣ Update secure storage
      await _storage.write(key: 'profile_image_id', value: imageId);

      // Update profile data with image_id
      profileData['image_id'] = imageId;
      await _storage.write(key: 'user_profile', value: jsonEncode(profileData));

      // 7️⃣ Set flag to indicate pending profile picture upload
      await _storage.write(
        key: 'profile_picture_pending_upload',
        value: 'true',
      );

      // 8️⃣ Update UI immediately
      setState(() {
        _profileImagePath = localPath;
      });

      _showSuccess('Profile picture updated locally');
      debugPrint('✅ Profile picture queued for upload');

      // 9️⃣ Try to upload to server (background)
      _uploadPendingProfilePicture();
    } catch (e) {
      debugPrint('❌ Error updating profile picture: $e');
      _showError('Failed to update profile picture');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  /// ✅ Upload pending profile picture to server
  Future<void> _uploadPendingProfilePicture() async {
    try {
      // Check if there's a pending upload
      final isPending = await _storage.read(
        key: 'profile_picture_pending_upload',
      );
      if (isPending != 'true') {
        debugPrint('ℹ️ No pending profile picture upload');
        return;
      }

      // Get image_id and local path
      final imageId = await _storage.read(key: 'profile_image_id');
      if (imageId == null) {
        debugPrint('⚠️ No image_id found');
        return;
      }

      final db = await DatabaseHelper.instance.database;
      final results = await db.query(
        'images',
        where: 'image_id = ? AND is_uploaded = 0',
        whereArgs: [imageId],
        limit: 1,
      );

      if (results.isEmpty) {
        debugPrint('ℹ️ Image already uploaded or not found');
        await _storage.delete(key: 'profile_picture_pending_upload');
        return;
      }

      final localPath = results.first['local_path'] as String;
      final imageFile = File(localPath);

      if (!await imageFile.exists()) {
        debugPrint('❌ Image file not found: $localPath');
        await _storage.delete(key: 'profile_picture_pending_upload');
        return;
      }

      debugPrint('📤 Uploading profile picture to server...');

      // Upload to server with existing image_id
      // ✅ CORRECT ORDER
      final response = await ApiService.instance.uploadProfilePicture(
        imageFile,
        imageId,
      );

      if (response.isSuccess) {
        final data = response.data;
        final serverImageUrl = data['image_url']?.toString() ?? '';

        // Update database: mark as uploaded
        await db.update(
          'images',
          {'server_image_url': serverImageUrl, 'is_uploaded': 1},
          where: 'image_id = ?',
          whereArgs: [imageId],
        );

        // Clear pending flag
        await _storage.delete(key: 'profile_picture_pending_upload');

        debugPrint('✅ Profile picture uploaded (image_id: $imageId)');

        if (mounted) {
          _showSuccess('Profile picture synced with server');
        }
      } else if (response.isOffline || response.isTimeout) {
        debugPrint('⚠️ Upload failed: offline/timeout. Will retry later.');
      } else {
        debugPrint('❌ Upload failed: ${response.error}');
      }
    } catch (e) {
      debugPrint('❌ Error uploading profile picture: $e');
    }
  }

  /// ✅ Check and upload pending profile picture
  Future<void> _syncPendingProfilePicture() async {
    final isPending = await _storage.read(
      key: 'profile_picture_pending_upload',
    );
    if (isPending == 'true') {
      debugPrint('🔄 Found pending profile picture upload, syncing...');
      await _uploadPendingProfilePicture();
    }
  }

  /// ✅ Remove profile picture
  Future<void> _removeProfilePicture() async {
    try {
      setState(() => _isUploadingImage = true);

      final userId = await _storage.read(key: 'user_id');
      final response = await ApiService.instance.delete(
        '/profile/remove-profile-picture/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        // Remove from database
        final imageId = await _storage.read(key: 'profile_image_id');
        if (imageId != null) {
          final db = await DatabaseHelper.instance.database;
          await db.delete('images', where: 'image_id = ?', whereArgs: [imageId]);
        }

        // Delete local file
        if (_profileImagePath != null) {
          final file = File(_profileImagePath!);
          if (await file.exists()) {
            await file.delete();
          }
        }

        // Remove from secure storage
        await _storage.delete(key: 'profile_image_id');
        await _storage.delete(key: 'profile_picture_pending_upload');

        setState(() {
          _profileImagePath = null;
        });

        _showSuccess('Profile picture removed');
      } else {
        _showError('Failed to remove profile picture');
      }
    } catch (e) {
      debugPrint('❌ Error removing profile picture: $e');
      _showError('Failed to remove profile picture');
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
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
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
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
      ),
    );
  }

  Future<void> _saveProfile() async {
    final Map<String, dynamic> body = {};

    if (_nameCtrl.text.trim() != _name.trim()) {
      body['name'] = _nameCtrl.text.trim();
    }

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

    if (body.isEmpty) {
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final userId = await _storage.read(key: 'user_id');
      final response = await ApiService.instance.put(
        '/profile/updateUser/$userId',
        body: body,
        requiresAuth: true,
        timeout: const Duration(seconds: 30),
      );

      if (response.isSuccess || response.statusCode == 200) {
        final currentJson = await _storage.read(key: 'user_profile');
        Map<String, dynamic> current =
            currentJson != null && currentJson.isNotEmpty
            ? jsonDecode(currentJson) as Map<String, dynamic>
            : <String, dynamic>{};

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

  /// ✅ Profile header with WhatsApp-style image editor
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
              // Profile Picture
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: _profileImagePath != null
                      ? DecorationImage(
                          image: FileImage(File(_profileImagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _profileImagePath == null
                    ? Center(
                        child: Text(
                          _name.isNotEmpty ? _name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryGreen,
                          ),
                        ),
                      )
                    : null,
              ),

              // Upload indicator overlay
              if (_isUploadingImage)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                ),

              // Camera button (WhatsApp style)
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _showImagePickerOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // Verified badge
              if (_emailVerified)
                Positioned(
                  top: 0,
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
                                controller.text = DateFormat(
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
