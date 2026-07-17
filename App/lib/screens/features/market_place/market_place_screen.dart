import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/market_place_services.dart';
import '../../../utils/constants.dart';
import 'product_details_screen.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  List<Map<String, dynamic>> _products = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String _searchQuery = '';
  String _selectedProductType = 'all';
  final TextEditingController _searchController = TextEditingController();
  Position? _currentPosition;
  double _maxDistance = 10; // Default 10km

  // Cache keys
  static const String _locationCacheKey = 'marketplace_location_cache';
  static const String _productsCacheKey = 'marketplace_products_cache';
  static const String _lastSyncKey = 'marketplace_last_sync';

  @override
  void initState() {
    super.initState();
    _loadCachedDataThenSync();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Load cached location and products first, then sync in background
  Future<void> _loadCachedDataThenSync() async {
    setState(() => _isLoading = true);

    // Load cached location and products in parallel
    await Future.wait([_loadCachedLocation(), _loadCachedProducts()]);

    // If we have cached data, display it immediately
    if (_products.isNotEmpty) {
      setState(() => _isLoading = false);
      debugPrint('✅ Loaded ${_products.length} cached products');
    }

    // Update location and products in background
    await _updateLocationAndProducts();
  }

  /// Load cached location
  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_locationCacheKey);

      if (locationJson != null) {
        final data = jsonDecode(locationJson) as Map<String, dynamic>;

        // Check if cache is not too old (1 hour)
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inHours < 1) {
          setState(() {
            _currentPosition = Position(
              latitude: data['latitude'],
              longitude: data['longitude'],
              timestamp: cachedTime,
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          });
          debugPrint('📍 Using cached location');
          return;
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached location: $e');
    }
  }

  /// Load cached products
  Future<void> _loadCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = prefs.getString(_productsCacheKey);

      if (productsJson != null) {
        final data = jsonDecode(productsJson) as Map<String, dynamic>;

        // Check if cache is not too old (30 minutes)
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inMinutes < 30) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data['products'] ?? []);
          });
          debugPrint('✅ Loaded ${_products.length} cached products');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached products: $e');
    }
  }

  /// Cache location
  Future<void> _cacheLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_locationCacheKey, jsonEncode(locationData));
      debugPrint('✅ Location cached');
    } catch (e) {
      debugPrint('❌ Error caching location: $e');
    }
  }

  /// Cache products
  Future<void> _cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsData = {
        'products': products,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_productsCacheKey, jsonEncode(productsData));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
      debugPrint('✅ Cached ${products.length} products');
    } catch (e) {
      debugPrint('❌ Error caching products: $e');
    }
  }

  /// Update location and products in background
  Future<void> _updateLocationAndProducts() async {
    try {
      // Update location
      await _getCurrentLocation(silent: true);

      // Load products
      if (_currentPosition != null) {
        await _loadMarketplaceProducts(silent: true);
      }
    } catch (e) {
      debugPrint('⚠️ Background update failed: $e');
    }
  }

  /// Get current location with caching
  Future<void> _getCurrentLocation({bool silent = false}) async {
    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isSyncing = true);
    }

    try {
      // Check location services
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

      // Check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied');
      }

      // ✅ Try to get last known position first (fast)
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null && _currentPosition == null) {
        setState(() {
          _currentPosition = position;
        });
        await _cacheLocation(position);

        // Load products with cached position
        if (!silent) {
          await _loadMarketplaceProducts();
        }
      }

      // ✅ Get accurate position (slower)
      final accuratePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = accuratePosition;
      });
      await _cacheLocation(accuratePosition);

      // Reload products if location changed significantly
      if (position == null ||
          (accuratePosition.latitude - position.latitude).abs() > 0.01 ||
          (accuratePosition.longitude - position.longitude).abs() > 0.01) {
        await _loadMarketplaceProducts(silent: silent);
      }
    } catch (e) {
      debugPrint('❌ Error getting location: $e');
      if (mounted && !silent) {
        _showSnackBar('Error getting location: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
    }
  }

  /// Load marketplace products
  Future<void> _loadMarketplaceProducts({bool silent = false}) async {
    if (_currentPosition == null) return;

    if (!silent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isSyncing = true);
    }

    try {
      final startTime = DateTime.now();

      final result = await MarketplaceService.getMarketplaceProducts(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        search: _searchQuery.isEmpty ? null : _searchQuery,
        maxDistance: _maxDistance,
        productType: _selectedProductType,
      );

      final duration = DateTime.now().difference(startTime);
      debugPrint('⏱️ Products loaded in ${duration.inMilliseconds}ms');

      if (result['success'] == true) {
        final newProducts = List<Map<String, dynamic>>.from(
          result['products'] ?? [],
        );

        setState(() {
          _products = newProducts;
        });

        // Cache products for next time
        await _cacheProducts(newProducts);
      } else {
        throw result['message'] ?? 'Failed to load products';
      }
    } catch (e) {
      debugPrint('❌ Error loading marketplace: $e');
      if (mounted && !silent) {
        _showSnackBar('Error loading products: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isSyncing = false;
        });
      }
    }
  }

  void _showSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: SmartReTranslator(
          text: message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: isError
            ? AppColors.errorColor
            : AppColors.successColor,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('❌ Error launching dialer: $e');
      if (mounted) {
        _showSnackBar('Could not launch phone dialer', isError: true);
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.filter_list,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: SmartReTranslator(
                    text: 'Filters',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SmartReTranslator(
              text: 'Maximum Distance',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            StatefulBuilder(
              builder: (context, setStateDialog) {
                return Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        activeTrackColor: AppColors.primaryGreen,
                        inactiveTrackColor: AppColors.primaryGreen.withOpacity(
                          0.2,
                        ),
                        thumbColor: AppColors.primaryGreen,
                        overlayColor: AppColors.primaryGreen.withOpacity(0.2),
                        valueIndicatorColor: AppColors.primaryGreen,
                        valueIndicatorTextStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Slider(
                        value: _maxDistance,
                        min: 5,
                        max: 100,
                        divisions: 19,
                        label: '${_maxDistance.round()} km',
                        onChanged: (value) {
                          setStateDialog(() {
                            _maxDistance = value;
                          });
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryGreen.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        '${_maxDistance.round()} km',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _loadMarketplaceProducts();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const SmartReTranslator(
                  text: 'Apply Filters',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showOnlineStatus: true, title: 'Marketplace'),
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Search and Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
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
                    onSubmitted: (_) => _loadMarketplaceProducts(),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search products...',
                      hintStyle: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.6),
                        fontSize: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: AppColors.textPrimary,
                        size: 22,
                      ),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_searchController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppColors.textPrimary,
                                size: 20,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _loadMarketplaceProducts();
                              },
                            ),
                          IconButton(
                            icon: Icon(
                              Icons.tune,
                              color: AppColors.textPrimary,
                              size: 22,
                            ),
                            onPressed: _showFilterBottomSheet,
                          ),
                        ],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Product Type Filter
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: MarketplaceService.getProductTypeOptions()
                        .map(
                          (type) => _buildProductTypeChip(
                            type['value']!,
                            type['label']!,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Products Count Header with Sync Indicator
          if (_products.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.shopping_bag,
                      size: 16,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: SmartReTranslator(
                      text: '${_products.length} products found',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'within ${_maxDistance.round()}km',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textPrimary.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (_isSyncing) ...[
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ],
              ),
            ),

          const SizedBox(height: 8),

          // Products List
          Expanded(
            child: _isLoading && _products.isEmpty
                ? _buildLoadingSkeleton()
                : _currentPosition == null
                ? _buildLocationError()
                : _products.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: () => _loadMarketplaceProducts(),
                    color: AppColors.primaryGreen,
                    backgroundColor: Colors.white,
                    child: Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount: _products.length,
                          itemBuilder: (context, index) {
                            return _buildProductCard(_products[index]);
                          },
                        ),

                        // Show subtle loading indicator at top if syncing
                        if (_isSyncing && _products.isNotEmpty)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              backgroundColor: Colors.transparent,
                              color: AppColors.primaryGreen,
                              minHeight: 2,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  /// ✅ Skeleton loader for initial load
  Widget _buildLoadingSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Image skeleton
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              const SizedBox(width: 12),
              // Text skeletons
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 16,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 14,
                      width: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 12,
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductTypeChip(String value, String label) {
    final isSelected = _selectedProductType == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedProductType = value;
            });
            _loadMarketplaceProducts();
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primaryGreen
                  : Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSelected)
                  const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                SmartReTranslator(
                  text: label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final distanceKm = product['distance_km'] as num? ?? 0;
    final imageUrl = product['image_url'];
    final productType = product['product_type'] ?? 'farm';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(
                  productId: product['product_id'],
                  productType: productType,
                ),
              ),
            );
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Stack(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primaryGreen.withOpacity(0.2),
                              width: 2,
                            ),
                          ),
                          child: imageUrl != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    '${AppConstants.baseUrl.replaceAll('/api', '')}$imageUrl',
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.agriculture,
                                        color: AppColors.primaryGreen
                                            .withOpacity(0.5),
                                        size: 36,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.agriculture,
                                  color: AppColors.primaryGreen.withOpacity(
                                    0.5,
                                  ),
                                  size: 36,
                                ),
                        ),
                        // Product Type Badge
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: productType == 'farm'
                                  ? AppColors.primaryGreen
                                  : Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              productType == 'farm'
                                  ? Icons.agriculture
                                  : Icons.store,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Product Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SmartReTranslator(
                        text: product['product_name'] ?? 'Unknown Product',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (product['variety'] != null &&
                          product['variety'].toString().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        SmartReTranslator(
                          text: product['variety'],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 8),

                      // Price
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.currency_rupee,
                              size: 14,
                              color: AppColors.primaryGreen,
                            ),
                            SmartReTranslator(
                              text: product['price_per_unit'].toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            ),
                            Text(
                              '/${product['unit']}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Seller & Distance
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline,
                            size: 14,
                            color: AppColors.textPrimary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              product['seller_name'] ?? 'Unknown Seller',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.location_on,
                            size: 14,
                            color: Color(0xFFFF9800),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            MarketplaceService.formatDistance(
                              distanceKm.toDouble(),
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFFF9800),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Contact Button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primaryGreen.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () {
                      final phone = product['seller_phone'];
                      if (phone != null) {
                        _makePhoneCall(phone);
                      } else {
                        _showSnackBar(
                          'Phone number not available',
                          isError: true,
                        );
                      }
                    },
                    icon: const Icon(
                      Icons.phone,
                      color: AppColors.primaryGreen,
                      size: 20,
                    ),
                    tooltip: 'Call Seller',
                    padding: const EdgeInsets.all(10),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_off,
                size: 60,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const SmartReTranslator(
              text: 'Location Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const SmartReTranslator(
              text: 'Please enable location services to browse marketplace',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _getCurrentLocation(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Retry',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
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
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 60,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 24),
            const SmartReTranslator(
              text: 'No products found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const SmartReTranslator(
              text: 'Try adjusting your search or filters',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _searchController.clear();
                  _searchQuery = '';
                  _selectedProductType = 'all';
                  _maxDistance = 10;
                });
                _loadMarketplaceProducts();
              },
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Reset Filters',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
