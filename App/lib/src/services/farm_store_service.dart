// lib/src/services/farm_store_service.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import 'api_service.dart';

class FarmStoreService {
  static final ApiService _apiService = ApiService.instance;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Duration _uploadTimeout = Duration(seconds: 30);

  // Get Current User ID
  static Future<String?> _getCurrentUserId() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) return null;

      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      return profile['user_id'];
    } catch (e) {
      debugPrint('❌ Error getting user ID: $e');
      return null;
    }
  }

  // ===== SHOP PLACE METHODS =====

  /// Add or update farmer shop location
  static Future<Map<String, dynamic>> addFarmerShopPlace({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('📍 Saving farmer shop location...');
      debugPrint('Latitude: $latitude, Longitude: $longitude');

      final response = await _apiService.post(
        'farmstore/add-farmer-shop-places',
        body: {'latitude': latitude, 'longitude': longitude},
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Shop place created successfully');
        return {
          'success': true,
          'data': response.data,
          'shopPlace': response.data['shopPlace'],
        };
      } else {
        debugPrint('❌ Failed to create shop place: ${response.error}');

        if (response.isOffline) {
          return {
            'success': false,
            'message': 'No internet connection',
            'isOffline': true,
          };
        } else if (response.isUnauthenticated || response.isUnauthorized) {
          return {
            'success': false,
            'message': 'Authentication required',
            'needsAuth': true,
          };
        } else {
          return {
            'success': false,
            'message': response.error ?? 'Failed to save location',
          };
        }
      }
    } catch (e) {
      debugPrint('❌ Exception in addFarmerShopPlace: $e');
      return {'success': false, 'message': 'Error saving location: $e'};
    }
  }

  /// Get current farmer's shop location
  static Future<Map<String, dynamic>> getMyShopPlace() async {
    try {
      final userId = await _getCurrentUserId();

      if (userId == null) {
        return {
          'success': false,
          'message': 'User not found',
          'needsAuth': true,
        };
      }

      debugPrint('📍 Fetching my shop place (user_id: $userId)...');

      final response = await _apiService.get(
        'farmstore/farmer-shop-places/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final places = response.data as List;
        debugPrint('✅ Fetched ${places.length} shop place(s)');

        if (places.isNotEmpty) {
          return {
            'success': true,
            'shopPlace': places.first,
            'hasLocation': true,
            'latitude': places.first['latitude'],
            'longitude': places.first['longitude'],
          };
        } else {
          return {
            'success': true,
            'hasLocation': false,
            'message': 'No location set yet',
          };
        }
      } else {
        return {
          'success': false,
          'message': response.error ?? 'Failed to fetch location',
          'isOffline': response.isOffline,
        };
      }
    } catch (e) {
      debugPrint('❌ Error fetching my shop place: $e');
      return {'success': false, 'message': 'Error: $e'};
    }
  }

  // ===== FARM PRODUCT METHODS =====

  /// Create new farm product (Step 1: returns product_id)
  static Future<Map<String, dynamic>> createFarmProduct(
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('📤 Creating new farm product...');
      debugPrint('📦 Request data: ${jsonEncode(data)}');

      final response = await _apiService.post(
        'farmstore/farm-products',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        final productId = result['product_id'];

        if (productId == null) {
          throw Exception('No product_id returned from server');
        }

        debugPrint('✅ Product created successfully with ID: $productId');
        return result;
      } else {
        final errorMsg = response.error ?? 'Failed to create product';
        debugPrint('❌ Create product failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error creating product: $e');
      rethrow;
    }
  }

  /// Upload product image (Step 2: Upload image with product_id)
  static Future<Map<String, dynamic>> uploadFarmProductImage(
    String productId,
    File imageFile,
  ) async {
    try {
      debugPrint('📤 Starting farm product image upload...');
      debugPrint('🆔 Product ID: $productId');
      debugPrint('📷 Image path: ${imageFile.path}');
      debugPrint('📊 File size: ${await imageFile.length()} bytes');

      // ✅ Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${ApiService.baseUrl}/product-images/upload-farm');

      debugPrint('🌐 Upload URL: $uri');

      var request = http.MultipartRequest('POST', uri);

      // ✅ Add authorization header
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        debugPrint('🔐 Authorization header added');
      }

      // ✅ Add product_id field
      request.fields['product_id'] = productId;

      // ✅ Add image file with proper content type
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
        filename:
            'farm_product_${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      request.files.add(multipartFile);
      debugPrint('📎 Multipart file added: ${multipartFile.filename}');

      // ✅ Send request with timeout
      debugPrint('⏳ Sending upload request...');
      final streamedResponse = await request.send().timeout(
        _uploadTimeout,
        onTimeout: () {
          debugPrint(
            '⏰ Upload request timed out after ${_uploadTimeout.inSeconds}s',
          );
          throw Exception('Image upload timed out. Please try again.');
        },
      );

      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('📥 Upload response status: ${response.statusCode}');
      debugPrint('📥 Upload response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Farm product image uploaded successfully');

        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          return responseData;
        } catch (e) {
          return {'success': true, 'message': 'Image uploaded successfully'};
        }
      } else {
        final errorMsg =
            'Failed to upload product image: ${response.statusCode} - ${response.body}';
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error uploading product image: $e');
      throw Exception('Network error. Please check your connection.');
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP client error uploading product image: $e');
      throw Exception('Connection failed. Please try again.');
    } catch (e) {
      debugPrint('❌ Error uploading product image: $e');
      rethrow;
    }
  }

  /// Get all products for current farmer
  static Future<List<Map<String, dynamic>>> getAllFarmProducts() async {
    try {
      final userId = await _getCurrentUserId();

      if (userId == null) {
        throw Exception('User ID not found in profile');
      }

      debugPrint('🔍 Fetching all farm products for user_id: $userId');

      final response = await _apiService.get(
        'farmstore/farm-products/farmer/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data;

        if (data is Map<String, dynamic> && data['products'] is List) {
          final products = data['products'] as List;
          debugPrint('✅ Found ${products.length} farm products');
          return products.cast<Map<String, dynamic>>();
        } else if (data is List) {
          debugPrint('✅ Found ${data.length} farm products');
          return data.cast<Map<String, dynamic>>();
        }

        debugPrint('⚠️ Unexpected response format');
        return [];
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch products');
        return [];
      } else {
        debugPrint('❌ Failed to fetch products: ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting farm products: $e');
      return [];
    }
  }

  /// Get products by farmer ID
  static Future<List<Map<String, dynamic>>> getFarmProductsByFarmer(
    String farmerId,
  ) async {
    try {
      debugPrint('🔍 Fetching products for farmer: $farmerId');

      final response = await _apiService.get(
        'farmstore/farm-products/farmer/$farmerId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data;

        if (data is Map<String, dynamic> && data['products'] is List) {
          final products = data['products'] as List;
          debugPrint('✅ Fetched ${products.length} products');
          return products.cast<Map<String, dynamic>>();
        } else if (data is List) {
          debugPrint('✅ Fetched ${data.length} products');
          return data.cast<Map<String, dynamic>>();
        }

        return [];
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch products');
        return [];
      } else {
        debugPrint('❌ Failed to fetch products: ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching products: $e');
      return [];
    }
  }

  /// Get single product by ID
  static Future<Map<String, dynamic>?> getFarmProductById(
    String productId,
  ) async {
    try {
      debugPrint('🔍 Fetching product by ID: $productId');

      final response = await _apiService.get(
        'farmstore/farm-products/$productId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        debugPrint('✅ Product fetched successfully: $productId');
        return result;
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Product not found: $productId');
        return null;
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch product');
        return null;
      } else {
        debugPrint('❌ Failed to fetch product: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching product: $e');
      return null;
    }
  }

  /// Update existing product
  static Future<void> updateFarmProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('🔄 Updating product: $productId');
      debugPrint('📦 Update data: ${jsonEncode(data)}');

      final response = await _apiService.put(
        'farmstore/farm-products/$productId',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Product updated successfully: $productId');
      } else {
        final errorMsg = response.error ?? 'Failed to update product';
        debugPrint('❌ Update product failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error updating product: $e');
      rethrow;
    }
  }

  /// Toggle product availability status
  static Future<Map<String, dynamic>> toggleFarmProductStatus(
    String productId,
  ) async {
    try {
      debugPrint('🔄 Toggling product status: $productId');

      final response = await _apiService.put(
        'farmstore/farm-products/$productId/toggle-status',
        body: {},
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        final isAvailable = result['is_available'] ?? false;
        debugPrint(
          '✅ Product status toggled successfully: $productId (Available: $isAvailable)',
        );
        return result;
      } else {
        final errorMsg = response.error ?? 'Failed to toggle product status';
        debugPrint('❌ Toggle product status failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error toggling product status: $e');
      rethrow;
    }
  }

  /// Delete product
  static Future<void> deleteFarmProduct(String productId) async {
    try {
      debugPrint('🗑️ Deleting product: $productId');

      final response = await _apiService.delete(
        'farmstore/farm-products/$productId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Product deleted successfully: $productId');
      } else {
        final errorMsg = response.error ?? 'Failed to delete product';
        debugPrint('❌ Delete product failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error deleting product: $e');
      rethrow;
    }
  }

  /// Get nearby farm products within 5km
  static Future<List<Map<String, dynamic>>> getNearbyFarmProducts({
    required double latitude,
    required double longitude,
  }) async {
    try {
      debugPrint('📍 Fetching nearby farm products...');
      debugPrint('📍 Location: $latitude, $longitude');

      final response = await _apiService.get(
        'farmstore/farm-products/nearby?lat=$latitude&lng=$longitude',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data;
        if (data is List) {
          debugPrint('✅ Found ${data.length} nearby products');
          return data.cast<Map<String, dynamic>>();
        }
        debugPrint('⚠️ Unexpected response format');
        return [];
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch nearby products');
        return [];
      } else {
        debugPrint('❌ Failed to fetch nearby products: ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error fetching nearby products: $e');
      return [];
    }
  }

  /// Clear cache
  static Future<void> clearCache() async {
    debugPrint('🧹 Farm store cache cleared');
  }
}
