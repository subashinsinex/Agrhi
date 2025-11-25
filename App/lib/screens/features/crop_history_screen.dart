// lib/screens/features/crop_history_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/colors.dart';
import '../../utils/constants.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../shared/widgets/smart_retranslator.dart';

class CropHistoryScreen extends StatefulWidget {
  const CropHistoryScreen({super.key});

  @override
  State<CropHistoryScreen> createState() => _CropHistoryScreenState();
}

class _CropHistoryScreenState extends State<CropHistoryScreen> {
  List<Map<String, dynamic>> _cropHistory = [];
  bool _isLoading = true;
  String? _error;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    _loadCropHistory();
  }

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  String _formatNumber(dynamic value, {int decimals = 1}) {
    if (value == null) return '0';
    if (value is num) return value.toStringAsFixed(decimals);
    if (value is String) {
      final parsed = double.tryParse(value);
      return parsed?.toStringAsFixed(decimals) ?? '0';
    }
    return '0';
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    try {
      final date = DateTime.parse(dateValue.toString());
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateValue.toString();
    }
  }

  Future<void> _loadCropHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      final userId = await _storage.read(key: 'user_id');
      if (userId == null) {
        throw Exception('User ID not found');
      }

      debugPrint('🔍 Loading crop history for user: $userId');

      final response = await http
          .get(
            Uri.parse('${AppConstants.baseUrl}/farmcrop/crophistory/$userId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 30));

      debugPrint('📡 Response status: ${response.statusCode}');
      debugPrint('📦 Response body: ${response.body}');

      if (response.statusCode == 200) {
        // ✅ Check if response body is empty
        if (response.body.trim().isEmpty) {
          debugPrint('ℹ️ Empty response - no crop history');
          setState(() {
            _cropHistory = [];
            _isLoading = false;
          });
          return;
        }

        final decoded = jsonDecode(response.body);

        List<Map<String, dynamic>> historyList;

        if (decoded is List) {
          historyList = decoded.cast<Map<String, dynamic>>();
        } else if (decoded is Map<String, dynamic>) {
          historyList = [decoded];
        } else {
          throw Exception('Unexpected response format');
        }

        // ✅ Server already filters inactive crops, use data as-is
        debugPrint('✅ Loaded ${historyList.length} crops from history');
        setState(() {
          _cropHistory = historyList;
          _isLoading = false;
        });
      } else if (response.statusCode == 404) {
        debugPrint('ℹ️ No crop history found for this user');
        setState(() {
          _cropHistory = [];
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load crop history: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('❌ Error loading crop history: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: 'Crop History'),
      backgroundColor: AppColors.backgroundColor,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Loading crop history...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Error loading crop history',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _error!,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCropHistory,
              icon: const Icon(Icons.refresh),
              label: const SmartReTranslator(text: 'Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
              ),
            ),
          ],
        ),
      );
    }

    if (_cropHistory.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 100, color: Colors.grey.shade300),
              const SizedBox(height: 24),
              const SmartReTranslator(
                text: 'No Crop History',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              const SmartReTranslator(
                text:
                    'You don\'t have any completed or inactive crops yet. Your crop history will appear here once crops are harvested or marked as inactive.',
                style: TextStyle(fontSize: 15, color: Colors.grey, height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade600, Colors.orange.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.history,
                    label: 'Total History',
                    value: _cropHistory.length.toString(),
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: Colors.white.withOpacity(0.3),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.crop,
                    label: 'Total Area',
                    value:
                        '${_cropHistory.fold<double>(0.0, (sum, c) => sum + double.parse(c['field_size']?.toString() ?? '0')).toStringAsFixed(1)} Ac',
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final crop = _cropHistory[index];
              return _buildCropHistoryCard(crop);
            }, childCount: _cropHistory.length),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 32),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCropHistoryCard(Map<String, dynamic> crop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: Colors.orange.shade700,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        crop['plant_name']?.toString() ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (crop['crop_type'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          crop['crop_type'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    crop['status']?.toString() ?? 'Completed',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  Icons.crop,
                  '${_formatNumber(crop['field_size'])} Acres',
                ),
                if (crop['survey_number'] != null)
                  _buildChip(
                    Icons.location_on,
                    crop['survey_number'] as String,
                  ),
                if (crop['planting_date'] != null)
                  _buildChip(
                    Icons.calendar_today,
                    'Planted: ${_formatDate(crop['planting_date'])}',
                  ),
                if (crop['harvest_date'] != null)
                  _buildChip(
                    Icons.event_available,
                    'Harvested: ${_formatDate(crop['harvest_date'])}',
                  ),
                if (crop['duration'] != null)
                  _buildChip(
                    Icons.timer,
                    '${_formatNumber(crop['duration'], decimals: 0)} days',
                  ),
              ],
            ),
            if (crop['farmer'] != null ||
                crop['water_requirement'] != null) ...[
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (crop['farmer'] != null) ...[
                    Icon(Icons.person, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(
                      crop['farmer'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                  if (crop['farmer'] != null &&
                      crop['water_requirement'] != null)
                    const SizedBox(width: 16),
                  if (crop['water_requirement'] != null) ...[
                    Icon(
                      Icons.water_drop,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${crop['water_requirement']} Water',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade700),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
