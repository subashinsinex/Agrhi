import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../../utils/colors.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import '../../../src/services/market_place_services.dart';
import '../../../utils/constants.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String productType; // 'farm' or 'retail'

  const ProductDetailsScreen({
    super.key,
    required this.productId,
    required this.productType,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _product;
  bool _isLoading = false;
  bool _isLoadingAddress = false;
  Position? _currentPosition;
  double? _distanceToShop;
  String? _formattedAddress;

  // Cache keys
  static const String _locationCacheKey = 'product_detail_location_cache';
  static const String _addressCachePrefix = 'geocode_cache_';

  @override
  void initState() {
    super.initState();
    _loadCachedDataThenFetch();
  }

  /// ✅ Load cached location first, then fetch fresh data
  Future<void> _loadCachedDataThenFetch() async {
    // Load cached location
    await _loadCachedLocation();

    // Load product details (this will use cached location)
    await _loadProductDetails();

    // Update location in background
    _updateLocationInBackground();
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
          debugPrint('📍 Using cached location for product details');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached location: $e');
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
      debugPrint('✅ Location cached for product details');
    } catch (e) {
      debugPrint('❌ Error caching location: $e');
    }
  }

  /// Update location in background
  Future<void> _updateLocationInBackground() async {
    try {
      // ✅ Try getLastKnownPosition first (fast)
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null && _currentPosition == null) {
        setState(() {
          _currentPosition = position;
        });
        await _cacheLocation(position);
        _calculateDistance();
      }

      // ✅ Get accurate position with timeout
      final accuratePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium, // Changed from high
        timeLimit: Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = accuratePosition;
      });
      await _cacheLocation(accuratePosition);
      _calculateDistance();
    } catch (e) {
      debugPrint('⚠️ Background location update failed: $e');
      // Don't show error - using cached location is fine
    }
  }

  /// Original getCurrentLocation (now just calls background update)
  Future<void> _getCurrentLocation() async {
    await _updateLocationInBackground();
  }

  void _calculateDistance() {
    if (_currentPosition == null || _product == null) return;

    final shopLat = _product!['shop_latitude'];
    final shopLng = _product!['shop_longitude'];

    if (shopLat != null && shopLng != null) {
      final distance = Geolocator.distanceBetween(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        shopLat is String ? double.parse(shopLat) : shopLat.toDouble(),
        shopLng is String ? double.parse(shopLng) : shopLng.toDouble(),
      );

      setState(() {
        _distanceToShop = distance / 1000; // Convert to km
      });
    }
  }

  /// ✅ Optimized geocoding with caching
  Future<void> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    // Create cache key from coordinates
    final cacheKey =
        '$_addressCachePrefix${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';

    // Check cache first
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAddress = prefs.getString(cacheKey);

      if (cachedAddress != null) {
        final data = jsonDecode(cachedAddress) as Map<String, dynamic>;
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        // Cache addresses for 7 days
        if (age.inDays < 7) {
          setState(() {
            _formattedAddress = data['address'];
          });
          debugPrint('✅ Using cached address');
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached address: $e');
    }

    // Fetch fresh address
    setState(() => _isLoadingAddress = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        // Build formatted address
        List<String> addressParts = [];

        if (place.street != null && place.street!.isNotEmpty) {
          addressParts.add(place.street!);
        }
        if (place.subLocality != null && place.subLocality!.isNotEmpty) {
          addressParts.add(place.subLocality!);
        }
        if (place.locality != null && place.locality!.isNotEmpty) {
          addressParts.add(place.locality!);
        }
        if (place.subAdministrativeArea != null &&
            place.subAdministrativeArea!.isNotEmpty) {
          addressParts.add(place.subAdministrativeArea!);
        }
        if (place.administrativeArea != null &&
            place.administrativeArea!.isNotEmpty) {
          addressParts.add(place.administrativeArea!);
        }
        if (place.postalCode != null && place.postalCode!.isNotEmpty) {
          addressParts.add(place.postalCode!);
        }

        final formattedAddress = addressParts.join(', ');

        setState(() {
          _formattedAddress = formattedAddress;
        });

        // Cache the address
        try {
          final prefs = await SharedPreferences.getInstance();
          final addressData = {
            'address': formattedAddress,
            'timestamp': DateTime.now().toIso8601String(),
          };
          await prefs.setString(cacheKey, jsonEncode(addressData));
          debugPrint('✅ Address cached: $formattedAddress');
        } catch (e) {
          debugPrint('⚠️ Error caching address: $e');
        }

        debugPrint('✅ Address: $_formattedAddress');
      }
    } catch (e) {
      debugPrint('❌ Error getting address: $e');
      setState(() {
        _formattedAddress = 'Address not available';
      });
    } finally {
      setState(() => _isLoadingAddress = false);
    }
  }

  Future<void> _loadProductDetails() async {
    setState(() => _isLoading = true);

    try {
      final product = await MarketplaceService.getProductDetails(
        productId: widget.productId,
        productType: widget.productType,
      );

      if (product != null) {
        setState(() {
          _product = product;
        });
        _calculateDistance();

        // For farmers (farm products), always use lat/long to get address
        // For retailers, use seller_address if available, otherwise use lat/long
        final shopLat = product['shop_latitude'];
        final shopLng = product['shop_longitude'];

        if (widget.productType == 'farm') {
          // Farmer: Always convert lat/long to address
          if (shopLat != null && shopLng != null) {
            final lat = shopLat is String
                ? double.parse(shopLat)
                : shopLat.toDouble();
            final lng = shopLng is String
                ? double.parse(shopLng)
                : shopLng.toDouble();
            await _getAddressFromCoordinates(lat, lng);
          }
        } else {
          // Retailer: Use seller_address if available, otherwise convert lat/long
          final sellerAddress = product['seller_address'];
          if (sellerAddress == null ||
              sellerAddress.toString().trim().isEmpty) {
            if (shopLat != null && shopLng != null) {
              final lat = shopLat is String
                  ? double.parse(shopLat)
                  : shopLat.toDouble();
              final lng = shopLng is String
                  ? double.parse(shopLng)
                  : shopLng.toDouble();
              await _getAddressFromCoordinates(lat, lng);
            }
          }
        }
      } else {
        if (mounted) {
          _showSnackBar('Product not found', isError: true);
          Navigator.pop(context);
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading product details: $e');
      if (mounted) {
        _showSnackBar('Error loading product: $e', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
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
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      _showSnackBar('Could not launch phone dialer', isError: true);
    }
  }

  Future<void> _openMaps() async {
    if (_product == null) return;

    final shopLat = _product!['shop_latitude'];
    final shopLng = _product!['shop_longitude'];

    if (shopLat == null || shopLng == null) {
      _showSnackBar('Location not available', isError: true);
      return;
    }

    final lat = shopLat is String ? double.parse(shopLat) : shopLat.toDouble();
    final lng = shopLng is String ? double.parse(shopLng) : shopLng.toDouble();

    final googleMapsUri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );

    try {
      if (await canLaunchUrl(googleMapsUri)) {
        await launchUrl(googleMapsUri, mode: LaunchMode.externalApplication);
      } else {
        _showSnackBar('Could not open maps', isError: true);
      }
    } catch (e) {
      debugPrint('❌ Error opening maps: $e');
      _showSnackBar('Error opening maps', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showOnlineStatus: true,
        title: 'Product Details',
      ),
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primaryGreen),
            )
          : _product == null
          ? _buildErrorState()
          : Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductImage(),
                        _buildProductInfo(),
                        const SizedBox(height: 12),
                        _buildSellerInfo(),
                        const SizedBox(height: 12),
                        _buildLocationInfo(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildProductImage() {
    final imageUrl = _product!['image_url'];

    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(color: Colors.grey[100]),
      child: Stack(
        children: [
          // Product Image
          imageUrl != null
              ? Image.network(
                  '${AppConstants.baseUrl.replaceAll('/api', '')}$imageUrl',
                  width: double.infinity,
                  height: 320,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.image_not_supported,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Image not available',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.agriculture,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No image',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),

          // Gradient Overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
            ),
          ),

          // Product Type Badge (Farm Product / Retail Product)
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: widget.productType == 'farm'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.productType == 'farm'
                        ? Icons.agriculture
                        : Icons.store,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  SmartReTranslator(
                    text: widget.productType == 'farm'
                        ? 'Farm Product'
                        : 'Retail Product',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Availability Status (In Stock / Out of Stock)
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _product!['is_available'] == true
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _product!['is_available'] == true
                        ? Icons.check_circle
                        : Icons.cancel,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 4),
                  SmartReTranslator(
                    text: _product!['is_available'] == true
                        ? 'In Stock'
                        : 'Out of Stock',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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

  Widget _buildProductInfo() {
    final pricePerUnit = _product!['price_per_unit'];
    final unit = _product!['unit'];
    final quantityAvailable = _product!['quantity_available'];
    final variety = _product!['variety'];
    final description = _product!['description'];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Product Name
          SmartReTranslator(
            text: _product!['product_name'] ?? 'Unknown Product',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),

          // Variety
          if (variety != null && variety.toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.local_florist,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  SmartReTranslator(
                    text: variety,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Price and Stock Row
          Row(
            children: [
              // Price Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen,
                        AppColors.primaryGreen.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.currency_rupee,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: SmartReTranslator(
                              text: '$pricePerUnit',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'per $unit',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Stock Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.2),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Available Stock',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.inventory_2,
                            color: Colors.blue[700],
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$quantityAvailable',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        unit ?? '',
                        style: TextStyle(
                          color: Colors.blue[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Description
          if (description != null && description.toString().isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: Colors.grey[700],
                ),
                const SizedBox(width: 8),
                const SmartReTranslator(
                  text: 'Description',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SmartReTranslator(
              text: description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    final sellerName = _product!['seller_name'] ?? 'Unknown Seller';
    final sellerPic = _product!['seller_pic'];
    final sellerPhone = _product!['seller_phone'];
    final category = _product!['category']; // Get category for retail products

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
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
                  Icons.store,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SmartReTranslator(
                  text: 'Seller Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Seller Picture
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGreen, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryGreen.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: sellerPic != null && sellerPic != 'no-image'
                    ? ClipOval(
                        child: Image.network(
                          '${AppConstants.baseUrl.replaceAll('/api', '')}$sellerPic',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person,
                              size: 35,
                              color: Colors.grey[400],
                            );
                          },
                        ),
                      )
                    : Icon(Icons.person, size: 35, color: Colors.grey[400]),
              ),
              const SizedBox(width: 16),

              // Seller Details (Name + Category)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Show category for retail products
                    if (widget.productType == 'retail' &&
                        category != null &&
                        category.toString().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.category,
                              size: 12,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            SmartReTranslator(
                              text: category.toString().toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (sellerPhone != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            sellerPhone,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Call Button
              if (sellerPhone != null)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: () => _makePhoneCall(sellerPhone),
                    icon: const Icon(
                      Icons.phone,
                      color: Colors.white,
                      size: 22,
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationInfo() {
    final shopLat = _product!['shop_latitude'];
    final shopLng = _product!['shop_longitude'];
    final sellerAddress = _product!['seller_address'];

    // For farmers: Always use reverse geocoded address from lat/long
    // For retailers: Use seller_address if available, otherwise use reverse geocoded address
    String? displayAddress;
    if (widget.productType == 'farm') {
      displayAddress = _formattedAddress;
    } else {
      displayAddress =
          (sellerAddress != null && sellerAddress.toString().trim().isNotEmpty)
          ? sellerAddress.toString()
          : _formattedAddress;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on,
                  color: Colors.orange[700],
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SmartReTranslator(
                  text: 'Location Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Distance Badge
          if (_distanceToShop != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[400]!, Colors.orange[600]!],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    MarketplaceService.formatDistance(_distanceToShop!),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

          // Address with lat/long display
          if (displayAddress != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.place_outlined,
                        size: 20,
                        color: Colors.grey[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _isLoadingAddress
                            ? Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Loading address...',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                displayAddress,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ],
                  ),
                  // Show lat/long coordinates
                  if (shopLat != null && shopLng != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.my_location,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Lat: ${shopLat.toString().substring(0, shopLat.toString().length > 10 ? 10 : shopLat.toString().length)}, '
                            'Long: ${shopLng.toString().substring(0, shopLng.toString().length > 10 ? 10 : shopLng.toString().length)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ] else if (_isLoadingAddress) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Fetching address from location...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Open in Maps Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: shopLat != null && shopLng != null ? _openMaps : null,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const SmartReTranslator(
                text: 'Open in Maps',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryGreen,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 100, color: Colors.grey[300]),
            const SizedBox(height: 24),
            const SmartReTranslator(
              text: 'Product not found',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            const SmartReTranslator(
              text:
                  'This product may have been removed or is no longer available',
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Go Back',
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
