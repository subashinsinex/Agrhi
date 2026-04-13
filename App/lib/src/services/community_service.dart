import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../utils/constants.dart';
import '../../utils/storage_helper.dart';

class CommunityService {
  static final _storageHelper = StorageHelper();

  // ─── Shared Dio instance ───────────────────────────────────────────────────

  static Dio get _dio => Dio(
    BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(minutes: 3),
      sendTimeout: const Duration(minutes: 3),
    ),
  );

  // ─── Auth ──────────────────────────────────────────────────────────────────

  static Future<String> _getToken() async {
    final token = await _storageHelper.getAccessToken();
    if (token == null) throw Exception('No access token found');
    return token;
  }

  static Options _authOptions(String token) =>
      Options(headers: {'Authorization': 'Bearer $token'});

  // ─── Posts ─────────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPosts({
    int page = 1,
    int limit = 10,
    String? category,
  }) async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/community/getPosts',
        queryParameters: {
          'page': page,
          'limit': limit,
          if (category != null && category != 'all') 'category': category,
        },
        options: _authOptions(token),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      _log('getPosts', e);
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> getMyPosts({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/community/getMyPosts',
        queryParameters: {'page': page, 'limit': limit},
        options: _authOptions(token),
      );
      final data = response.data;
      if (data is List) return List<Map<String, dynamic>>.from(data);
      if (data is Map && data['posts'] != null) {
        return List<Map<String, dynamic>>.from(data['posts']);
      }
      return [];
    } catch (e) {
      _log('getMyPosts', e);
      rethrow;
    }
  }

  // ─── Create Post ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> createPost({
    required String content,
    required String category,
    File? mediaFile,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    try {
      final token = await _getToken();

      final formData = FormData.fromMap({
        'content': content,
        'category': category,
        if (mediaFile != null)
          'media': await MultipartFile.fromFile(
            mediaFile.path,
            filename: mediaFile.path.split(Platform.pathSeparator).last,
          ),
      });

      final response = await _dio.post(
        '/community/createPost',
        data: formData,
        options: _authOptions(token),
        onSendProgress: onSendProgress,
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _log('createPost', e);
      rethrow;
    }
  }

  // ─── Update Post ───────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> updatePost({
    required int postId,
    required String content,
  }) async {
    try {
      final token = await _getToken();
      final response = await _dio.put(
        '/community/updatePost/$postId',
        data: {'content': content},
        options: _authOptions(token),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _log('updatePost', e);
      rethrow;
    }
  }

  // ─── Delete Post ───────────────────────────────────────────────────────────

  static Future<void> deletePost(int postId) async {
    try {
      final token = await _getToken();
      await _dio.delete(
        '/community/deletePost/$postId',
        options: _authOptions(token),
      );
    } catch (e) {
      _log('deletePost', e);
      rethrow;
    }
  }

  // ─── Likes ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> toggleLike(int postId) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        '/community/toggleLike/$postId',
        options: _authOptions(token),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _log('toggleLike', e);
      rethrow;
    }
  }

  // ─── Comments ──────────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getComments(int postId) async {
    try {
      final token = await _getToken();
      final response = await _dio.get(
        '/community/getComments/$postId',
        options: _authOptions(token),
      );
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      _log('getComments', e);
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> addComment({
    required int postId,
    required String content,
  }) async {
    try {
      final token = await _getToken();
      final response = await _dio.post(
        '/community/addComment/$postId',
        data: {'content': content},
        options: _authOptions(token),
      );
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      _log('addComment', e);
      rethrow;
    }
  }

  static Future<void> deleteComment({
    required int postId,
    required int commentId,
  }) async {
    try {
      final token = await _getToken();
      await _dio.delete(
        '/community/deleteComment/$postId/$commentId',
        options: _authOptions(token),
      );
    } catch (e) {
      _log('deleteComment', e);
      rethrow;
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static void _log(String method, dynamic e) {
    if (e is DioException) {
      debugPrint(
        '❌ CommunityService.$method → '
        '${e.response?.statusCode} | ${e.response?.data ?? e.message}',
      );
    } else {
      debugPrint('❌ CommunityService.$method → $e');
    }
  }
}
