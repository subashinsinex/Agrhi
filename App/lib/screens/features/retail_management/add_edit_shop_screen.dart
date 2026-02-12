import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/retail_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../utils/constants.dart';
import 'dart:convert';

class ManageShopScreen extends StatefulWidget {
  final String? retailerId;

  const ManageShopScreen({super.key, this.retailerId});

  @override
  State<ManageShopScreen> createState() => _ManageShopScreenState();
}

class _ManageShopScreenState extends State<ManageShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopNumberController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  // ✅ Create ImagePicker instance once (reuse it)
  final ImagePicker _picker = ImagePicker();

  String? _businessType = 'fertilizer';
  bool _isLoading = false;
  bool _isEditing = false;
  String? _retailerId;
  String? _shopImageUrl;
  File? _selectedImage;
  double? _capturedLatitude;
  double? _capturedLongitude;
  bool _locationCaptured = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  Future<void> _loadShopData() async {
    setState(() => _isLoading = true);

    try {
      Map<String, dynamic>? retailerData;

      if (widget.retailerId != null) {
        retailerData = await RetailService.getShopById(widget.retailerId!);
      }

      if (retailerData != null) {
        debugPrint('📥 Loading shop data: $retailerData');

        setState(() {
          _isEditing = true;
          _retailerId = retailerData!['retailer_id'];
          _shopNameController.text = retailerData['shop_name'] ?? '';
          _shopNumberController.text = retailerData['shop_number'] ?? '';
          _shopAddressController.text = retailerData['shop_address'] ?? '';
          _gstNumberController.text = retailerData['gst_number'] ?? '';
          _licenseNumberController.text = retailerData['license_number'] ?? '';
          _businessType = retailerData['business_type'] ?? 'fertilizer';

          _capturedLatitude = _parseDouble(retailerData['latitude']);
          _capturedLongitude = _parseDouble(retailerData['longitude']);

          _shopImageUrl =
              retailerData['shop_image_url'] ??
              retailerData['image_url'] ??
              retailerData['shop_image'];

          _locationCaptured =
              _capturedLatitude != null && _capturedLongitude != null;

          debugPrint('✅ Shop image URL: $_shopImageUrl');
          debugPrint('✅ Latitude: $_capturedLatitude');
          debugPrint('✅ Longitude: $_capturedLongitude');
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading shop data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error loading shop data: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      try {
        return double.parse(value);
      } catch (e) {
        debugPrint('❌ Error parsing double from string: $value');
        return null;
      }
    }
    return null;
  }

  Future<bool> _handleLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: SmartReTranslator(
              text: 'Location services are disabled. Please enable them.',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: SmartReTranslator(text: 'Location permission denied'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: SmartReTranslator(
              text: 'Location permissions are permanently denied',
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      return false;
    }

    return true;
  }

  // ✅ Optimized: Get location first (use last known for speed), then capture image
  Future<void> _captureImageWithLocation() async {
    final hasPermission = await _handleLocationPermission();
    if (!hasPermission) return;

    setState(() => _isLoading = true);

    try {
      // ✅ Step 1: Get last known position first (instant)
      Position? position = await Geolocator.getLastKnownPosition();

      // ✅ Step 2: Open camera immediately with last known position
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear, // ✅ Specify rear camera
      );

      if (pickedFile != null) {
        // ✅ Step 3: Get accurate current position in background (if last known was null)
        position ??= await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10),
        );

        setState(() {
          _selectedImage = File(pickedFile.path);
          _capturedLatitude = position!.latitude;
          _capturedLongitude = position.longitude;
          _locationCaptured = true;
          _shopImageUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SmartReTranslator(
                text:
                    'Image captured with location: ${position.latitude.toStringAsFixed(5)}, ${position.longitude.toStringAsFixed(5)}',
              ),
              backgroundColor: AppColors.successColor,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error capturing image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error capturing image: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ✅ Two-step shop creation: 1) Create retailer, 2) Upload image
  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedImage == null && _shopImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(text: 'Please capture shop image'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    if (!_locationCaptured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: SmartReTranslator(
            text: 'Please capture image to get shop location',
          ),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) {
        throw Exception('User profile not found');
      }

      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      final userId = profile['user_id'];

      final shopData = {
        'user_id': userId,
        'shop_name': _shopNameController.text.trim(),
        'shop_number': _shopNumberController.text.trim(),
        'shop_address': _shopAddressController.text.trim(),
        'gst_number': _gstNumberController.text.trim(),
        'business_type': _businessType,
        'license_number': _licenseNumberController.text.trim(),
        'latitude': _capturedLatitude,
        'longitude': _capturedLongitude,
      };

      if (_isEditing && _retailerId != null) {
        // ✅ Editing existing shop
        debugPrint('🔄 Updating existing shop: $_retailerId');
        await RetailService.updateRetailer(_retailerId!, shopData);

        // ✅ Upload new image only if selected
        if (_selectedImage != null) {
          debugPrint('📤 Uploading new shop image...');
          await RetailService.uploadShopImage(_retailerId!, _selectedImage!);
        }
      } else {
        // ✅ Creating new shop - TWO SEQUENTIAL API CALLS
        debugPrint('➕ Creating new shop with two-step process...');

        // ✅ STEP 1: Create retailer and get retailer_id
        debugPrint('📤 Step 1: Creating retailer details...');
        final response = await RetailService.createRetailer(shopData);
        final newRetailerId = response['retailer_id'];

        if (newRetailerId == null) {
          throw Exception('Failed to create shop: No retailer_id returned');
        }

        debugPrint('✅ Shop created with ID: $newRetailerId');

        setState(() {
          _retailerId = newRetailerId;
          _isEditing = true;
        });

        // ✅ STEP 2: Upload shop image using the returned retailer_id
        if (_selectedImage != null) {
          debugPrint(
            '📤 Step 2: Uploading shop image for retailer: $newRetailerId',
          );
          await RetailService.uploadShopImage(newRetailerId, _selectedImage!);
          debugPrint('✅ Shop image uploaded successfully');
        } else {
          debugPrint('⚠️ No image to upload');
        }
      }

      // ✅ Reload shop data to get updated image URL
      debugPrint('🔄 Reloading shop data...');
      await _loadShopData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(
              text: _isEditing
                  ? 'Shop updated successfully'
                  : 'Shop created successfully',
            ),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error saving shop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error: $e'),
            backgroundColor: AppColors.errorColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showOnlineStatus: true,
        title: _isEditing ? 'Edit Shop' : 'Create Shop',
      ),
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  const SizedBox(height: 16),
                  SmartReTranslator(
                    text: _isEditing ? 'Updating shop...' : 'Creating shop...',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        icon: Icons.camera_alt,
                        title: 'Shop Image & Location',
                        subtitle: 'Capture your shop with GPS location',
                      ),
                      const SizedBox(height: 16),
                      _buildImageCapture(),

                      if (_locationCaptured) ...[
                        const SizedBox(height: 16),
                        _buildLocationCard(),
                        const SizedBox(height: 16),
                        _buildLocationPreview(),
                      ],

                      const SizedBox(height: 32),

                      _buildSectionHeader(
                        icon: Icons.store,
                        title: 'Basic Information',
                        subtitle: 'Enter your shop details',
                      ),
                      const SizedBox(height: 16),

                      _buildLabeledTextField(
                        label: 'Shop Name',
                        controller: _shopNameController,
                        icon: Icons.store_outlined,
                        hint: 'Enter your shop name',
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Shop name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Shop Number',
                        controller: _shopNumberController,
                        icon: Icons.phone_outlined,
                        hint: 'Enter contact number',
                        keyboardType: TextInputType.phone,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Shop number is required';
                          }
                          if (value.trim().length < 7 || value.trim().length > 15) {
                            return 'Enter a valid phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Shop Address',
                        controller: _shopAddressController,
                        icon: Icons.location_on_outlined,
                        hint: 'Enter complete address',
                        maxLines: 3,
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Shop address is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledDropdown(),

                      const SizedBox(height: 32),

                      _buildSectionHeader(
                        icon: Icons.description,
                        title: 'Registration Details',
                        subtitle: 'Optional tax and license information',
                      ),
                      const SizedBox(height: 16),

                      _buildLabeledTextField(
                        label: 'GST Number',
                        controller: _gstNumberController,
                        icon: Icons.receipt_long_outlined,
                        hint: 'Enter GST number (Optional)',
                        isRequired: false,
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'License Number',
                        controller: _licenseNumberController,
                        icon: Icons.badge_outlined,
                        hint: 'Enter license number (Optional)',
                        isRequired: false,
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveShop,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            disabledBackgroundColor: Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      _isEditing
                                          ? Icons.check_circle
                                          : Icons.add_circle,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    SmartReTranslator(
                                      text: _isEditing
                                          ? 'Update Shop'
                                          : 'Create Shop',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppColors.primaryGreen, size: 24),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SmartReTranslator(
                text: title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              SmartReTranslator(
                text: subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildImageCapture() {
    return GestureDetector(
      onTap: _isLoading ? null : _captureImageWithLocation,
      child: Container(
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _locationCaptured
                ? AppColors.successColor
                : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _locationCaptured
                  ? AppColors.successColor.withOpacity(0.1)
                  : Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _selectedImage != null
              ? _buildSelectedImagePreview()
              : _shopImageUrl != null
              ? _buildNetworkImagePreview()
              : _buildImagePlaceholder(),
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(_selectedImage!, fit: BoxFit.cover),
        _buildImageOverlay('New Image Selected'),
      ],
    );
  }

  Widget _buildNetworkImagePreview() {
    final imageUrl = _shopImageUrl!.startsWith('http')
        ? _shopImageUrl!
        : '${AppConstants.baseUrl.replaceAll('/api', '')}$_shopImageUrl';

    debugPrint('🖼️ Loading image from: $imageUrl');

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          imageUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                        : null,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 12),
                  SmartReTranslator(
                    text: 'Loading image...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            debugPrint('❌ Error loading image: $error');
            debugPrint('❌ Stack trace: $stackTrace');
            return _buildImagePlaceholder();
          },
        ),
        _buildImageOverlay('Tap to change image'),
      ],
    );
  }

  Widget _buildImageOverlay(String text) {
    return Positioned(
      top: 12,
      right: 12,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _locationCaptured
              ? AppColors.successColor
              : AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _locationCaptured ? Icons.check_circle : Icons.camera_alt,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 6),
            SmartReTranslator(
              text: text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade50,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add_a_photo,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          const SmartReTranslator(
            text: 'Tap to capture shop image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SmartReTranslator(
            text: 'Location will be captured automatically',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.successColor.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.successColor.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.successColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.my_location,
              color: AppColors.successColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SmartReTranslator(
                  text: 'GPS Coordinates',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_capturedLatitude!.toStringAsFixed(6)}, ${_capturedLongitude!.toStringAsFixed(6)}',
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.check_circle,
            color: AppColors.successColor,
            size: 24,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationPreview() {
    if (_capturedLatitude == null || _capturedLongitude == null) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: LatLng(_capturedLatitude!, _capturedLongitude!),
                initialZoom: 17,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.agrhi.com',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(_capturedLatitude!, _capturedLongitude!),
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.store,
                          color: AppColors.primaryGreen,
                          size: 30,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: const Text(
                  '© OpenStreetMap',
                  style: TextStyle(fontSize: 9, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabeledTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required String hint,
    bool isRequired = false,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SmartReTranslator(
              text: label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (isRequired)
              const Text(
                ' *',
                style: TextStyle(
                  color: AppColors.errorColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          validator: validator,
          enabled: !_isLoading,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: Icon(icon, color: AppColors.primaryGreen, size: 22),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.errorColor),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.errorColor,
                width: 2,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade200),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLabeledDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            SmartReTranslator(
              text: 'Business Type',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              ' *',
              style: TextStyle(
                color: AppColors.errorColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _businessType,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: const Icon(
              Icons.business,
              color: AppColors.primaryGreen,
              size: 22,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primaryGreen,
                width: 2,
              ),
            ),
          ),
          items: const [
            DropdownMenuItem(
              value: 'fertilizer',
              child: SmartReTranslator(text: 'Fertilizer'),
            ),
            DropdownMenuItem(
              value: 'seeds',
              child: SmartReTranslator(text: 'Seeds'),
            ),
            DropdownMenuItem(
              value: 'tools',
              child: SmartReTranslator(text: 'Tools'),
            ),
            DropdownMenuItem(
              value: 'all',
              child: SmartReTranslator(text: 'All Products'),
            ),
          ],
          onChanged: _isLoading
              ? null
              : (value) => setState(() => _businessType = value),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopNumberController.dispose();
    _shopAddressController.dispose();
    _gstNumberController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }
}
