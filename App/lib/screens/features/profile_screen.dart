import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crop_image/crop_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../src/services/api_service.dart';
import '../../src/services/sync_service.dart';
import '../../utils/colors.dart';
import '../auth/email_verify_screen.dart';
import '../shared/custom_app_bar.dart';
import '../shared/smart_retranslator.dart';

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
  bool _isSyncing = false;
  bool _emailVerified = false;
  bool _isEditing = false;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  int _pendingProfileUpdatesCount = 0;

  String _name = '';
  String _email = '';
  String _phone = '';
  String _category = '';
  String _address = '';
  String _pincode = '';
  String _dob = '';
  String? _profileImagePath;

  Key _profileImageKey = UniqueKey();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _pincodeCtrl;
  late final TextEditingController _dobCtrl;

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPendingUpdates();
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

  Future<void> _checkPendingUpdates() async {
    final count = await SyncService.instance.getPendingProfileUpdatesCount();

    if (!mounted) return;

    setState(() {
      _pendingProfileUpdatesCount = count;
    });

    if (count > 0) {
      _triggerProfileSync();
    }
  }

  Future<void> _triggerProfileSync() async {
    if (_isSyncing) {
      debugPrint('⏭️ Profile sync already in progress');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSyncing = true;
    });

    try {
      final accessToken = await _storage.read(key: 'access_token');

      if (accessToken != null) {
        final result = await SyncService.instance.syncAllProfileUpdates(
          accessToken,
        );

        await _checkPendingUpdates();

        if (result['success'] == true && result['processed'] > 0) {
          await _reloadUserProfileQuietly();

          if (mounted) {
            _showSuccess('Profile synced with server');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Profile sync error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  Future<void> _loadUserProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _reloadUserProfileQuietly();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _reloadUserProfileQuietly() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson == null || profileJson.isEmpty) {
        _showError('Profile data not found');
        return;
      }

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

      String formattedDob = '';

      final dobValue = profileData['dob'];

      if (dobValue != null && dobValue.toString().isNotEmpty) {
        try {
          final dobDate = DateTime.parse(dobValue.toString());

          formattedDob = DateFormat('dd MMM yyyy').format(dobDate);
        } catch (_) {
          formattedDob = dobValue.toString();
        }
      }

      if (!mounted) return;

      setState(() {
        _name = profileData['name'] ?? '';
        _email = profileData['email'] ?? '';
        _phone = profileData['phone_number'] ?? '';
        _category = profileData['user_category'] ?? '';
        _address = profileData['address'] ?? '';
        _pincode = profileData['pincode']?.toString() ?? '';
        _dob = formattedDob;
        _emailVerified = profileData['email_verified'] ?? false;

        _nameCtrl.text = _name;
        _emailCtrl.text = _email;
        _addressCtrl.text = _address;
        _pincodeCtrl.text = _pincode;
        _dobCtrl.text = _dob;
      });

      await _loadProfilePicture();
    } catch (e) {
      debugPrint('❌ Error loading profile from storage: $e');

      _showError('Failed to load profile');
    }
  }

  Future<void> _loadProfilePicture() async {
    try {
      final localPath = await _storage.read(key: 'profile_image_local_path');

      if (localPath == null || localPath.isEmpty) {
        if (mounted) {
          setState(() {
            _profileImagePath = null;
            _profileImageKey = UniqueKey();
          });
        }

        return;
      }

      final file = File(localPath);

      if (await file.exists()) {
        if (_profileImagePath != null) {
          try {
            await FileImage(File(_profileImagePath!)).evict();
          } catch (e) {
            debugPrint('⚠️ Failed to evict old image cache: $e');
          }
        }

        try {
          await FileImage(file).evict();
        } catch (e) {
          debugPrint('⚠️ Failed to evict new image cache: $e');
        }

        if (mounted) {
          setState(() {
            _profileImagePath = localPath;
            _profileImageKey = UniqueKey();
          });
        }
      } else {
        await _storage.delete(key: 'profile_image_local_path');

        if (mounted) {
          setState(() {
            _profileImagePath = null;
            _profileImageKey = UniqueKey();
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading profile picture: $e');
    }
  }

  void _viewProfilePictureDialog() {
    if (_profileImagePath == null) return;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Image.file(
                          File(_profileImagePath!),
                          key: UniqueKey(),
                          width: double.infinity,
                          height: 400,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.5),
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _showProfilePictureOptions();
                          },
                          icon: const Icon(Icons.edit, size: 20),
                          label: const SmartReTranslator(
                            text: 'Change',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            _removeProfilePicture();
                          },
                          icon: const Icon(Icons.delete, size: 20),
                          label: const SmartReTranslator(
                            text: 'Remove',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showProfilePictureOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SmartReTranslator(
                  text: 'Profile Photo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (_profileImagePath != null)
                  _bottomSheetTile(
                    icon: Icons.visibility_rounded,
                    label: 'View Photo',
                    onTap: () {
                      Navigator.pop(context);
                      _viewProfilePictureDialog();
                    },
                  ),
                _bottomSheetTile(
                  icon: Icons.camera_alt_rounded,
                  label: 'Take Photo',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
                _bottomSheetTile(
                  icon: Icons.photo_library_rounded,
                  label: 'Choose from Gallery',
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                if (_profileImagePath != null)
                  _bottomSheetTile(
                    icon: Icons.delete_rounded,
                    label: 'Remove Photo',
                    iconColor: AppColors.errorColor,
                    textColor: AppColors.errorColor,
                    onTap: () {
                      Navigator.pop(context);
                      _removeProfilePicture();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bottomSheetTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color iconColor = AppColors.primaryGreen,
    Color textColor = AppColors.textPrimary,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: SmartReTranslator(
        text: label,
        style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      onTap: onTap,
    );
  }

  // ============================================================
  // 1:1 SQUARE PROFILE IMAGE CROP
  // ============================================================

Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile == null || !mounted) return;

      // Force 1:1 square crop
      final controller = CropController(aspectRatio: 1.0);

      final croppedFile = await showDialog<File?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: MediaQuery.of(dialogContext).size.height * 0.75,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor: Colors.white,
                    title: const Text('Crop Profile Picture'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                      ),
                    ],
                  ),

                  Expanded(
                    child: CropImage(
                      controller: controller,

                      // IMPORTANT:
                      // crop_image expects an Image widget,
                      // not FileImage.
                      image: Image.file(
                        File(pickedFile.path),
                        fit: BoxFit.contain,
                      ),

                      paddingSize: 20,

                      // Correct parameter for crop_image 1.0.13
                      alwaysShowThirdLines: true,

                      minimumImageSize: 100,
                      maximumImageSize: 2000,

                      gridColor: Colors.white,
                      gridInnerColor: Colors.white70,
                      gridCornerColor: Colors.white,
                      scrimColor: Colors.black54,
                      showCorners: true,
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(16),
                    color: Colors.black,
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.pop(dialogContext);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              try {
                                // Get the cropped square bitmap
                                final bitmap = await controller.croppedBitmap();

                                final directory = await getTemporaryDirectory();

                                final path =
                                    '${directory.path}/cropped_profile_${DateTime.now().millisecondsSinceEpoch}.png';

                                final file = File(path);

                                final bytes = await bitmap.toByteData(
                                  format: ui.ImageByteFormat.png,
                                );

                                if (bytes == null) {
                                  if (dialogContext.mounted) {
                                    Navigator.pop(dialogContext);
                                  }
                                  return;
                                }

                                await file.writeAsBytes(
                                  bytes.buffer.asUint8List(),
                                  flush: true,
                                );

                                if (dialogContext.mounted) {
                                  Navigator.pop(dialogContext, file);
                                }
                              } catch (e) {
                                debugPrint('❌ Crop error: $e');

                                if (dialogContext.mounted) {
                                  ScaffoldMessenger.of(
                                    dialogContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed to crop image: $e'),
                                    ),
                                  );
                                }
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primaryGreen,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Crop & Use'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (croppedFile == null || !mounted) return;

      await _updateProfilePicture(croppedFile);
    } catch (e) {
      debugPrint('❌ Error picking/cropping image: $e');

      if (mounted) {
        _showError('Failed to crop profile picture');
      }
    }
  }
  
  // ============================================================
  // SAVE PROFILE IMAGE
  // ============================================================

  Future<void> _updateProfilePicture(File image) async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson == null) {
        throw 'Profile data not found';
      }

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

      String imageId = profileData['image_id']?.toString() ?? '';

      if (imageId.isEmpty) {
        imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
      }

      final oldLocalPath = await _storage.read(key: 'profile_image_local_path');

      if (oldLocalPath != null && oldLocalPath.isNotEmpty) {
        try {
          await FileImage(File(oldLocalPath)).evict();
        } catch (e) {
          debugPrint('⚠️ Failed to evict old image: $e');
        }

        final oldFile = File(oldLocalPath);

        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }

      final directory = await getApplicationDocumentsDirectory();

      final profileDir = Directory('${directory.path}/profile_pictures');

      if (!await profileDir.exists()) {
        await profileDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final extension = image.path.split('.').last;

      final localPath =
          '${profileDir.path}/profile_${imageId}_$timestamp.$extension';

      await image.copy(localPath);

      await _storage.write(key: 'profile_image_id', value: imageId);

      await _storage.write(key: 'profile_image_local_path', value: localPath);

      await _storage.write(
        key: 'profile_picture_pending_upload',
        value: 'true',
      );

      profileData['image_id'] = imageId;

      await _storage.write(key: 'user_profile', value: jsonEncode(profileData));

      imageCache.clear();
      imageCache.clearLiveImages();

      await _loadProfilePicture();

      _showSuccess('Profile picture saved locally');

      await _checkPendingUpdates();

      _triggerProfileSync();
    } catch (e) {
      debugPrint('❌ Error updating profile picture: $e');

      _showError('Failed to update profile picture');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // ============================================================
  // REMOVE PROFILE IMAGE
  // ============================================================

  Future<void> _removeProfilePicture() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      final userId = await _storage.read(key: 'user_id');

      final response = await ApiService.instance.delete(
        '/profile/remove-profile-picture/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        if (_profileImagePath != null) {
          try {
            await FileImage(File(_profileImagePath!)).evict();
          } catch (e) {
            debugPrint('⚠️ Failed to evict image: $e');
          }

          final file = File(_profileImagePath!);

          if (await file.exists()) {
            await file.delete();
          }
        }

        await _storage.delete(key: 'profile_image_id');

        await _storage.delete(key: 'profile_image_local_path');

        await _storage.delete(key: 'profile_picture_pending_upload');

        final profileJson = await _storage.read(key: 'user_profile');

        if (profileJson != null) {
          final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

          profileData['image_id'] = null;
          profileData['pic_url'] = 'no-image';

          await _storage.write(
            key: 'user_profile',
            value: jsonEncode(profileData),
          );
        }

        imageCache.clear();
        imageCache.clearLiveImages();

        await _loadProfilePicture();

        _showSuccess('Profile picture removed');
      } else {
        _showError('Failed to remove profile picture');
      }
    } catch (e) {
      debugPrint('❌ Error removing profile picture: $e');

      _showError('Failed to remove profile picture');
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // ============================================================
  // ERROR / SUCCESS
  // ============================================================

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

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    final Map<String, dynamic> updates = {};

    if (_nameCtrl.text.trim() != _name.trim()) {
      updates['name'] = _nameCtrl.text.trim();
    }

    if (!_emailVerified &&
        _emailCtrl.text.trim().isNotEmpty &&
        _emailCtrl.text.trim() != _email.trim()) {
      updates['email'] = _emailCtrl.text.trim();
    }

    if (_addressCtrl.text.trim() != _address.trim()) {
      updates['address'] = _addressCtrl.text.trim();
    }

    if (_pincodeCtrl.text.trim() != _pincode.trim()) {
      updates['pincode'] = _pincodeCtrl.text.trim();
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

      updates['dob'] = dobIso;
    }

    if (updates.isEmpty) {
      setState(() {
        _isEditing = false;
      });

      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final currentJson = await _storage.read(key: 'user_profile');

      final profileData = currentJson != null && currentJson.isNotEmpty
          ? jsonDecode(currentJson) as Map<String, dynamic>
          : <String, dynamic>{};

      profileData.addAll(updates);

      profileData['updated_at'] = DateTime.now().toIso8601String();

      await _storage.write(key: 'user_profile', value: jsonEncode(profileData));

      await _storage.write(key: 'profile_data_pending', value: 'true');

      await _storage.write(
        key: 'profile_pending_updates',
        value: jsonEncode(updates),
      );

      await _reloadUserProfileQuietly();

      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }

      _showSuccess('Profile updated (will sync when online)');

      await _checkPendingUpdates();

      _triggerProfileSync();
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');

      _showError('Error updating profile: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _handleBackPressed() {
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
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 10),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: _profileImagePath != null
                    ? _viewProfilePictureDialog
                    : _showProfilePictureOptions,
                child: Container(
                  key: _profileImageKey,
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.18),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.9),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.10),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
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
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        )
                      : null,
                ),
              ),
              if (_isUploadingImage)
                Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.42),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _showProfilePictureOptions,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.14),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              if (_emailVerified)
                Positioned(
                  top: -2,
                  right: 2,
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
          const SizedBox(height: 8),
          if (_isEditing)
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                textInputAction: TextInputAction.next,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter name',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.92),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: Colors.black.withOpacity(0.06),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: AppColors.primaryGreen,
                      width: 1.4,
                    ),
                  ),
                ),
              ),
            )
          else
            Text(
              _name.isNotEmpty ? _name : 'Guest User',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          if (_category.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.75),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                _category,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SYNC BANNER
  // ============================================================

  Widget _buildProfileSyncBanner() {
    if (_pendingProfileUpdatesCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.4),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange.shade700,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SmartReTranslator(
              text: _pendingProfileUpdatesCount == 1
                  ? 'Profile update pending sync'
                  : '$_pendingProfileUpdatesCount profile updates pending sync',
              style: TextStyle(
                fontSize: 12,
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: _isSyncing ? null : _triggerProfileSync,
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const SmartReTranslator(
                    text: 'Sync Now',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // EMAIL VERIFICATION
  // ============================================================

  Widget _buildVerificationBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withOpacity(0.96),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.4),
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
                    final profileData =
                        jsonDecode(profileJson) as Map<String, dynamic>;

                    profileData['email_verified'] = true;

                    await _storage.write(
                      key: 'user_profile',
                      value: jsonEncode(profileData),
                    );
                  }
                } catch (e) {
                  debugPrint('Error updating verification status: $e');
                }

                setState(() {
                  _emailVerified = true;
                });

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

  // ============================================================
  // PROFILE DETAILS
  // ============================================================

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
            locked: _emailVerified,
            keyboardType: TextInputType.emailAddress,
            helperText: _emailVerified
                ? 'Verified email cannot be changed'
                : 'You can edit this email until it is verified',
          ),
          const SizedBox(height: 10),
          _buildDetailCard(
            icon: Icons.phone_outlined,
            title: 'Phone',
            value: _phone,
            isEditing: false,
            helperText: 'Phone number cannot be edited here',
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
            keyboardType: TextInputType.streetAddress,
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
    bool locked = false,
    TextInputType? keyboardType,
    String? helperText,
  }) {
    final showField = isEditing && controller != null;

    final isLockedField = showField && !enabledWhenEditing;

    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 2),
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
                  Row(
                    children: [
                      Expanded(
                        child: SmartReTranslator(
                          text: title,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      if (verified)
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: AppColors.successColor.withOpacity(0.10),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified,
                            color: AppColors.successColor,
                            size: 15,
                          ),
                        ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.14),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            color: Colors.black54,
                            size: 15,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (!showField)
                    Text(
                      value.isNotEmpty ? value : 'Not provided',
                      style: TextStyle(
                        fontSize: 14.5,
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
                              final initialDate = _parseDob(_dobCtrl.text);

                              final now = DateTime.now();

                              final picked = await showDatePicker(
                                context: context,
                                initialDate: initialDate.isAfter(now)
                                    ? now
                                    : initialDate,
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
                        absorbing: isDate || isLockedField,
                        child: TextField(
                          controller: controller,
                          enabled: enabledWhenEditing,
                          keyboardType: keyboardType,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'Enter $title',
                            filled: true,
                            fillColor: isLockedField
                                ? Colors.grey.withOpacity(0.08)
                                : Colors.white,
                            prefixIcon: isDate
                                ? const Icon(Icons.calendar_month_rounded)
                                : null,
                            suffixIcon: isLockedField
                                ? const Icon(
                                    Icons.lock_rounded,
                                    color: Colors.black45,
                                    size: 18,
                                  )
                                : isDate
                                ? const Icon(Icons.arrow_drop_down_rounded)
                                : null,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 13,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.08),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primaryGreen,
                                width: 1.4,
                              ),
                            ),
                            disabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.black.withOpacity(0.06),
                              ),
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  if (helperText != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      helperText,
                      style: TextStyle(
                        fontSize: 11,
                        color: locked
                            ? Colors.black54
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  DateTime _parseDob(String value) {
    try {
      return DateFormat('dd MMM yyyy').parse(value);
    } catch (_) {
      return DateTime(2000, 1, 1);
    }
  }

  // ============================================================
  // EDIT ACTION
  // ============================================================

  Widget _buildEditAction() {
    if (_isSaving) {
      return const Padding(
        padding: EdgeInsets.only(right: 12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: Colors.black,
          ),
        ),
      );
    }

    return AppBarActionButton(
      icon: _isEditing ? Icons.check_rounded : Icons.edit_rounded,
      tooltip: _isEditing ? 'Save' : 'Edit',
      color: Colors.black,
      onPressed: () async {
        if (_isEditing) {
          await _saveProfile();
        } else {
          setState(() {
            _isEditing = true;
          });
        }
      },
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: CustomAppBar(
        title: 'Profile',
        backgroundColor: Colors.transparent,
        elevation: 0,
        showOnlineStatus: true,
        onBackPressed: _handleBackPressed,
        actions: [if (!_isLoading) _buildEditAction()],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _reloadUserProfileQuietly();
                await _triggerProfileSync();
                await _checkPendingUpdates();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _buildProfileHeader(),
                    _buildProfileSyncBanner(),
                    if (!_emailVerified) _buildVerificationBanner(),
                    _buildProfileDetails(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }
}
