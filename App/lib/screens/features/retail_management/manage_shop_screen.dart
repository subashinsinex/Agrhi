import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/retail_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../utils/constants.dart';
import 'dart:convert';

class ManageShopScreen extends StatefulWidget {
  final String? retailerId; // ✅ ADD: Optional retailerId for editing

  const ManageShopScreen({super.key, this.retailerId}); // ✅ UPDATE

  @override
  State<ManageShopScreen> createState() => _ManageShopScreenState();
}

class _ManageShopScreenState extends State<ManageShopScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameController = TextEditingController();
  final _shopAddressController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();

  String? _businessType = 'fertilizer';
  bool _isLoading = false;
  bool _isEditing = false;
  String? _retailerId;
  String? _shopImageUrl;
  File? _selectedImage;

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

      // ✅ If retailerId provided from shops list, load that specific shop
      if (widget.retailerId != null) {
        retailerData = await RetailService.getShopById(widget.retailerId!);
      }

      if (retailerData != null) {
        setState(() {
          _isEditing = true;
          _retailerId = retailerData!['retailer_id'];
          _shopNameController.text = retailerData['shop_name'] ?? '';
          _shopAddressController.text = retailerData['shop_address'] ?? '';
          _gstNumberController.text = retailerData['gst_number'] ?? '';
          _licenseNumberController.text = retailerData['license_number'] ?? '';
          _businessType = retailerData['business_type'] ?? 'fertilizer';
          _latitudeController.text = retailerData['latitude']?.toString() ?? '';
          _longitudeController.text =
              retailerData['longitude']?.toString() ?? '';
          _shopImageUrl = retailerData['shop_image_url'];
        });
      }
    } catch (e) {
      debugPrint('Error loading shop data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveShop() async {
    if (!_formKey.currentState!.validate()) return;

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
        'shop_address': _shopAddressController.text.trim(),
        'gst_number': _gstNumberController.text.trim(),
        'business_type': _businessType,
        'license_number': _licenseNumberController.text.trim(),
        'latitude': double.tryParse(_latitudeController.text.trim()),
        'longitude': double.tryParse(_longitudeController.text.trim()),
      };

      String? newRetailerId;

      if (_isEditing && _retailerId != null) {
        await RetailService.updateRetailer(_retailerId!, shopData);
      } else {
        final response = await RetailService.createRetailer(shopData);
        newRetailerId = response['retailer_id'];
        setState(() {
          _retailerId = newRetailerId;
          _isEditing = true;
        });
      }

      // Upload image if selected
      if (_selectedImage != null && _retailerId != null) {
        await RetailService.uploadShopImage(_retailerId!, _selectedImage!);
        await _loadShopData(); // Reload to get updated image URL
      }

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
        Navigator.pop(context, true); // ✅ Return true on success
      }
    } catch (e) {
      debugPrint('Error saving shop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error: $e'),
            backgroundColor: AppColors.errorColor,
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
      appBar: const CustomAppBar(showOnlineStatus: true, title: 'Manage Shop'),
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Shop Image'),
                  const SizedBox(height: 12),
                  _buildImagePicker(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Basic Information'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _shopNameController,
                    label: 'Shop Name',
                    icon: Icons.store,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Shop name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _shopAddressController,
                    label: 'Shop Address',
                    icon: Icons.location_on,
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Shop address is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildBusinessTypeDropdown(),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Registration Details'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _gstNumberController,
                    label: 'GST Number',
                    icon: Icons.receipt_long,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _licenseNumberController,
                    label: 'License Number',
                    icon: Icons.badge,
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('Location'),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    icon: Icons.location_searching,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    icon: Icons.location_searching,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveShop,
                    icon: Icon(
                      _isEditing ? Icons.save : Icons.add,
                      color: Colors.white,
                    ),
                    label: SmartReTranslator(
                      text: _isEditing ? 'Update Shop' : 'Create Shop',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return SmartReTranslator(
      text: title,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 18,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: _selectedImage != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_selectedImage!, fit: BoxFit.cover),
              )
            : _shopImageUrl != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${AppConstants.baseUrl.replaceAll('/api', '')}$_shopImageUrl',
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImagePlaceholder();
                  },
                ),
              )
            : _buildImagePlaceholder(),
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
        const SizedBox(height: 8),
        SmartReTranslator(
          text: 'Tap to add shop image',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.errorColor),
        ),
      ),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
    );
  }

  Widget _buildBusinessTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _businessType,
      decoration: InputDecoration(
        labelText: 'Business Type',
        prefixIcon: Icon(Icons.business, color: AppColors.primaryGreen),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryGreen, width: 2),
        ),
      ),
      dropdownColor: Colors.white,
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
      onChanged: (value) => setState(() => _businessType = value),
    );
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _shopAddressController.dispose();
    _gstNumberController.dispose();
    _licenseNumberController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }
}
