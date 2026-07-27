import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../src/services/market_place_services.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
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
  double _maxDistance = 10;

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  Position? _currentPosition;

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
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedDataThenSync() async {
    setState(() => _isLoading = true);

    await Future.wait([_loadCachedLocation(), _loadCachedProducts()]);

    if (_products.isNotEmpty && mounted) {
      setState(() => _isLoading = false);
    }

    await _updateLocationAndProducts();
  }

  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_locationCacheKey);

      if (locationJson != null) {
        final data = jsonDecode(locationJson) as Map<String, dynamic>;
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inHours < 1 && mounted) {
          setState(() {
            _currentPosition = Position(
              latitude: (data['latitude'] as num).toDouble(),
              longitude: (data['longitude'] as num).toDouble(),
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
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached location: $e');
    }
  }

  Future<void> _loadCachedProducts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = prefs.getString(_productsCacheKey);

      if (productsJson != null) {
        final data = jsonDecode(productsJson) as Map<String, dynamic>;
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inMinutes < 30 && mounted) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data['products'] ?? []);
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached products: $e');
    }
  }

  Future<void> _cacheLocation(Position position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationData = {
        'latitude': position.latitude,
        'longitude': position.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_locationCacheKey, jsonEncode(locationData));
    } catch (e) {
      debugPrint('❌ Error caching location: $e');
    }
  }

  Future<void> _cacheProducts(List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsData = {
        'products': products,
        'timestamp': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_productsCacheKey, jsonEncode(productsData));
      await prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ Error caching products: $e');
    }
  }

  Future<void> _updateLocationAndProducts() async {
    try {
      await _getCurrentLocation(silent: true);
      if (_currentPosition != null) {
        await _loadMarketplaceProducts(silent: true);
      }
    } catch (e) {
      debugPrint('⚠️ Background update failed: $e');
    }
  }

  Future<void> _getCurrentLocation({bool silent = false}) async {
    if (!mounted) return;

    setState(() {
      if (silent) {
        _isSyncing = true;
      } else {
        _isLoading = true;
      }
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled');
      }

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

      final lastKnown = await Geolocator.getLastKnownPosition();

      if (lastKnown != null && _currentPosition == null && mounted) {
        setState(() {
          _currentPosition = lastKnown;
        });
        await _cacheLocation(lastKnown);

        if (!silent) {
          await _loadMarketplaceProducts();
        }
      }

      final accuratePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      final oldPosition = _currentPosition;

      if (mounted) {
        setState(() {
          _currentPosition = accuratePosition;
        });
      }

      await _cacheLocation(accuratePosition);

      if (oldPosition == null ||
          (accuratePosition.latitude - oldPosition.latitude).abs() > 0.01 ||
          (accuratePosition.longitude - oldPosition.longitude).abs() > 0.01) {
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

  Future<void> _loadMarketplaceProducts({bool silent = false}) async {
    if (_currentPosition == null) return;

    if (mounted) {
      setState(() {
        if (silent) {
          _isSyncing = true;
        } else {
          _isLoading = true;
        }
      });
    }

    try {
      final result = await MarketplaceService.getMarketplaceProducts(
        latitude: _currentPosition!.latitude,
        longitude: _currentPosition!.longitude,
        search: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
        maxDistance: _maxDistance,
        productType: _selectedProductType,
      );

      if (result['success'] == true) {
        final newProducts = List<Map<String, dynamic>>.from(
          result['products'] ?? [],
        );

        if (mounted) {
          setState(() {
            _products = newProducts;
          });
        }

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

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      setState(() {
        _searchQuery = value.trim();
      });
      _loadMarketplaceProducts(silent: true);
    });
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    try {
      final launchUri = Uri(scheme: 'tel', path: phoneNumber);
      await launchUrl(launchUri);
    } catch (e) {
      debugPrint('❌ Error launching dialer: $e');
      if (mounted) {
        _showSnackBar('Could not launch phone dialer', isError: true);
      }
    }
  }

  void _showFilterBottomSheet() {
    double tempDistance = _maxDistance;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setBottomState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.96),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 52,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const SmartReTranslator(
                    text: 'Filter Marketplace',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.70),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SmartReTranslator(
                          text: 'Maximum Distance',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Slider(
                          value: tempDistance,
                          min: 5,
                          max: 100,
                          divisions: 19,
                          activeColor: AppColors.primaryGreen,
                          label: '${tempDistance.round()} km',
                          onChanged: (value) {
                            setBottomState(() {
                              tempDistance = value;
                            });
                          },
                        ),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tempDistance.round()} km',
                              style: const TextStyle(
                                color: AppColors.primaryGreen,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _maxDistance = 10;
                              _selectedProductType = 'all';
                              _searchController.clear();
                              _searchQuery = '';
                            });
                            _loadMarketplaceProducts();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            side: BorderSide(
                              color: AppColors.primaryGreen.withOpacity(0.3),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const SmartReTranslator(
                            text: 'Reset',
                            style: TextStyle(
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              _maxDistance = tempDistance;
                            });
                            _loadMarketplaceProducts();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const SmartReTranslator(
                            text: 'Apply',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  int _gridCount(double width) {
    if (width >= 1200) return 4;
    if (width >= 900) return 3;
    return 2;
  }

  double _imageRatioForProduct(Map<String, dynamic> product, int index) {
    final name = (product['product_name'] ?? '').toString().trim();
    final variety = (product['variety'] ?? '').toString().trim();
    final seller = (product['seller_name'] ?? '').toString().trim();

    final textWeight = name.length + variety.length + seller.length;
    const ratios = [0.72, 0.84, 0.95, 1.08, 1.2, 1.34];

    if (textWeight > 45) return ratios[index % 3];
    if (textWeight > 28) return ratios[(index + 2) % ratios.length];
    return ratios[(index + 4) % ratios.length];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(showOnlineStatus: true, title: 'Marketplace'),
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: false,
      body: Column(
        children: [
          _buildTopHeader(),
          Expanded(
            child: _isLoading && _products.isEmpty
                ? _buildLoadingGrid()
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
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final crossAxisCount = _gridCount(
                              constraints.maxWidth,
                            );

                            return MasonryGridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              physics: const AlwaysScrollableScrollPhysics(),
                              gridDelegate:
                                  SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                  ),
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              itemCount: _products.length,
                              itemBuilder: (context, index) {
                                final product = _products[index];
                                return _MarketplaceProductCard(
                                  product: product,
                                  imageAspectRatio: _imageRatioForProduct(
                                    product,
                                    index,
                                  ),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            ProductDetailsScreen(
                                              productId: product['product_id'],
                                              productType:
                                                  product['product_type'] ??
                                                  'farm',
                                            ),
                                      ),
                                    );
                                  },
                                  onCallTap: () {
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
                                );
                              },
                            );
                          },
                        ),
                        if (_isSyncing)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              color: AppColors.primaryGreen,
                              minHeight: 2,
                              backgroundColor: Colors.transparent,
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

  Widget _buildTopHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      color: Colors.transparent,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.88),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search,
                  color: AppColors.textPrimary,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) {
                      setState(() {});
                      _onSearchChanged(_searchController.text);
                    },
                    onSubmitted: (_) {
                      _searchDebounce?.cancel();
                      _searchQuery = _searchController.text.trim();
                      _loadMarketplaceProducts();
                    },
                    decoration: InputDecoration(
                      hintText: 'Search vegetables, fruits, seeds...',
                      hintStyle: TextStyle(
                        color: AppColors.textPrimary.withOpacity(0.55),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                    ),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    onPressed: () {
                      _searchDebounce?.cancel();
                      _searchController.clear();
                      setState(() {
                        _searchQuery = '';
                      });
                      _loadMarketplaceProducts();
                    },
                    icon: const Icon(Icons.close, size: 18),
                  ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _showFilterBottomSheet,
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: MarketplaceService.getProductTypeOptions()
                  .map(
                    (type) =>
                        _buildProductTypeChip(type['value']!, type['label']!),
                  )
                  .toList(),
            ),
          ),
          if (_products.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_bag_outlined,
                      color: AppColors.primaryGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SmartReTranslator(
                      text: '${_products.length} products found',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '${_maxDistance.round()} km',
                    style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.65),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isSyncing) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
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
          ],
        ],
      ),
    );
  }

  Widget _buildProductTypeChip(String value, String label) {
    final isSelected = _selectedProductType == value;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () {
          setState(() {
            _selectedProductType = value;
          });
          _loadMarketplaceProducts();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryGreen
                : Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? AppColors.primaryGreen
                  : Colors.grey.withOpacity(0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? AppColors.primaryGreen.withOpacity(0.18)
                    : Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              if (isSelected) ...[
                const Icon(Icons.check_circle, size: 16, color: Colors.white),
                const SizedBox(width: 6),
              ],
              SmartReTranslator(
                text: label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = _gridCount(constraints.maxWidth);
        final ratios = [0.72, 1.15, 0.9, 1.28, 0.82, 1.05];

        return MasonryGridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          gridDelegate: SliverSimpleGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
          ),
          mainAxisSpacing: 14,
          crossAxisSpacing: 14,
          itemCount: 6,
          itemBuilder: (context, index) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.82),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AspectRatio(
                    aspectRatio: ratios[index % ratios.length],
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[300]?.withOpacity(0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Container(
                          height: 14,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300]?.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300]?.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          height: 18,
                          width: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey[300]?.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[300]?.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(6),
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
      },
    );
  }

  Widget _buildLocationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_off_rounded,
                size: 58,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 22),
            const SmartReTranslator(
              text: 'Location Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const SmartReTranslator(
              text:
                  'Please enable location services to browse nearby products.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 22),
            ElevatedButton.icon(
              onPressed: () => _getCurrentLocation(),
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Retry',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
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
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.88),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 58,
                color: AppColors.primaryGreen,
              ),
            ),
            const SizedBox(height: 22),
            const SmartReTranslator(
              text: 'No products found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            const SmartReTranslator(
              text: 'Try changing search text, type, or distance filter.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 22),
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
              icon: const Icon(Icons.restart_alt, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Reset Filters',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final double imageAspectRatio;
  final VoidCallback onTap;
  final VoidCallback onCallTap;

  const _MarketplaceProductCard({
    required this.product,
    required this.imageAspectRatio,
    required this.onTap,
    required this.onCallTap,
  });

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = product['image_url'];
    final productType = _safeText(product['product_type'], fallback: 'farm');
    final distanceKm = (product['distance_km'] as num?)?.toDouble() ?? 0;
    final isAvailable = product['is_available'] == true;
    final productName = _safeText(
      product['product_name'],
      fallback: 'Unknown Product',
    );
    final sellerName = _safeText(
      product['seller_name'],
      fallback: 'Unknown Seller',
    );
    final variety = _safeText(product['variety']);
    final unit = _safeText(product['unit'], fallback: 'unit');
    final price = _safeText(product['price_per_unit'], fallback: '--');

    final hasValidImage =
        imageUrl != null &&
        imageUrl.toString().trim().isNotEmpty &&
        imageUrl.toString().trim() != 'no-image';

    final typeColor = productType == 'farm'
        ? AppColors.primaryGreen
        : Colors.blue;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.14),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              AspectRatio(
                aspectRatio: imageAspectRatio,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        child: hasValidImage
                            ? Image.network(
                                '${AppConstants.baseUrl.replaceAll('/api', '')}$imageUrl',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(
                                      0xFFF0F3F4,
                                    ).withOpacity(0.82),
                                    child: const Center(
                                      child: Icon(
                                        Icons.image_not_supported_outlined,
                                        color: AppColors.primaryGreen,
                                        size: 30,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Container(
                                color: const Color(
                                  0xFFF0F3F4,
                                ).withOpacity(0.82),
                                child: const Center(
                                  child: Icon(
                                    Icons.agriculture_rounded,
                                    color: AppColors.primaryGreen,
                                    size: 30,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 90),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: typeColor,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          productType == 'farm' ? 'Farm' : 'Retail',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Material(
                        color: Colors.white.withOpacity(0.94),
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          onTap: onCallTap,
                          borderRadius: BorderRadius.circular(12),
                          child: const SizedBox(
                            width: 34,
                            height: 34,
                            child: Icon(
                              Icons.call_rounded,
                              size: 17,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 10,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 100),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.green.withOpacity(0.95)
                              : Colors.red.withOpacity(0.95),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          isAvailable ? 'In Stock' : 'Out of Stock',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      productName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    if (variety.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        variety,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textPrimary.withOpacity(0.70),
                          fontWeight: FontWeight.w500,
                          height: 1.2,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 3),
                          child: Text(
                            '₹',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryGreen,
                              height: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: price,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryGreen,
                                    height: 1,
                                  ),
                                ),
                                TextSpan(
                                  text: '/$unit',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: AppColors.textPrimary.withOpacity(
                                      0.65,
                                    ),
                                    fontWeight: FontWeight.w600,
                                    height: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.store_mall_directory_outlined,
                          size: 12,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            sellerName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textPrimary.withOpacity(0.75),
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            MarketplaceService.formatDistance(distanceKm),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: Colors.orange,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
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
}
