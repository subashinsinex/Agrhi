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
  
  /// Check if product is available
  static bool isProductAvailable(Map<String, dynamic> product) {
    return product['is_available'] == true || product['is_available'] == 1;
  }
}
