// lib/screens/profile/profile_screen.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:crop_image/crop_image.dart';
import '../shared/smart_retranslator.dart';
import '../auth/email_verify_screen.dart';
import '../../utils/colors.dart';
import '../../src/services/api_service.dart';
import '../../src/services/sync_service.dart';

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
    if (mounted) {
      setState(() => _pendingProfileUpdatesCount = count);
    }

    if (count > 0) {
      _triggerProfileSync();
    }
  }

  Future<void> _triggerProfileSync() async {
    if (_isSyncing) {
      debugPrint('⏭️ Profile sync already in progress');
      return;
    }

    setState(() => _isSyncing = true);

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
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);

    try {
      await _reloadUserProfileQuietly();
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _reloadUserProfileQuietly() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');

      if (profileJson != null && profileJson.isNotEmpty) {
        final profileData = jsonDecode(profileJson) as Map<String, dynamic>;

        if (mounted) {
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

            _nameCtrl.text = _name;
            _emailCtrl.text = _email;
            _addressCtrl.text = _address;
            _pincodeCtrl.text = _pincode;
            _dobCtrl.text = _dob;
          });
        }

        await _loadProfilePicture();
      } else {
        _showError('Profile data not found');
      }
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
            FileImage(File(_profileImagePath!)).evict();
          } catch (e) {
            debugPrint('⚠️ Failed to evict old image cache: $e');
          }
        }

        try {
          FileImage(file).evict();
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
      builder: (context) => Dialog(
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
                child: Column(
                  children: [
                    Row(
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewerButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: (color ?? Colors.white).withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color ?? Colors.white, width: 2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color ?? Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color ?? Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showProfilePictureOptions() {
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
              if (_profileImagePath != null)
                ListTile(
                  leading: const Icon(
                    Icons.visibility,
                    color: AppColors.primaryGreen,
                  ),
                  title: const SmartReTranslator(text: 'View Photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _viewProfilePictureDialog();
                  },
                ),
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

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );

      if (pickedFile == null) return;

      final croppedFile = await _showCropDialog(File(pickedFile.path));

      if (croppedFile != null) {
        await _updateProfilePicture(croppedFile);
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      _showError('Failed to pick image');
    }
  }

  Future<File?> _showCropDialog(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final controller = CropController(
        aspectRatio: 1,
        defaultCrop: const Rect.fromLTRB(0.1, 0.1, 0.9, 0.9),
      );

      final croppedImage = await showDialog<Uint8List?>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 8,
                  bottom: 12,
                  left: 16,
                  right: 16,
                ),
                color: AppColors.primaryGreen,
                child: const Row(
                  children: [
                    Expanded(
                      child: SmartReTranslator(
                        text: 'Crop Profile Picture',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: CropImage(
                  controller: controller,
                  image: Image.memory(imageBytes),
                  gridColor: Colors.white,
                  gridCornerSize: 50,
                  gridThinWidth: 1,
                  gridThickWidth: 3,
                  scrimColor: Colors.black.withOpacity(0.7),
                  alwaysShowThirdLines: true,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.black87,
                child: const SmartReTranslator(
                  text: 'Pinch to zoom • Drag to reposition',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Container(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 20,
                  left: 20,
                  right: 20,
                ),
                color: Colors.black,
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(dialogContext).pop(null),
                        icon: const Icon(Icons.close),
                        label: const SmartReTranslator(
                          text: 'Cancel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            final bitmap = await controller.croppedBitmap();
                            final byteData = await bitmap.toByteData(
                              format: ui.ImageByteFormat.png,
                            );

                            if (byteData != null) {
                              final bytes = byteData.buffer.asUint8List();
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(bytes);
                              }
                            } else {
                              if (dialogContext.mounted) {
                                Navigator.of(dialogContext).pop(null);
                              }
                            }
                          } catch (e) {
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(null);
                            }
                          }
                        },
                        icon: const Icon(Icons.check),
                        label: const SmartReTranslator(
                          text: 'Confirm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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

      if (croppedImage == null) return null;

      final directory = await getTemporaryDirectory();
      final croppedFile = File(
        '${directory.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await croppedFile.writeAsBytes(croppedImage);

      return croppedFile;
    } catch (e) {
      debugPrint('❌ Error cropping image: $e');
      _showError('Failed to crop image');
      return null;
    }
  }

  Future<void> _updateProfilePicture(File image) async {
    try {
      setState(() => _isUploadingImage = true);

      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) throw 'Profile data not found';

      final profileData = jsonDecode(profileJson) as Map<String, dynamic>;
      String imageId = profileData['image_id']?.toString() ?? '';

      if (imageId.isEmpty) {
        imageId = 'img_${DateTime.now().millisecondsSinceEpoch}';
      }

      final oldLocalPath = await _storage.read(key: 'profile_image_local_path');
      if (oldLocalPath != null && oldLocalPath.isNotEmpty) {
        try {
          FileImage(File(oldLocalPath)).evict();
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
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _removeProfilePicture() async {
    try {
      setState(() => _isUploadingImage = true);

      final userId = await _storage.read(key: 'user_id');
      final response = await ApiService.instance.delete(
        '/profile/remove-profile-picture/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        if (_profileImagePath != null) {
          try {
            FileImage(File(_profileImagePath!)).evict();
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
      setState(() => _isEditing = false);
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentJson = await _storage.read(key: 'user_profile');
      Map<String, dynamic> profileData =
          currentJson != null && currentJson.isNotEmpty
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

      setState(() => _isEditing = false);

      _showSuccess('Profile updated (will sync when online)');
      await _checkPendingUpdates();

      _triggerProfileSync();
    } catch (e) {
      debugPrint('❌ Error saving profile: $e');
      _showError('Error updating profile: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildProfileSyncBanner() {
    if (_pendingProfileUpdatesCount == 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300, width: 1.5),
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
              GestureDetector(
                onTap: _profileImagePath != null
                    ? _viewProfilePictureDialog
                    : _showProfilePictureOptions,
                child: Container(
                  key: _profileImageKey,
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
              ),
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
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _showProfilePictureOptions,
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
          if (_isEditing)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _nameCtrl,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.transparent,
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.5),
                    ),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                ),
                cursorColor: Colors.white,
              ),
            )
          else
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
