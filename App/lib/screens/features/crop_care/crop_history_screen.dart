// lib/screens/features/crop_history_screen.dart
import 'package:flutter/material.dart';
import '../../../utils/colors.dart';
import '../../../src/database/database_helper.dart';
import '../../shared/custom_app_bar.dart';
import '../../shared/smart_retranslator.dart';
import 'add_edit_crop_screen.dart';

class CropHistoryScreen extends StatefulWidget {
  const CropHistoryScreen({super.key});

  @override
  State<CropHistoryScreen> createState() => _CropHistoryScreenState();
}

class _CropHistoryScreenState extends State<CropHistoryScreen> {
  List<Map<String, dynamic>> _inactiveCrops = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadInactiveCrops();
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  String _formatDateOnly(String? dateTimeString) {
    if (dateTimeString == null || dateTimeString.isEmpty) return '';
    try {
      if (dateTimeString.contains('T')) {
        return dateTimeString.split('T')[0];
      }
      if (dateTimeString.contains(' ')) {
        return dateTimeString.split(' ')[0];
      }
      return dateTimeString;
    } catch (e) {
      return dateTimeString;
    }
  }

  // ✅ Calculate crop duration
  int? _calculateCropDuration(String? plantingDate, String? harvestDate) {
    if (plantingDate == null || harvestDate == null) return null;
    if (plantingDate.isEmpty || harvestDate.isEmpty) return null;

    try {
      final planted = DateTime.tryParse(plantingDate);
      final harvested = DateTime.tryParse(harvestDate);

      if (planted != null && harvested != null) {
        return harvested.difference(planted).inDays;
      }
    } catch (e) {
      debugPrint('Error calculating duration: $e');
    }
    return null;
  }

  // ✅ Calculate statistics from inactive crops (3 key metrics)
  Map<String, dynamic> _calculateStatistics() {
    final totalCrops = _inactiveCrops.length;

    // Count unique crop varieties
    final uniqueCropTypes = _inactiveCrops
        .map((c) => c['plantname']?.toString() ?? c['plant_name']?.toString())
        .where((name) => name != null && name.isNotEmpty)
        .toSet()
        .length;

    // Count crops harvested this year
    final currentYear = DateTime.now().year;
    final thisYearCrops = _inactiveCrops.where((crop) {
      final harvestDate = crop['harvestdate']?.toString();
      if (harvestDate != null && harvestDate.isNotEmpty) {
        try {
          final date = DateTime.tryParse(harvestDate);
          return date?.year == currentYear;
        } catch (_) {}
      }
      return false;
    }).length;

    return {
      'totalCrops': totalCrops,
      'uniqueTypes': uniqueCropTypes,
      'thisYearCrops': thisYearCrops,
    };
  }

  Future<void> _loadInactiveCrops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final allCrops = await db.getAllCrops();

      // ✅ Filter to show only inactive crops (isactive = 0)
      final inactiveCrops = allCrops
          .where((crop) => crop['isactive'] == 0)
          .toList();

      setState(() {
        _inactiveCrops = inactiveCrops;
        _isLoading = false;
      });

