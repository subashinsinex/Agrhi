import 'package:flutter/material.dart';
import 'api_service.dart';

class MarketplaceService {
  static final ApiService _apiService = ApiService.instance;

  /// Get unified marketplace products (farm + retail)
  /// Optional filters: search, maxDistance, productType
  static Future<Map<String, dynamic>> getMarketplaceProducts({
    required double latitude,
    required double longitude,
    String? search,
    double? maxDistance,
    String? productType, // 'all', 'farm', 'retail'
  }) async {
    try {
      debugPrint('🛒 Fetching marketplace products...');
      debugPrint('📍 User location: $latitude, $longitude');

      // Build query parameters
      final queryParams = {
        'lat': latitude.toString(),
        'lng': longitude.toString(),
      };

      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
        debugPrint('🔍 Search filter: $search');
      }

      if (maxDistance != null) {
        queryParams['max_distance'] = maxDistance.toString();
        debugPrint('📏 Max distance: ${maxDistance}km');
      }

      if (productType != null &&
          productType.isNotEmpty &&
          productType != 'all') {
        queryParams['product_type'] = productType;
        debugPrint('🏪 Product type: $productType');
      }

      // Build query string
      final queryString = queryParams.entries
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final response = await _apiService.get(
        'marketplace/products?$queryString',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        final products = (data['products'] as List?) ?? [];
        final total = data['total'] ?? 0;

        debugPrint('✅ Found $total marketplace products');

        return {
          'success': true,
          'products': products,
          'total': total,
          'filters': data['filters'],
        };
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch marketplace products');
        return {
          'success': false,
          'message': 'No internet connection',
          'isOffline': true,
          'products': [],
        };
      } else {
        debugPrint('❌ Failed to fetch marketplace: ${response.error}');
        return {
          'success': false,
          'message': response.error ?? 'Failed to fetch products',
          'products': [],
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching marketplace products: $e');
      return {'success': false, 'message': 'Error: $e', 'products': []};
    }
  }

  /// Get single product details
  static Future<Map<String, dynamic>?> getProductDetails({
    required String productId,
    required String productType, // 'farm' or 'retail'
  }) async {
    try {
      debugPrint('🔍 Fetching product details: $productId ($productType)');

      final response = await _apiService.get(
        'marketplace/products/$productId?product_type=$productType',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data as Map<String, dynamic>;
        debugPrint('✅ Product details fetched');
        return data['product'];
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch product details');
        return null;
      } else {
        debugPrint('❌ Failed to fetch product details: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching product details: $e');
      return null;
    }
  }

  /// Get product type options
  static List<Map<String, String>> getProductTypeOptions() {
    return [
      {'value': 'all', 'label': 'All Products'},
      {'value': 'farm', 'label': 'Farm Products'},
      {'value': 'retail', 'label': 'Retail Products'},
    ];
  }

  /// Format distance for display
  static String formatDistance(double distanceKm) {
    if (distanceKm < 0.1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 1) {
      return '${(distanceKm * 1000).round()}m away';
    } else if (distanceKm < 10) {
      return '${distanceKm.toStringAsFixed(1)}km away';
    } else {
      return '${distanceKm.round()}km away';
    }
  }

  /// Format price with currency
  static String formatPrice(dynamic price, String unit) {
    try {
      final priceValue = price is String
          ? double.tryParse(price) ?? 0
          : (price as num).toDouble();
      return '₹${priceValue.toStringAsFixed(2)}/$unit';
    } catch (e) {
      debugPrint('❌ Error formatting price: $e');
      return '₹0.00/$unit';
    }
  }

  /// Get product type badge info
  static Map<String, dynamic> getProductTypeBadge(String productType) {
    if (productType == 'farm') {
      return {
        'label': 'Farm',
        'color': const Color(0xFF4CAF50),
        'icon': Icons.agriculture,
      };
    } else {
      return {
        'label': 'Retail',
        'color': const Color(0xFF2196F3),
        'icon': Icons.store,
      };
    }
  }

  /// Check if product is available
  static bool isProductAvailable(Map<String, dynamic> product) {
    return product['is_available'] == true || product['is_available'] == 1;
  }

  /// Get product availability status text
  static String getAvailabilityStatus(Map<String, dynamic> product) {
    if (isProductAvailable(product)) {
      final quantity = product['quantity_available'];
      if (quantity != null) {
        final quantityValue = quantity is String
            ? double.tryParse(quantity) ?? 0
            : (quantity as num).toDouble();

        if (quantityValue > 0) {
          return 'In Stock';
        } else {
          return 'Out of Stock';
        }
      }
      return 'Available';
    } else {
      return 'Not Available';
    }
  }

  /// Get product availability color
  static Color getAvailabilityColor(Map<String, dynamic> product) {
    if (isProductAvailable(product)) {
      final quantity = product['quantity_available'];
      if (quantity != null) {
        final quantityValue = quantity is String
            ? double.tryParse(quantity) ?? 0
            : (quantity as num).toDouble();

        if (quantityValue > 10) {
          return Colors.green;
        } else if (quantityValue > 0) {
          return Colors.orange;
        } else {
          return Colors.red;
        }
      }
      return Colors.green;
    } else {
      return Colors.red;
    }
  }

  /// Format quantity for display
  static String formatQuantity(dynamic quantity, String unit) {
    try {
      final quantityValue = quantity is String
          ? double.tryParse(quantity) ?? 0
          : (quantity as num).toDouble();

      if (quantityValue == quantityValue.roundToDouble()) {
        return '${quantityValue.round()} $unit';
      } else {
        return '${quantityValue.toStringAsFixed(2)} $unit';
      }
    } catch (e) {
      debugPrint('❌ Error formatting quantity: $e');
      return '0 $unit';
    }
  }

  /// Get formatted product created date
  static String getFormattedDate(dynamic createdAt) {
    try {
      if (createdAt == null) return 'Unknown date';

      final DateTime date = createdAt is String
          ? DateTime.parse(createdAt)
          : createdAt as DateTime;

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        return '${(difference.inDays / 7).floor()} weeks ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      debugPrint('❌ Error formatting date: $e');
      return 'Unknown date';
    }
  }

  /// Validate if location is available for product
  static bool hasValidLocation(Map<String, dynamic> product) {
    final shopLat = product['shop_latitude'];
    final shopLng = product['shop_longitude'];

    if (shopLat == null || shopLng == null) return false;

    try {
      final lat = shopLat is String
          ? double.parse(shopLat)
          : shopLat.toDouble();
      final lng = shopLng is String
          ? double.parse(shopLng)
          : shopLng.toDouble();

      // Basic validation for valid coordinates
      return lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    } catch (e) {
      return false;
    }
  }

  /// Filter products by search query locally
  static List<Map<String, dynamic>> filterProductsLocally(
    List<Map<String, dynamic>> products,
    String searchQuery,
  ) {
    if (searchQuery.isEmpty) return products;

    final query = searchQuery.toLowerCase();
    return products.where((product) {
      final name = (product['product_name'] ?? '').toString().toLowerCase();
      final variety = (product['variety'] ?? '').toString().toLowerCase();
      final description = (product['description'] ?? '')
          .toString()
          .toLowerCase();
      final seller = (product['seller_name'] ?? '').toString().toLowerCase();

      return name.contains(query) ||
          variety.contains(query) ||
          description.contains(query) ||
          seller.contains(query);
    }).toList();
  }

  /// Sort products by different criteria
  static List<Map<String, dynamic>> sortProducts(
    List<Map<String, dynamic>> products,
    String sortBy,
  ) {
    final sortedProducts = List<Map<String, dynamic>>.from(products);

    switch (sortBy) {
      case 'distance':
        sortedProducts.sort((a, b) {
          final distA =
              (a['distance_km'] as num?)?.toDouble() ?? double.infinity;
          final distB =
              (b['distance_km'] as num?)?.toDouble() ?? double.infinity;
          return distA.compareTo(distB);
        });
        break;
      case 'price_low':
        sortedProducts.sort((a, b) {
          final priceA =
              (a['price_per_unit'] as num?)?.toDouble() ?? double.infinity;
          final priceB =
              (b['price_per_unit'] as num?)?.toDouble() ?? double.infinity;
          return priceA.compareTo(priceB);
        });
        break;
      case 'price_high':
        sortedProducts.sort((a, b) {
          final priceA = (a['price_per_unit'] as num?)?.toDouble() ?? 0;
          final priceB = (b['price_per_unit'] as num?)?.toDouble() ?? 0;
          return priceB.compareTo(priceA);
        });
        break;
      case 'newest':
        sortedProducts.sort((a, b) {
          final dateA =
              DateTime.tryParse(a['created_at'] ?? '') ?? DateTime(1970);
          final dateB =
              DateTime.tryParse(b['created_at'] ?? '') ?? DateTime(1970);
          return dateB.compareTo(dateA);
        });
        break;
      default:
        // Default: sort by distance
        sortedProducts.sort((a, b) {
          final distA =
              (a['distance_km'] as num?)?.toDouble() ?? double.infinity;
          final distB =
              (b['distance_km'] as num?)?.toDouble() ?? double.infinity;
          return distA.compareTo(distB);
        });
    }

    return sortedProducts;
  }

  /// Get sort options
  static List<Map<String, String>> getSortOptions() {
    return [
      {'value': 'distance', 'label': 'Nearest First'},
      {'value': 'price_low', 'label': 'Price: Low to High'},
      {'value': 'price_high', 'label': 'Price: High to Low'},
      {'value': 'newest', 'label': 'Newest First'},
    ];
  }
}
