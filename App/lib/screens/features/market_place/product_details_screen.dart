import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../src/services/market_place_services.dart';
import '../../../utils/colors.dart';
import '../../../utils/constants.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';

class ProductDetailsScreen extends StatefulWidget {
  final String productId;
  final String productType;

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

  static const String _locationCacheKey = 'product_detail_location_cache';
  static const String _addressCachePrefix = 'geocode_cache_';

  @override
  void initState() {
    super.initState();
    _loadCachedDataThenFetch();
  }

  Future<void> _loadCachedDataThenFetch() async {
    await _loadCachedLocation();
    await _loadProductDetails();
    _updateLocationInBackground();
  }

  Future<void> _loadCachedLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final locationJson = prefs.getString(_locationCacheKey);

      if (locationJson != null) {
        final data = jsonDecode(locationJson) as Map<String, dynamic>;
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
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading cached location: $e');
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

  Future<void> _updateLocationInBackground() async {
    try {
      Position? position = await Geolocator.getLastKnownPosition();

      if (position != null && _currentPosition == null) {
        setState(() {
          _currentPosition = position;
        });
        await _cacheLocation(position);
        _calculateDistance();
      }

      final accuratePosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      );

      setState(() {
        _currentPosition = accuratePosition;
      });
      await _cacheLocation(accuratePosition);
      _calculateDistance();
    } catch (e) {
      debugPrint('⚠️ Background location update failed: $e');
    }
  }

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
        _distanceToShop = distance / 1000;
      });
    }
  }

  Future<void> _getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    final cacheKey =
        '$_addressCachePrefix${latitude.toStringAsFixed(4)}_${longitude.toStringAsFixed(4)}';

    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedAddress = prefs.getString(cacheKey);

      if (cachedAddress != null) {
        final data = jsonDecode(cachedAddress) as Map<String, dynamic>;
        final cachedTime = DateTime.parse(data['timestamp']);
        final age = DateTime.now().difference(cachedTime);

        if (age.inDays < 7) {
          setState(() {
            _formattedAddress = data['address'];
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error loading cached address: $e');
    }

    setState(() => _isLoadingAddress = true);

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
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

        try {
          final prefs = await SharedPreferences.getInstance();
          final addressData = {
            'address': formattedAddress,
            'timestamp': DateTime.now().toIso8601String(),
          };
          await prefs.setString(cacheKey, jsonEncode(addressData));
        } catch (e) {
          debugPrint('⚠️ Error caching address: $e');
        }
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

        final shopLat = product['shop_latitude'];
        final shopLng = product['shop_longitude'];

        if (widget.productType == 'farm') {
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
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
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

  String _safeText(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  String _shortCoordinate(dynamic value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return '--';
    return text.length > 10 ? '${text.substring(0, 10)}...' : text;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(
        showOnlineStatus: true,
        title: 'Product Details',
      ),
      backgroundColor: Colors.transparent,
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
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildProductImage(),
                        _buildProductInfo(),
                        const SizedBox(height: 12),
                        _buildSellerInfo(),
                        const SizedBox(height: 12),
                        _buildLocationInfo(),
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
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 100,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Color(0xB3000000), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: widget.productType == 'farm'
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF2196F3),
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                  Flexible(
                    child: SmartReTranslator(
                      text: widget.productType == 'farm'
                          ? 'Farm Product'
                          : 'Retail Product',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _product!['is_available'] == true
                    ? Colors.green
                    : Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x4D000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
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
                  Flexible(
                    child: SmartReTranslator(
                      text: _product!['is_available'] == true
                          ? 'In Stock'
                          : 'Out of Stock',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
    final unit = _safeText(_product!['unit']);
    final quantityAvailable = _product!['quantity_available'];
    final variety = _safeText(_product!['variety']);
    final description = _safeText(_product!['description']);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SmartReTranslator(
            text: _safeText(
              _product!['product_name'],
              fallback: 'Unknown Product',
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              height: 1.2,
            ),
          ),
          if (variety.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF7EE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.local_florist,
                    size: 14,
                    color: AppColors.primaryGreen,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: SmartReTranslator(
                      text: variety,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Price',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F7FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x332196F3),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Available Stock',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Color(0xFF123A73),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.inventory_2,
                            color: Color(0xFF1976D2),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$quantityAvailable',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF123A73),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Text(
                        unit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF1976D2),
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
          if (description.isNotEmpty) ...[
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
                const Expanded(
                  child: SmartReTranslator(
                    text: 'Description',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SmartReTranslator(
              text: description,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
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
    final sellerName = _safeText(
      _product!['seller_name'],
      fallback: 'Unknown Seller',
    );
    final sellerPic = _product!['seller_pic'];
    final sellerPhone = _safeText(_product!['seller_phone']);
    final category = _safeText(_product!['category']);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                  color: const Color(0xFFEAF7EE),
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.primaryGreen, width: 3),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sellerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (widget.productType == 'retail' &&
                        category.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        constraints: const BoxConstraints(maxWidth: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.category,
                              size: 12,
                              color: Color(0xFF1976D2),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: SmartReTranslator(
                                text: category.toUpperCase(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1976D2),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (sellerPhone.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.phone_outlined,
                            size: 15,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              sellerPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (sellerPhone.isNotEmpty)
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.primaryGreen,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 8,
                        offset: Offset(0, 4),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 10,
            offset: Offset(0, 4),
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
                  color: const Color(0xFFFFF3E8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.location_on,
                  color: Color(0xFFEF8A17),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: SmartReTranslator(
                  text: 'Location Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          if (_distanceToShop != null)
            Container(
              constraints: const BoxConstraints(maxWidth: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEF8A17),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.near_me, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      MarketplaceService.formatDistance(_distanceToShop!),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (displayAddress != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE4E7EC), width: 1),
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
                                children: const [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryGreen,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Loading address...',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                displayAddress,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[800],
                                  height: 1.5,
                                ),
                              ),
                      ),
                    ],
                  ),
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
                            'Lat: ${_shortCoordinate(shopLat)}, Long: ${_shortCoordinate(shopLng)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                color: const Color(0xFFF8F9FB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Fetching address from location...',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: shopLat != null && shopLng != null ? _openMaps : null,
              icon: const Icon(Icons.map_outlined, size: 20),
              label: const SmartReTranslator(
                text: 'Open in Maps',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              label: const SmartReTranslator(
                text: 'Go Back',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
