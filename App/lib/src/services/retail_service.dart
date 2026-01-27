// lib/src/services/retail_service.dart

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'api_service.dart';

class RetailService {
  static final ApiService _apiService = ApiService.instance;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ✅ Timeout duration for multipart uploads
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

  // ✅ Create Shop (Step 1: Create retailer details, returns retailer_id)
  static Future<Map<String, dynamic>> createRetailer(
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('📤 Creating new retailer...');
      debugPrint('📦 Request data: ${jsonEncode(data)}');

      final response = await _apiService.post(
        'retail/createretailers',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        final retailerId = result['retailer_id'];

        if (retailerId == null) {
          throw Exception('No retailer_id returned from server');
        }

        debugPrint('✅ Shop created successfully with ID: $retailerId');
        return result;
      } else {
        final errorMsg = response.error ?? 'Failed to create shop';
        debugPrint('❌ Create shop failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error creating shop: $e');
      rethrow;
    }
  }

  // ✅ Upload Shop Image (Step 2: Upload image with retailer_id)
  static Future<Map<String, dynamic>> uploadShopImage(
    String retailerId,
    File imageFile,
  ) async {
    try {
      debugPrint('📤 Starting shop image upload...');
      debugPrint('🆔 Retailer ID: $retailerId');
      debugPrint('📷 Image path: ${imageFile.path}');
      debugPrint('📊 File size: ${await imageFile.length()} bytes');

      // ✅ Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${ApiService.baseUrl}/shop-images/upload');

      debugPrint('🌐 Upload URL: $uri');

      var request = http.MultipartRequest('POST', uri);

      // ✅ Add authorization header
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
        debugPrint('🔐 Authorization header added');
      }

      // ✅ Add retailer_id field
      request.fields['retailer_id'] = retailerId;

      // ✅ Add image file with proper content type
      final multipartFile = await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        contentType: MediaType('image', 'jpeg'),
        filename:
            'shop_${retailerId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
        debugPrint('✅ Shop image uploaded successfully');

        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          return responseData;
        } catch (e) {
          // If response is not JSON, return success message
          return {'success': true, 'message': 'Image uploaded successfully'};
        }
      } else {
        final errorMsg =
            'Failed to upload shop image: ${response.statusCode} - ${response.body}';
        debugPrint('❌ $errorMsg');
        throw Exception(errorMsg);
      }
    } on SocketException catch (e) {
      debugPrint('❌ Network error uploading shop image: $e');
      throw Exception('Network error. Please check your connection.');
    } on http.ClientException catch (e) {
      debugPrint('❌ HTTP client error uploading shop image: $e');
      throw Exception('Connection failed. Please try again.');
    } catch (e) {
      debugPrint('❌ Error uploading shop image: $e');
      rethrow;
    }
  }

  // ✅ Get All Shops for Current User
  static Future<List<Map<String, dynamic>>> getAllShops() async {
    try {
      final userId = await _getCurrentUserId();
      if (userId == null) {
        throw Exception('User ID not found in profile');
      }

      debugPrint('🔍 Fetching all shops for user_id: $userId');

      final response = await _apiService.get(
        'retail/getretailers/$userId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data;
        if (data is List) {
          debugPrint('✅ Found ${data.length} shops');
          return data.cast<Map<String, dynamic>>();
        }
        debugPrint('⚠️ Unexpected response format');
        return [];
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch shops');
        return [];
      } else {
        debugPrint('❌ Failed to fetch shops: ${response.error}');
        return [];
      }
    } catch (e) {
      debugPrint('❌ Error getting shops: $e');
      return [];
    }
  }

  // ✅ Get Single Shop by ID
  static Future<Map<String, dynamic>?> getShopById(String retailerId) async {
    try {
      debugPrint('🔍 Fetching shop by ID: $retailerId');

      final response = await _apiService.get(
        'retail/getretail/$retailerId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        debugPrint('✅ Shop fetched successfully: $retailerId');
        return result;
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Shop not found: $retailerId');
        return null;
      } else if (response.isOffline) {
        debugPrint('⚠️ Offline - Cannot fetch shop');
        return null;
      } else {
        debugPrint('❌ Failed to fetch shop: ${response.error}');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error fetching shop: $e');
      return null;
    }
  }

  // ✅ Update Shop
  static Future<void> updateRetailer(
    String retailerId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('🔄 Updating retailer: $retailerId');
      debugPrint('📦 Update data: ${jsonEncode(data)}');

      final response = await _apiService.put(
        'retail/updateretailers/$retailerId',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Shop updated successfully: $retailerId');
      } else {
        final errorMsg = response.error ?? 'Failed to update shop';
        debugPrint('❌ Update shop failed: $errorMsg');
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('❌ Error updating shop: $e');
      rethrow;
    }
  }

  // ✅ Create Product
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('📤 Creating new product...');
      debugPrint('📦 Request data: ${jsonEncode(data)}');

      final response = await _apiService.post(
        'retail/createproducts',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        final productId = result['product_id'];
        debugPrint('✅ Product created successfully: $productId');
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

  // ✅ Upload Product Image
  static Future<Map<String, dynamic>> uploadProductImage(
    String productId,
    File imageFile,
  ) async {
    try {
      debugPrint('📤 Starting product image upload...');
      debugPrint('🆔 Product ID: $productId');
      debugPrint('📷 Image path: ${imageFile.path}');
      debugPrint('📊 File size: ${await imageFile.length()} bytes');

      // ✅ Check if file exists
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist');
      }

      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${ApiService.baseUrl}/product-images/upload');

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
            'product_${productId}_${DateTime.now().millisecondsSinceEpoch}.jpg',
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
        debugPrint('✅ Product image uploaded successfully');

        try {
          final responseData =
              jsonDecode(response.body) as Map<String, dynamic>;
          return responseData;
        } catch (e) {
          // If response is not JSON, return success message
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

  // ✅ Get Products by Shop
  static Future<List<Map<String, dynamic>>> getProductsByRetailer(
    String retailerId,
  ) async {
    try {
      debugPrint('🔍 Fetching products for retailer: $retailerId');

      final response = await _apiService.get(
        'retail/getproducts/retailer/$retailerId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final data = response.data;
        if (data is List) {
          debugPrint('✅ Fetched ${data.length} products');
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
      debugPrint('❌ Error fetching products: $e');
      return [];
    }
  }

  // ✅ Update Product
  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      debugPrint('🔄 Updating product: $productId');
      debugPrint('📦 Update data: ${jsonEncode(data)}');

      final response = await _apiService.put(
        'retail/updateproducts/$productId',
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

  // ✅ Toggle Product Active/Inactive Status
  static Future<Map<String, dynamic>> toggleProductStatus(
    String productId,
  ) async {
    try {
      debugPrint('🔄 Toggling product status: $productId');

      final response = await _apiService.post(
        'retail/products/$productId/toggle-status',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        final isActive = result['is_active'] ?? false;
        debugPrint(
          '✅ Product status toggled successfully: $productId (Active: $isActive)',
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

  // ✅ Delete Product (Optional - if your backend supports it)
  static Future<void> deleteProduct(String productId) async {
    try {
      debugPrint('🗑️ Deleting product: $productId');

      final response = await _apiService.delete(
        'retail/deleteproducts/$productId',
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

  // ✅ Clear cache
  static Future<void> clearCache() async {
    debugPrint('🧹 Retail cache cleared');
  }
}
