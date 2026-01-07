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

  // Get Current User ID
  static Future<String?> _getCurrentUserId() async {
    try {
      final profileJson = await _storage.read(key: 'user_profile');
      if (profileJson == null) return null;

      final profile = jsonDecode(profileJson) as Map<String, dynamic>;
      return profile['user_id'];
    } catch (e) {
      debugPrint('Error getting user ID: $e');
      return null;
    }
  }

  // Create Shop
  static Future<Map<String, dynamic>> createRetailer(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.post(
        'retail/createretailers',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        debugPrint('✅ Shop created: ${result['retailer_id']}');
        return result;
      } else {
        throw Exception(response.error ?? 'Failed to create shop');
      }
    } catch (e) {
      debugPrint('❌ Error creating shop: $e');
      rethrow;
    }
  }

  // Get All Shops for Current User
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

  // Get Single Shop by ID
  static Future<Map<String, dynamic>?> getShopById(String retailerId) async {
    try {
      final response = await _apiService.get(
        'retail/getretail/$retailerId',
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        debugPrint('✅ Shop fetched: $retailerId');
        return result;
      } else if (response.statusCode == 404) {
        debugPrint('⚠️ Shop not found');
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

  // Update Shop
  static Future<void> updateRetailer(
    String retailerId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.put(
        'retail/updateretailers/$retailerId',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Shop updated: $retailerId');
      } else {
        throw Exception(response.error ?? 'Failed to update shop');
      }
    } catch (e) {
      debugPrint('❌ Error updating shop: $e');
      rethrow;
    }
  }

  // Upload Shop Image
  static Future<void> uploadShopImage(String retailerId, File imageFile) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${ApiService.baseUrl}/shop-images/upload');

      var request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['retailer_id'] = retailerId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Shop image uploaded successfully');
      } else {
        throw Exception('Failed to upload shop image: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error uploading shop image: $e');
      rethrow;
    }
  }

  // Create Product
  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.post(
        'retail/createproducts',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        final result = response.data as Map<String, dynamic>;
        debugPrint('✅ Product created: ${result['product_id']}');
        return result;
      } else {
        throw Exception(response.error ?? 'Failed to create product');
      }
    } catch (e) {
      debugPrint('❌ Error creating product: $e');
      rethrow;
    }
  }

  // Get Products by Shop
  static Future<List<Map<String, dynamic>>> getProductsByRetailer(
    String retailerId,
  ) async {
    try {
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

  // Update Product
  static Future<void> updateProduct(
    String productId,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiService.put(
        'retail/updateproducts/$productId',
        body: data,
        requiresAuth: true,
      );

      if (response.isSuccess) {
        debugPrint('✅ Product updated: $productId');
      } else {
        throw Exception(response.error ?? 'Failed to update product');
      }
    } catch (e) {
      debugPrint('❌ Error updating product: $e');
      rethrow;
    }
  }

  // Upload Product Image
  static Future<void> uploadProductImage(
    String productId,
    File imageFile,
  ) async {
    try {
      final token = await _storage.read(key: 'access_token');
      final uri = Uri.parse('${ApiService.baseUrl}/product-images/upload');

      var request = http.MultipartRequest('POST', uri);

      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      request.fields['product_id'] = productId;
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        debugPrint('✅ Product image uploaded successfully');
      } else {
        throw Exception('Failed to upload product image: ${response.body}');
      }
    } catch (e) {
      debugPrint('❌ Error uploading product image: $e');
      rethrow;
    }
  }

  // Clear cache
  static Future<void> clearCache() async {
    debugPrint('✅ Retail cache cleared');
  }
}