      debugPrint('✅ Loaded ${inactiveCrops.length} inactive crops');
    } catch (e) {
      debugPrint('❌ Error loading inactive crops: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ✅ Show detailed crop info dialog
  void _showCropInfoDialog(Map<String, dynamic> crop) {
    final plantName =
        crop['plantname']?.toString() ??
        crop['plant_name']?.toString() ??
        'Unknown Crop';

    final plantingDate = _formatDateOnly(crop['plantingdate']?.toString());
    final harvestDate = _formatDateOnly(crop['harvestdate']?.toString());
    final duration = _calculateCropDuration(
      crop['plantingdate']?.toString(),
      crop['harvestdate']?.toString(),
    );
    final fieldSize = _formatNumber(crop['fieldsize']);
    final surveyNumber = crop['survey_number']?.toString() ?? 'N/A';
    final soilType = crop['soiltype']?.toString();
    final status = crop['status']?.toString() ?? 'Unknown';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history, color: Colors.orange.shade700),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                plantName,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.grey.shade700,
                    ),
                    const SizedBox(width: 6),
                    SmartReTranslator(
                      text: status,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // Farm Details
              _buildInfoRow(
                Icons.agriculture,
                'Survey Number',
                surveyNumber,
                AppColors.primaryGreen,
              ),
              const SizedBox(height: 12),

              // Field Size
              _buildInfoRow(
                Icons.crop_landscape,
                'Field Size',
                '$fieldSize Acres',
                Colors.orange.shade700,
              ),
              const Divider(height: 20),

              // Planting Date
              _buildInfoRow(
                Icons.calendar_month,
                'Planting Date',
                plantingDate.isNotEmpty ? plantingDate : 'Not recorded',
                Colors.green.shade700,
              ),
              const SizedBox(height: 12),

              // Harvest Date
              _buildInfoRow(
                Icons.event_available,
                'Harvest Date',
                harvestDate.isNotEmpty ? harvestDate : 'Not recorded',
                Colors.amber.shade800,
              ),

              // Duration
              if (duration != null) ...[
                const SizedBox(height: 12),
                _buildInfoRow(
                  Icons.timer_outlined,
                  'Crop Duration',
                  '$duration days',
                  Colors.blue.shade700,
                ),
              ],

              // Soil Type
              if (soilType != null) ...[
                const Divider(height: 20),
                _buildInfoSection(
                  Icons.terrain,
                  'Soil Type',
                  soilType,
                  Colors.brown.shade700,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const SmartReTranslator(
              text: 'Close',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _reactivateCrop(crop);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.successColor,
            ),
            child: const SmartReTranslator(
              text: 'Reactivate',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build info rows
  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }

  // Helper method to build info sections
  Widget _buildInfoSection(
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              SmartReTranslator(
                text: value.isNotEmpty ? value : 'Not specified',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Reactivate crop
  Future<void> _reactivateCrop(Map<String, dynamic> crop) async {
    final cropId = crop['usercropid'].toString();
    final plantName =
        crop['plantname']?.toString() ??
        crop['plant_name']?.toString() ??
        'this crop';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartReTranslator(
          text: 'Reactivate Crop?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SmartReTranslator(
          text:
              'Are you sure you want to reactivate $plantName? It will appear in the active crops list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SmartReTranslator(text: 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.successColor,
            ),
            child: const SmartReTranslator(text: 'Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = DatabaseHelper.instance;

      var canActivate = await db.canActivateCrop(cropId);

      if (!canActivate) {
        final updated = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => AddCropScreen(crop: crop)),
        );

        if (updated == true) {
          canActivate = await db.canActivateCrop(cropId);

          if (canActivate) {
            await db.updateCropActiveStatus(cropId: cropId, isActive: 1);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: SmartReTranslator(
                    text:
                        'Harvest date updated and crop reactivated successfully',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: SmartReTranslator(
                    text:
                        'Please set a valid future harvest date to reactivate this crop',
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          }
        }

        await _loadInactiveCrops();
        return;
      }

      await db.updateCropActiveStatus(cropId: cropId, isActive: 1);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: SmartReTranslator(text: 'Crop reactivated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadInactiveCrops();
    } catch (e) {
      debugPrint('❌ Error reactivating crop: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: SmartReTranslator(text: 'Error: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Crop History',
        showOnlineStatus: true,
      ),
      backgroundColor: Colors.transparent,
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.primaryGreen),
                  const SizedBox(height: 16),
                  const SmartReTranslator(
                    text: 'Loading crop history...',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.errorColor,
                  ),
                  const SizedBox(height: 16),
                  const SmartReTranslator(
                    text: 'Error loading crop history',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadInactiveCrops,
                    icon: const Icon(Icons.refresh),
                    label: const SmartReTranslator(
                      text: 'Retry',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                    ),
                  ),
                ],
              ),
            )
          : _inactiveCrops.isEmpty
          ? Center(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    const SmartReTranslator(
                      text:
                          'You don\'t have any inactive crops yet. Deactivated crops will appear here.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            )
          : CustomScrollView(
              slivers: [
                // ✅ Summary Card with 3 Metrics (3x1 Single Row)
                SliverToBoxAdapter(
                  child: Builder(
                    builder: (context) {
                      final stats = _calculateStatistics();

                      return Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.orange.shade600,
                              Colors.orange.shade100,
                            ],
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
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.history,
                                label: 'Total History',
                                value: stats['totalCrops'].toString(),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.calendar_today,
                                label: 'This Year',
                                value: stats['thisYearCrops'].toString(),
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 60,
                              color: Colors.white.withOpacity(0.3),
                            ),
                            Expanded(
                              child: _buildStatItem(
                                icon: Icons.category,
                                label: 'Unique Varieties',
                                value: stats['uniqueTypes'].toString(),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                // Crop List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final crop = _inactiveCrops[index];
                      return _buildCropHistoryCard(crop);
                    }, childCount: _inactiveCrops.length),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCropHistoryCard(Map<String, dynamic> crop) {
    final isPending = (crop['isdirty'] == 1 || crop['isuploaded'] == 0);

    // Format dates to show only date (remove time)
    String? plantingDate = _formatDateOnly(crop['plantingdate']?.toString());
    String? harvestDate = _formatDateOnly(crop['harvestdate']?.toString());

    final plantName =
        crop['plantname']?.toString() ??
        crop['plant_name']?.toString() ??
        'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isPending
            ? Border.all(color: Colors.orange.shade300, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showCropInfoDialog(crop),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.history,
                      color: Colors.grey.shade600,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SmartReTranslator(
                          text: plantName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (crop['croptype'] != null) ...[
                          const SizedBox(height: 2),
                          SmartReTranslator(
                            text: crop['croptype'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isPending)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.cloud_upload,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  const SizedBox(width: 8),
                  // ✅ Inactive Badge (clickable to reactivate)
                  InkWell(
                    onTap: () => _reactivateCrop(crop),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const SmartReTranslator(
                        text: 'Inactive',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Crop Details in 2x2 Grid
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Row 1: Survey Number | Acres
                    Row(
                      children: [
                        // Survey Number (Left)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 14,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  const SmartReTranslator(
                                    text: 'Survey',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                crop['survey_number']?.toString() ?? 'N/A',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Acres (Right)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.crop_landscape,
                                    size: 14,
                                    color: Colors.orange.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  const SmartReTranslator(
                                    text: 'Area',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    '${_formatNumber(crop['fieldsize'])} ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SmartReTranslator(
                                    text: 'Ac',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Row 2: Planting Date | Harvest Date
                    Row(
                      children: [
                        // Planting Date (Left)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_month,
                                    size: 14,
                                    color: Colors.green.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  const SmartReTranslator(
                                    text: 'Planted',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                plantingDate.isNotEmpty ? plantingDate : 'N/A',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Harvest Date (Right)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.event_available,
                                    size: 14,
                                    color: Colors.amber.shade800,
                                  ),
                                  const SizedBox(width: 4),
                                  const SmartReTranslator(
                                    text: 'Harvest',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                harvestDate.isNotEmpty ? harvestDate : 'N/A',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade800,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Soil Type (if exists)
                    if (crop['soiltype'] != null) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.terrain,
                            size: 14,
                            color: Colors.brown.shade700,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: SmartReTranslator(
                              text: crop['soiltype'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        SmartReTranslator(
          text: label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.9),
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
