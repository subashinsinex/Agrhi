import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/retail_service.dart';
import '../../../src/services/language_service.dart';
import 'add_edit_product_screen.dart';
import '../../../utils/constants.dart';

class ManageProductsScreen extends StatefulWidget {
  final String retailerId;
  final String? shopName;

  const ManageProductsScreen({
    super.key,
    required this.retailerId,
    this.shopName,
  });

  @override
  State<ManageProductsScreen> createState() => _ManageProductsScreenState();
}

class _ManageProductsScreenState extends State<ManageProductsScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // ✅ Cache for translated product names
  final Map<String, String> _translatedProductNames = {};
  final Map<String, String> _translatedBrands = {};

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);

    try {
      final products = await RetailService.getProductsByRetailer(
        widget.retailerId,
      );

      setState(() {
        _products = products;
      });

      // ✅ Preload translations for current language
      _preloadProductTranslations();
    } catch (e) {
      debugPrint('Error loading products: $e');
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

  // ✅ Preload all product name translations
  Future<void> _preloadProductTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    // Only translate if not English
    if (languageService.currentLocale.languageCode == 'en') {
      return;
    }

    // Clear existing translations
    _translatedProductNames.clear();
    _translatedBrands.clear();

    for (var product in _products) {
      final productName = product['product_name'] ?? '';
      final brand = product['brand'] ?? '';

      if (productName.isNotEmpty &&
          !_translatedProductNames.containsKey(productName)) {
        try {
          final translated = await languageService.translate(productName);
          _translatedProductNames[productName] = translated;
        } catch (e) {
          debugPrint('Translation error for $productName: $e');
        }
      }

      if (brand.isNotEmpty && !_translatedBrands.containsKey(brand)) {
        try {
          final translated = await languageService.translate(brand);
          _translatedBrands[brand] = translated;
        } catch (e) {
          debugPrint('Translation error for $brand: $e');
        }
      }
    }

    if (mounted) {
      setState(() {}); // Refresh UI with translations
    }
  }

  // ✅ Multilingual search using cached translations
  List<Map<String, dynamic>> get _filteredProducts {
    if (_searchQuery.isEmpty) return _products;

    final query = _searchQuery.toLowerCase().trim();

    return _products.where((product) {
      final productName = (product['product_name'] ?? '').toLowerCase();
      final brand = (product['brand'] ?? '').toLowerCase();

      // Get translated versions
      final translatedProductName =
          (_translatedProductNames[product['product_name']] ?? '')
              .toLowerCase();
      final translatedBrand = (_translatedBrands[product['brand']] ?? '')
          .toLowerCase();

      // Search in both original English and translated text
      return productName.contains(query) ||
          brand.contains(query) ||
          translatedProductName.contains(query) ||
          translatedBrand.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        showOnlineStatus: true,
        title: widget.shopName ?? 'Manage Products',
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          // ✅ Header section with count and add button
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.primaryGreen.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                // Count and Add button row
                Row(
                  children: [
                    // Product count
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SmartReTranslator(
                                text: 'Products',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${_filteredProducts.length} ${_filteredProducts.length == 1 ? 'item' : 'items'}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Add button
                    Material(
                      color: AppColors.primaryGreen,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddEditProductScreen(
                                retailerId: widget.retailerId,
                              ),
                            ),
                          );

                          if (result == true) {
                            _loadProducts();
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Colors.white,
                                size: 20,
                              ),
                              SizedBox(width: 6),
                              SmartReTranslator(
                                text: 'Add',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Search bar
                ListenableBuilder(
                  listenable: _searchController,
                  builder: (context, _) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search products...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: AppColors.primaryGreen,
                            size: 22,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // ✅ Products list
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryGreen,
                    ),
                  )
                : _products.isEmpty
                ? _buildEmptyState()
                : _filteredProducts.isEmpty
                ? _buildNoResults()
                : RefreshIndicator(
                    onRefresh: _loadProducts,
                    color: AppColors.primaryGreen,
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
                      itemCount: _filteredProducts.length,
                      itemBuilder: (context, index) {
                        return _buildProductCard(_filteredProducts[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: _products.isEmpty
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddEditProductScreen(retailerId: widget.retailerId),
                  ),
                );

                if (result == true) {
                  _loadProducts();
                }
              },
              backgroundColor: AppColors.primaryGreen,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Add Product',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inventory_2_outlined,
                size: 80,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const SmartReTranslator(
              text: 'No products yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SmartReTranslator(
                text:
                    'Start building your inventory by adding your first product',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          SmartReTranslator(
            text: 'No products found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          SmartReTranslator(
            text: 'Try searching with different keywords',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    // ✅ Safely parse stock_qty as a number
    final stockQtyRaw = product['stock_qty'];
    final stockQty = stockQtyRaw is String
        ? double.tryParse(stockQtyRaw)?.toInt() ?? 0
        : (stockQtyRaw is num ? stockQtyRaw.toInt() : 0);

    final isLowStock = stockQty < 10;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFE8F5E9), // Light green
            const Color(0xFFF1F8E9), // Very light green-yellow
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryGreen.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddEditProductScreen(
                  retailerId: widget.retailerId,
                  product: product,
                ),
              ),
            );

            if (result == true) {
              _loadProducts();
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // ✅ Product Image with green border
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                  child: product['product_image_url'] != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(
                            '${AppConstants.baseUrl.replaceAll('/api', '')}${product['product_image_url']}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Icon(
                                Icons.broken_image_outlined,
                                color: Colors.grey.shade400,
                                size: 32,
                              );
                            },
                          ),
                        )
                      : Icon(
                          Icons.inventory_2_outlined,
                          color: AppColors.primaryGreen.withOpacity(0.5),
                          size: 32,
                        ),
                ),
                const SizedBox(width: 12),

                // ✅ Product Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: product['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product['brand'] != null) ...[
                        const SizedBox(height: 4),
                        SmartReTranslator(
                          text: product['brand'],
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      // ✅ Price and Stock Row
                      Row(
                        children: [
                          // Price
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.currency_rupee,
                                size: 14,
                                color: AppColors.primaryGreen,
                              ),
                              SmartReTranslator(
                                text: '${product['price']}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryGreen,
                                ),
                              ),
                              Text(
                                ' /${product['unit']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),

                          // Stock indicator
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isLowStock
                                  ? Colors.orange.withOpacity(0.2)
                                  : Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isLowStock
                                      ? Icons.warning_amber
                                      : Icons.check_circle_outline,
                                  size: 12,
                                  color: isLowStock
                                      ? Colors.orange[800]
                                      : Colors.blue[800],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$stockQty ${product['unit']}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isLowStock
                                        ? Colors.orange[800]
                                        : Colors.blue[800],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ✅ Arrow icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.primaryGreen.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
