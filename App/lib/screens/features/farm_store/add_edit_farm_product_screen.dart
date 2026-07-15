import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/farm_store_service.dart';
import '../../../utils/constants.dart';

class AddEditFarmProductScreen extends StatefulWidget {
  final String farmerId;
  final Map<String, dynamic>? product;

  const AddEditFarmProductScreen({
    super.key,
    required this.farmerId,
    this.product,
  });

  @override
  State<AddEditFarmProductScreen> createState() =>
      _AddEditFarmProductScreenState();
}

class _AddEditFarmProductScreenState extends State<AddEditFarmProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _varietyController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();

  final ImagePicker _picker = ImagePicker();

  String? _unit = 'kg';
  bool _isLoading = false;
  bool _isEditing = false;
  String? _productId;
  String? _productImageUrl;
  File? _selectedImage;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.product != null;
    if (_isEditing) {
      _populateFormData();
    }
  }

  void _populateFormData() {
    final product = widget.product!;
    _productId = product['product_id'];
    _productNameController.text = product['product_name'] ?? '';
    _varietyController.text = product['variety'] ?? '';
    _descriptionController.text = product['description'] ?? '';
    _priceController.text = product['price_per_unit']?.toString() ?? '';
    _quantityController.text = product['quantity_available']?.toString() ?? '';
    _unit = product['unit'] ?? 'kg';
    _productImageUrl = product['image_url'];

    debugPrint('📥 Loading farm product data: $_productId');
    debugPrint('✅ Product image URL: $_productImageUrl');
  }

  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _productImageUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: SmartReTranslator(text: 'Image selected successfully'),
              backgroundColor: AppColors.successColor,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error picking from camera: $e');
      _showErrorSnackBar('Failed to open camera: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _productImageUrl = null;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: SmartReTranslator(text: 'Image selected successfully'),
              backgroundColor: AppColors.successColor,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error picking from gallery: $e');
      _showErrorSnackBar('Failed to open gallery: $e');
    }
  }

  Future<void> _showImageSourceDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const SmartReTranslator(
          text: 'Choose Image Source',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryGreen,
                ),
              ),
              title: const SmartReTranslator(text: 'Camera'),
              subtitle: const SmartReTranslator(
                text: 'Take a new photo',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _pickImageFromCamera();
                });
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.photo_library,
                  color: AppColors.primaryGreen,
                ),
              ),
              title: const SmartReTranslator(text: 'Gallery'),
              subtitle: const SmartReTranslator(
                text: 'Choose from existing photos',
                style: TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                Future.delayed(const Duration(milliseconds: 100), () {
                  _pickImageFromGallery();
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SmartReTranslator(text: message),
        backgroundColor: AppColors.errorColor,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'product_name': _productNameController.text.trim(),
        'variety': _varietyController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price_per_unit': double.parse(_priceController.text.trim()),
        'unit': _unit,
        'quantity_available': double.parse(_quantityController.text.trim()),
      };

      if (_isEditing && _productId != null) {
        debugPrint('🔄 Updating existing farm product: $_productId');
        await FarmStoreService.updateFarmProduct(_productId!, productData);

        if (_selectedImage != null) {
          debugPrint('📤 Uploading new product image...');
          await FarmStoreService.uploadFarmProductImage(
            _productId!,
            _selectedImage!,
          );
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: SmartReTranslator(text: 'Product updated successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        debugPrint('➕ Creating new farm product...');

        final response = await FarmStoreService.createFarmProduct(productData);
        final newProductId = response['product_id'];

        if (newProductId == null) {
          throw Exception('Failed to create product: No product_id returned');
        }

        debugPrint('✅ Farm product created with ID: $newProductId');

        setState(() {
          _productId = newProductId;
          _isEditing = true;
        });

        if (_selectedImage != null) {
          debugPrint('📤 Uploading product image for: $newProductId');
          await FarmStoreService.uploadFarmProductImage(
            newProductId,
            _selectedImage!,
          );
          debugPrint('✅ Product image uploaded successfully');
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: SmartReTranslator(text: 'Product created successfully'),
              backgroundColor: AppColors.successColor,
            ),
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('❌ Error saving farm product: $e');
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
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showOnlineStatus: true,
        title: _isEditing ? 'Edit Product' : 'Add Product',
      ),
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(height: 16),
                  SmartReTranslator(
                    text: _isEditing
                        ? 'Updating product...'
                        : 'Creating product...',
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
                        icon: Icons.image,
                        title: 'Product Image',
                        subtitle: 'Add a clear photo of your produce',
                      ),
                      const SizedBox(height: 16),
                      _buildImagePicker(),

                      const SizedBox(height: 32),

                      _buildSectionHeader(
                        icon: Icons.agriculture,
                        title: 'Product Information',
                        subtitle: 'Enter product details',
                      ),
                      const SizedBox(height: 16),

                      _buildLabeledTextField(
                        label: 'Product Name',
                        controller: _productNameController,
                        icon: Icons.eco,
                        hint: 'e.g., Tomato, Rice, Mango',
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Product name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Variety',
                        controller: _varietyController,
                        icon: Icons.local_florist_outlined,
                        hint: 'e.g., Cherry, Basmati (Optional)',
                        isRequired: false,
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        icon: Icons.description_outlined,
                        hint: 'Describe your product (Optional)',
                        maxLines: 3,
                        isRequired: false,
                      ),

                      const SizedBox(height: 32),

                      _buildSectionHeader(
                        icon: Icons.monetization_on,
                        title: 'Pricing & Quantity',
                        subtitle: 'Set your selling price and quantity',
                      ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: _buildLabeledTextField(
                              label: 'Price',
                              controller: _priceController,
                              icon: Icons.currency_rupee,
                              hint: 'Enter price',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d*'),
                                ),
                              ],
                              isRequired: true,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Price required';
                                }
                                final price = double.tryParse(value);
                                if (price == null || price <= 0) {
                                  return 'Invalid price';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildLabeledDropdown(
                              label: 'Unit',
                              value: _unit,
                              icon: null,
                              items: const [
                                DropdownMenuItem(
                                  value: 'kg',
                                  child: Text('kg'),
                                ),
                                DropdownMenuItem(
                                  value: 'gram',
                                  child: Text('gram'),
                                ),
                                DropdownMenuItem(
                                  value: 'liter',
                                  child: Text('liter'),
                                ),
                                DropdownMenuItem(
                                  value: 'dozen',
                                  child: Text('dozen'),
                                ),
                                DropdownMenuItem(
                                  value: 'piece',
                                  child: Text('piece'),
                                ),
                              ],
                              onChanged: (value) =>
                                  setState(() => _unit = value),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Quantity Available',
                        controller: _quantityController,
                        icon: Icons.inventory_outlined,
                        hint: 'Enter available quantity',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*'),
                          ),
                        ],
                        isRequired: true,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Quantity is required';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty < 0) {
                            return 'Enter valid quantity';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 40),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _saveProduct,
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
                                          ? 'Update Product'
                                          : 'Create Product',
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

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isLoading ? null : _showImageSourceDialog,
      child: Container(
        alignment: Alignment.center,
        height: 240,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _selectedImage != null || _productImageUrl != null
                ? AppColors.primaryGreen
                : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: _selectedImage != null
              ? _buildSelectedImagePreview()
              : _productImageUrl != null
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
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 16),
                SizedBox(width: 6),
                SmartReTranslator(
                  text: 'New Image',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNetworkImagePreview() {
    final imageUrl = _productImageUrl!.startsWith('http')
        ? _productImageUrl!
        : '${AppConstants.baseUrl.replaceAll('/api', '')}$_productImageUrl';

    debugPrint('🖼️ Loading farm product image from: $imageUrl');

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
            debugPrint('❌ Error loading product image: $error');
            return _buildImagePlaceholder();
          },
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit, color: Colors.white, size: 16),
                SizedBox(width: 6),
                SmartReTranslator(
                  text: 'Tap to change',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      color: Colors.grey.shade50,
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
              Icons.add_photo_alternate,
              size: 48,
              color: AppColors.primaryGreen,
            ),
          ),
          const SizedBox(height: 16),
          const SmartReTranslator(
            text: 'Tap to add product image',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          SmartReTranslator(
            text: 'Camera or Gallery',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
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
    List<TextInputFormatter>? inputFormatters,
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
          inputFormatters: inputFormatters,
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

  Widget _buildLabeledDropdown({
    required String label,
    required String? value,
    IconData? icon,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
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
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: Colors.white,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            prefixIcon: icon != null
                ? Icon(icon, color: AppColors.primaryGreen, size: 22)
                : null,
            filled: true,
            fillColor: Colors.white,
            contentPadding: EdgeInsets.symmetric(
              horizontal: icon != null ? 16 : 16,
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
          items: items,
          onChanged: _isLoading ? null : onChanged,
        ),
      ],
    );
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _varietyController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
