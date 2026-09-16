import 'package:agrhi/core/utils/storage_helper.dart';
import 'package:agrhi/models/feedback_item.dart';
import 'package:agrhi/services/api_service.dart';
import 'package:agrhi/services/auth_service.dart';

/// Coordinates feedback workflows; widgets own forms, navigation and messages.
class FeedbackController {
  FeedbackController({
    StorageHelper? storage,
    AuthService? authService,
    ApiService? apiService,
  }) : _storage = storage ?? StorageHelper(),
       _authService = authService ?? AuthService(),
       _apiService = apiService ?? ApiService.instance;

  final StorageHelper _storage;
  final AuthService _authService;
  final ApiService _apiService;

  Future<void> refreshSession() async {
    await _authService.refreshAccessToken();
  }

  Future<void> submit({
    required String message,
    required bool isProblem,
    Map<String, dynamic>? shopReference,
  }) async {
    final userId = await _storage.getUserId();

    if (userId == null) {
      throw Exception('Authentication required');
    }

    String finalMessage = message.trim();

    if (shopReference != null) {
      final shopName = shopReference['shop_name'] ?? 'Unknown Shop';
      final retailerId = shopReference['retailer_id'] ?? '';
      final requestType = shopReference['request_type'] ?? 'delete_shop';

      if (requestType == 'delete_shop') {
        finalMessage =
            'DELETE SHOP REQUEST\n\n'
            'Shop Name: $shopName\n'
            'Shop ID: $retailerId\n\n'
            'Reason:\n$finalMessage';
      } else if (requestType == 'edit_shop') {
        finalMessage =
            'EDIT SHOP REQUEST\n\n'
            'Shop Name: $shopName\n'
            'Shop ID: $retailerId\n\n'
            'Changes Needed:\n$finalMessage';
      }
    }

    final response = await _apiService.post(
      '/feedback/addfeedback',
      body: {
        'user_id': userId,
        'message': finalMessage,
        'isproblem': isProblem,
      },
      requiresAuth: true,
    );

    if (response.isSuccess) {
      return;
    } else if (response.statusCode == 401) {
      throw Exception('Session expired. Please log in again.');
    } else if (response.isOffline) {
      throw Exception('No internet connection. Please check your network.');
    } else {
      throw Exception(
        response.error ?? 'Failed to submit feedback: ${response.statusCode}',
      );
    }
  }

  Future<List<FeedbackItem>> fetchHistory() async {
    final userId = await _storage.getUserId();
    if (userId == null) throw Exception('Authentication required');
    final response = await _apiService.get(
      '/feedback/getfeedback/$userId',
      requiresAuth: true,
    );
    if (response.isSuccess) {
      final dynamic jsonData = response.data;
      List<dynamic> data;
      if (jsonData is List) {
        data = jsonData;
      } else if (jsonData is Map && jsonData['data'] != null) {
        data = jsonData['data'] as List;
      } else {
        data = [];
      }
      return data
          .map((json) => FeedbackItem.fromJson(json))
          .toList()
          .reversed
          .toList();
    }
    if (response.statusCode == 404) return [];
    if (response.statusCode == 401) {
      throw Exception('Session expired - please log in again');
    }
    if (response.isOffline) throw Exception('No internet connection');
    throw Exception('Failed to load feedback history: ${response.statusCode}');
  }
}
