import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/retail_service.dart';
import '../../../utils/constants.dart';

class AddEditProductScreen extends StatefulWidget {
  final String retailerId;
  final Map<String, dynamic>? product;

  const AddEditProductScreen({
    super.key,
    required this.retailerId,
    this.product,
  });

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _brandController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockQtyController = TextEditingController();

  // ✅ Create ImagePicker instance once (reuse it)
  final ImagePicker _picker = ImagePicker();

  String? _category = 'fertilizer';
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
    _brandController.text = product['brand'] ?? '';
    _descriptionController.text = product['description'] ?? '';
    _priceController.text = product['price']?.toString() ?? '';
    _stockQtyController.text = product['stock_qty']?.toString() ?? '';
    _category = product['category'] ?? 'fertilizer';
    _unit = product['unit'] ?? 'kg';
    _productImageUrl =
        product['product_image_url'] ??
        product['image_url'] ??
        product['product_image'];

    debugPrint('📥 Loading product data: $_productId');
    debugPrint('✅ Product image URL: $_productImageUrl');
  }

  // ✅ Optimized image picking with direct camera launch
  Future<void> _pickImageFromCamera() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.rear, // ✅ Specify rear camera
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

  // ✅ Show optimized image picker dialog
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
                Navigator.pop(context); // ✅ Close dialog first
                // ✅ Open camera immediately after dialog closes
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
                Navigator.pop(context); // ✅ Close dialog first
                // ✅ Open gallery immediately after dialog closes
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

  // ✅ Two-step product creation: 1) Create product, 2) Upload image
  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final productData = {
        'retailer_id': widget.retailerId,
        'category': _category,
        'product_name': _productNameController.text.trim(),
        'brand': _brandController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text.trim()),
        'unit': _unit,
        'stock_qty': double.parse(_stockQtyController.text.trim()),
      };

      if (_isEditing && _productId != null) {
        // ✅ Editing existing product
        debugPrint('🔄 Updating existing product: $_productId');
        await RetailService.updateProduct(_productId!, productData);

        // ✅ Upload new image only if selected
        if (_selectedImage != null) {
          debugPrint('📤 Uploading new product image...');
          await RetailService.uploadProductImage(_productId!, _selectedImage!);
        }
      } else {
        // ✅ Creating new product - TWO SEQUENTIAL API CALLS
        debugPrint('➕ Creating new product with two-step process...');

        // ✅ STEP 1: Create product and get product_id
        debugPrint('📤 Step 1: Creating product details...');
        final response = await RetailService.createProduct(productData);
        final newProductId = response['product_id'];

        if (newProductId == null) {
          throw Exception('Failed to create product: No product_id returned');
        }

        debugPrint('✅ Product created with ID: $newProductId');

        setState(() {
          _productId = newProductId;
          _isEditing = true;
        });

        // ✅ STEP 2: Upload product image using the returned product_id
        if (_selectedImage != null) {
          debugPrint(
            '📤 Step 2: Uploading product image for product: $newProductId',
          );
          await RetailService.uploadProductImage(newProductId, _selectedImage!);
          debugPrint('✅ Product image uploaded successfully');
        } else {
          debugPrint('⚠️ No image to upload');
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(
              text: _isEditing
                  ? 'Product updated successfully'
                  : 'Product created successfully',
            ),
            backgroundColor: AppColors.successColor,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('❌ Error saving product: $e');
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
        title: _isEditing ? 'Edit Product' : 'Add Product',
      ),
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
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
                      // Product Image Section
                      _buildSectionHeader(
                        icon: Icons.image,
                        title: 'Product Image',
                        subtitle: 'Add a clear photo of your product',
                      ),
                      const SizedBox(height: 16),
                      _buildImagePicker(),

                      const SizedBox(height: 32),

                      // Basic Information
                      _buildSectionHeader(
                        icon: Icons.inventory_2,
                        title: 'Basic Information',
                        subtitle: 'Enter product details',
                      ),
                      const SizedBox(height: 16),

                      _buildLabeledTextField(
                        label: 'Product Name',
                        controller: _productNameController,
                        icon: Icons.shopping_bag_outlined,
                        hint: 'Enter product name',
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
                        label: 'Brand',
                        controller: _brandController,
                        icon: Icons.label_outlined,
                        hint: 'Enter brand name',
                        isRequired: false,
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledDropdown(
                        label: 'Category',
                        value: _category,
                        icon: Icons.category_outlined,
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
                            value: 'pesticides',
                            child: SmartReTranslator(text: 'Pesticides'),
                          ),
                          DropdownMenuItem(
                            value: 'fruits and vegetables',
                            child: SmartReTranslator(text: 'Fruits and Vegetables'),
                          ),
                          DropdownMenuItem(
                            value: 'dairy products',
                            child: SmartReTranslator(text: 'Dairy Products'),
                          ),
                          DropdownMenuItem(
                            value: 'grains and pulses',
                            child: SmartReTranslator(text: 'Grains and Pulses'),
                          ),
                          DropdownMenuItem(
                            value: 'other',
                            child: SmartReTranslator(text: 'Other'),
                          ),
                        ],
                        onChanged: (value) => setState(() => _category = value),
                      ),
                      const SizedBox(height: 20),

                      _buildLabeledTextField(
                        label: 'Description',
                        controller: _descriptionController,
                        icon: Icons.description_outlined,
                        hint: 'Enter product description (Optional)',
                        maxLines: 3,
                        isRequired: false,
                      ),

                      const SizedBox(height: 32),

                      // Pricing & Stock
                      _buildSectionHeader(
                        icon: Icons.attach_money,
                        title: 'Pricing & Stock',
                        subtitle: 'Set price and availability',
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
                                  value: 'liter',
                                  child: Text('liter'),
                                ),
                                DropdownMenuItem(
                                  value: 'piece',
                                  child: Text('piece'),
                                ),
                                DropdownMenuItem(
                                  value: 'bag',
                                  child: Text('bag'),
                                ),
                                DropdownMenuItem(
                                  value: 'box',
                                  child: Text('box'),
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
                        label: 'Stock Quantity',
                        controller: _stockQtyController,
                        icon: Icons.inventory_outlined,
                        hint: 'Enter available stock',
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
                            return 'Stock quantity is required';
                          }
                          final qty = double.tryParse(value);
                          if (qty == null || qty < 0) {
                            return 'Enter valid quantity';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 40),

                      // Save Button
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
      onTap: _isLoading
          ? null
          : _showImageSourceDialog, // ✅ Disable during loading
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

    debugPrint('🖼️ Loading product image from: $imageUrl');

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
    _brandController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockQtyController.dispose();
    super.dispose();
  }
}
