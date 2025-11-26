// lib/screens/features/crop_care_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/colors.dart';
import '../../src/services/crop_care_sync_service.dart';
import '../../src/database/database_helper.dart';
import '../shared/widgets/smart_retranslator.dart';
import 'add_farm_screen.dart';
import 'add_crop_screen.dart';

class CropCareScreen extends StatefulWidget {
  const CropCareScreen({super.key});

  @override
  State<CropCareScreen> createState() => _CropCareScreenState();
}

class _CropCareScreenState extends State<CropCareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final GlobalKey<_FarmsManagerTabState> _farmsTabKey = GlobalKey();
  final GlobalKey<_CropsManagerTabState> _cropsTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
  }

  // UPDATED: Refresh BOTH tabs simultaneously
  void _refreshBothTabs() {
    _cropsTabKey.currentState?._loadCrops();
    _farmsTabKey.currentState?._loadFarms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const SmartReTranslator(
          text: 'Crop Care Manager',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primaryGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync, color: Colors.white),
            onPressed: () => _performManualSync(),
            tooltip: 'Sync',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(
              icon: Icon(Icons.eco, size: 20),
              child: SmartReTranslator(
                text: 'Crops',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Tab(
              icon: Icon(Icons.agriculture, size: 20),
              child: SmartReTranslator(
                text: 'Farms',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      backgroundColor: AppColors.backgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          bool changed = false;
          if (_tabController.index == 0) {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddCropScreen()),
            );
            changed = result == true;
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddFarmScreen()),
            );
            changed = result == true;
          }
          // UPDATED: Refresh both tabs when changed
          if (changed) _refreshBothTabs();
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          CropsManagerTab(key: _cropsTabKey, onDataChanged: _refreshBothTabs),
          FarmsManagerTab(key: _farmsTabKey, onDataChanged: _refreshBothTabs),
        ],
      ),
    );
  }

  Future<void> _performManualSync() async {
    final storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
    );
    try {
      final token = await storage.read(key: 'access_token');
      if (token == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Not authenticated')));
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Text('Syncing...'),
            ],
          ),
          duration: Duration(seconds: 30),
        ),
      );
      final result = await CropCareSyncService.instance.performFullSync(token);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sync completed successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // UPDATED: Refresh both tabs after sync
        _refreshBothTabs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '❌ Sync failed: ${result['error'] ?? 'Unknown error'}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// ==================== FARMS MANAGER TAB ====================

class FarmsManagerTab extends StatefulWidget {
  final VoidCallback onDataChanged; // ADDED: Callback for data changes

  const FarmsManagerTab({super.key, required this.onDataChanged});

  @override
  State<FarmsManagerTab> createState() => _FarmsManagerTabState();
}

class _FarmsManagerTabState extends State<FarmsManagerTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;
  String? _error;
  int _pendingCount = 0;
  String? _expandedFarmId;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadFarms();
  }

  Future<String?> _getAccessToken() async {
    return await _storage.read(key: 'access_token');
  }

  String _formatNumber(dynamic value, [int decimals = 1]) {
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

  Future<void> _loadFarms() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Not authenticated');
      }

      debugPrint('🔄 Starting farm sync...');

      final syncResult = await CropCareSyncService.instance.performFullSync(
        token,
      );
      debugPrint('📊 Sync result: $syncResult');

      final db = DatabaseHelper.instance;
      final farmsList = await db.getAllFarms();
      final pending = await db.getPendingFarms();

      debugPrint(
        '✅ Loaded ${farmsList.length} farms (${pending.length} pending)',
      );

      setState(() {
        _farms = farmsList;
        _pendingCount = pending.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading farms: $e');

      try {
        final db = DatabaseHelper.instance;
        final farmsList = await db.getAllFarms();
        final pending = await db.getPendingFarms();

        setState(() {
          _farms = farmsList;
          _pendingCount = pending.length;
          _isLoading = false;
          _error = 'Using offline data: ${e.toString()}';
        });
        return;
      } catch (_) {}

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addFarm() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddFarmScreen()),
    ).then((added) {
      // UPDATED: Call callback to refresh both tabs
      if (added == true) widget.onDataChanged();
    });
  }

  void _editFarm(Map<String, dynamic> farm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFarmScreen(farm: farm)),
    ).then((updated) {
      // UPDATED: Call callback to refresh both tabs
      if (updated == true) widget.onDataChanged();
    });
  }

  Future<Map<String, dynamic>> _calculateFarmStatistics() async {
    int totalCrops = 0;
    double totalUsedArea = 0.0;
    final totalArea = _farms.fold(
      0.0,
      (sum, f) => sum + _toDouble(f['farmsize']),
    );

    for (var farm in _farms) {
      final farmId = farm['farmid']?.toString() ?? '';
      final crops = await DatabaseHelper.instance.getCropsByFarmId(farmId);
      totalCrops += crops.length;
      totalUsedArea += crops.fold<double>(
        0.0,
        (sum, crop) => sum + _toDouble(crop['fieldsize']),
      );
    }

    final availableArea = totalArea - totalUsedArea;
    final avgUtilization = totalArea > 0
        ? (totalUsedArea / totalArea * 100)
        : 0.0;

    return {
      'totalFarms': _farms.length,
      'totalArea': totalArea,
      'totalCrops': totalCrops,
      'usedArea': totalUsedArea,
      'availableArea': availableArea,
      'avgUtilization': avgUtilization,
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Syncing farms...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    if (_error != null && _farms.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Error loading farms',
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
              onPressed: _loadFarms,
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
      );
    }

    final totalArea = _farms.fold(
      0.0,
      (sum, f) => sum + _toDouble(f['farmsize']),
    );

    return CustomScrollView(
      slivers: [
        if (_pendingCount > 0)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SmartReTranslator(
                      text: '$_pendingCount farm(s) pending sync',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onDataChanged, // UPDATED: Use callback
                    child: const SmartReTranslator(
                      text: 'Sync now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null && _farms.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: SmartReTranslator(
                      text: 'Offline mode - showing local data',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_farms.isNotEmpty)
          SliverToBoxAdapter(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _calculateFarmStatistics(),
              builder: (context, snapshot) {
                final stats =
                    snapshot.data ??
                    {
                      'totalFarms': _farms.length,
                      'totalArea': totalArea,
                      'totalCrops': 0,
                      'usedArea': 0.0,
                      'availableArea': totalArea,
                      'avgUtilization': 0.0,
                    };

                return Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primaryGreen,
                        AppColors.primaryGreen.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryGreen.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.agriculture,
                              label: 'Total Farms',
                              value: stats['totalFarms'].toString(),
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.landscape,
                              label: 'Total Area',
                              value:
                                  '${stats['totalArea'].toStringAsFixed(1)} Ac',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.eco,
                              label: 'Total Crops',
                              value: stats['totalCrops'].toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        height: 1,
                        color: Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.crop_square,
                              label: 'Used Area',
                              value:
                                  '${stats['usedArea'].toStringAsFixed(1)} Ac',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.check_circle_outline,
                              label: 'Available',
                              value:
                                  '${stats['availableArea'].toStringAsFixed(1)} Ac',
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 60,
                            color: Colors.white.withOpacity(0.3),
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                          Expanded(
                            child: _buildUniformStatItem(
                              icon: Icons.analytics_outlined,
                              label: 'Utilization',
                              value:
                                  '${stats['avgUtilization'].toStringAsFixed(0)}%',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        _farms.isEmpty
            ? SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.agriculture,
                          size: 100,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 24),
                        const SmartReTranslator(
                          text: 'No Farms Found',
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
                              'You haven\'t created any farms yet. Start by adding your first farm to manage your crops better.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton.icon(
                          onPressed: _addFarm,
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const SmartReTranslator(
                            text: 'Create Your First Farm',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 32,
                              vertical: 16,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final farm = _farms[index];
                    return _buildFarmCard(farm);
                  }, childCount: _farms.length),
                ),
              ),
      ],
    );
  }

  // Keep all _buildFarmCard, _buildUniformStatItem, _buildAreaStat, and _buildChip methods unchanged
  // They remain exactly as in the previous code...

  Widget _buildFarmCard(Map<String, dynamic> farm) {
    final farmId = farm['farmid']?.toString() ?? '';
    final isExpanded = _expandedFarmId == farmId;
    final isPending = farm['isdirty'] == 1 || farm['isuploaded'] == 0;

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getCropsByFarmId(farmId),
      builder: (context, snapshot) {
        final crops = snapshot.data ?? [];
        final totalFarmArea = _toDouble(farm['farmsize']);
        final usedArea = crops.fold<double>(
          0.0,
          (sum, crop) => sum + _toDouble(crop['fieldsize']),
        );
        final availableArea = totalFarmArea - usedArea;
        final usagePercentage = totalFarmArea > 0
            ? (usedArea / totalFarmArea * 100).clamp(0, 100)
            : 0.0;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isPending
                ? Border.all(color: Colors.orange.shade300, width: 2)
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                setState(() {
                  _expandedFarmId = isExpanded ? null : farmId;
                });
              },
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
                            color: AppColors.primaryGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.agriculture,
                            color: AppColors.primaryGreen,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: SmartReTranslator(
                                      text:
                                          farm['surveynumber']?.toString() ??
                                          'N/A',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isPending)
                                    Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.orange,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.cloud_upload,
                                            size: 12,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 4),
                                          SmartReTranslator(
                                            text: 'Pending',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.landscape,
                                    size: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                  const SizedBox(width: 4),
                                  SmartReTranslator(
                                    text:
                                        '${_formatNumber(farm['farmsize'])} Acres',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: Colors.grey.shade600,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(Icons.crop, size: 16, color: Colors.grey.shade600),
                        const SizedBox(width: 4),
                        SmartReTranslator(
                          text: '${crops.length} Crops',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: usagePercentage > 90
                                ? Colors.red
                                : usagePercentage > 70
                                ? Colors.orange
                                : AppColors.successColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: SmartReTranslator(
                            text: '${usagePercentage.toStringAsFixed(0)}% Used',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 16),
                      Divider(color: Colors.grey.shade200, height: 1),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildAreaStat(
                                  'Total Area',
                                  '${totalFarmArea.toStringAsFixed(1)} Ac',
                                  Icons.landscape,
                                  AppColors.primaryGreen,
                                ),
                                _buildAreaStat(
                                  'Used',
                                  '${usedArea.toStringAsFixed(1)} Ac',
                                  Icons.crop,
                                  Colors.orange,
                                ),
                                _buildAreaStat(
                                  'Available',
                                  '${availableArea.toStringAsFixed(1)} Ac',
                                  Icons.check_circle,
                                  Colors.green,
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const SmartReTranslator(
                                      text: 'Land Usage',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${usagePercentage.toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: usagePercentage > 90
                                            ? Colors.red
                                            : AppColors.primaryGreen,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: usagePercentage / 100,
                                    backgroundColor: Colors.grey.shade200,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      usagePercentage > 90
                                          ? Colors.red
                                          : usagePercentage > 70
                                          ? Colors.orange
                                          : AppColors.primaryGreen,
                                    ),
                                    minHeight: 8,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (farm['soil_types'] != null ||
                          farm['irrigation_types'] != null ||
                          farm['water_sources'] != null) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (farm['soil_types'] != null)
                              _buildChip(
                                Icons.terrain,
                                farm['soil_types'] as String,
                              ),
                            if (farm['irrigation_types'] != null)
                              _buildChip(
                                Icons.water_drop,
                                farm['irrigation_types'] as String,
                              ),
                            if (farm['water_sources'] != null)
                              _buildChip(
                                Icons.water,
                                farm['water_sources'] as String,
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: () => _editFarm(farm),
                          icon: const Icon(Icons.edit, size: 18),
                          label: const SmartReTranslator(
                            text: 'Edit Farm',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.primaryGreen,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUniformStatItem({
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
          textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildAreaStat(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        SmartReTranslator(
          text: label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
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
            child: SmartReTranslator(
              text: text,
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

// ==================== CROPS MANAGER TAB ====================

class CropsManagerTab extends StatefulWidget {
  final VoidCallback onDataChanged; // ADDED: Callback for data changes

  const CropsManagerTab({super.key, required this.onDataChanged});

  @override
  State<CropsManagerTab> createState() => _CropsManagerTabState();
}

class _CropsManagerTabState extends State<CropsManagerTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _crops = [];
  bool _isLoading = true;
  String? _error;
  int _pendingCount = 0;
  String? _expandedCropId;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadCrops();
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

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final token = await _getAccessToken();
      if (token == null) throw Exception('Not authenticated');

      await CropCareSyncService.instance.performFullSync(token);
      final db = DatabaseHelper.instance;
      final cropsList = await db.getAllCrops();
      final pending = await db.getPendingCrops();
      setState(() {
        _crops = cropsList;
        _pendingCount = pending.length;
        _isLoading = false;
      });
    } catch (e) {
      try {
        final db = DatabaseHelper.instance;
        final cropsList = await db.getAllCrops();
        final pending = await db.getPendingCrops();
        setState(() {
          _crops = cropsList;
          _pendingCount = pending.length;
          _isLoading = false;
          _error = 'Using offline data: ${e.toString()}';
        });
        return;
      } catch (_) {}
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _addCrop() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddCropScreen()),
    ).then((added) {
      // UPDATED: Call callback to refresh both tabs
      if (added == true) widget.onDataChanged();
    });
  }

  void _editCrop(Map<String, dynamic> crop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCropScreen(crop: crop)),
    ).then((updated) {
      // UPDATED: Call callback to refresh both tabs
      if (updated == true) widget.onDataChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Syncing crops...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    if (_error != null && _crops.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.errorColor),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Error loading crops',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCrops,
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
      );
    }

    final totalArea = _crops.fold(
      0.0,
      (sum, c) => sum + _toDouble(c['fieldsize']),
    );
    final activeCrops = _crops.where((c) => c['isactive'] == 1).length;
    final inactiveCrops = _crops.length - activeCrops;

    final uniqueFarms = _crops
        .map((c) => c['farmid']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet()
        .length;

    return CustomScrollView(
      slivers: [
        if (_pendingCount > 0)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_upload,
                    color: Colors.orange.shade700,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SmartReTranslator(
                      text: '$_pendingCount crop(s) pending sync',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onDataChanged, // UPDATED: Use callback
                    child: const SmartReTranslator(
                      text: 'Sync now',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_error != null && _crops.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.cloud_off, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: SmartReTranslator(
                      text: 'Offline mode - showing local data',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_crops.isNotEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryGreen,
                    AppColors.primaryGreen.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.eco,
                          label: 'Total Crops',
                          value: _crops.length.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.landscape,
                          label: 'Total Area',
                          value: '${totalArea.toStringAsFixed(1)} Ac',
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.agriculture,
                          label: 'Farms',
                          value: uniqueFarms.toString(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(height: 1, color: Colors.white.withOpacity(0.3)),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.check_circle,
                          label: 'Active',
                          value: activeCrops.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.pause_circle_outline,
                          label: 'Inactive',
                          value: inactiveCrops.toString(),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 60,
                        color: Colors.white.withOpacity(0.3),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      Expanded(
                        child: _buildUniformStatItem(
                          icon: Icons.cloud_upload,
                          label: 'Pending',
                          value: _pendingCount.toString(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        if (_crops.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                return _buildCropCard(_crops[index]);
              }, childCount: _crops.length),
            ),
          ),
        if (_crops.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.eco, size: 100, color: Colors.grey.shade300),
                    const SizedBox(height: 24),
                    const SmartReTranslator(
                      text: 'No Crops Found',
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
                          'You haven\'t added any crops yet. Start tracking your crops by adding them to your farms.',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: _addCrop,
                      icon: const Icon(Icons.add, color: Colors.white),
                      label: const SmartReTranslator(
                        text: 'Add Your First Crop',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // Keep _buildCropCard, _buildUniformStatItem, and _buildChip unchanged...
  // (Same as previous code - too long to repeat here, but they remain identical)

  Widget _buildCropCard(Map<String, dynamic> crop) {
    final isActive = crop['isactive'] == 1;
    final isPending = (crop['isdirty'] == 1 || crop['isuploaded'] == 0);
    final statusColor = isActive ? AppColors.successColor : Colors.orange;
    final cropId = crop['usercropid']?.toString() ?? '';
    final isExpanded = _expandedCropId == cropId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: isPending
            ? Border.all(color: Colors.orange.shade300, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            setState(() {
              _expandedCropId = isExpanded ? null : cropId;
            });
          },
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
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.eco, color: statusColor, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: SmartReTranslator(
                                  text:
                                      crop['plant_name']?.toString() ??
                                      'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isPending)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.cloud_upload,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      SmartReTranslator(
                                        text: 'Pending',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (crop['croptype'] != null) ...[
                            const SizedBox(height: 4),
                            SmartReTranslator(
                              text: crop['croptype'] as String,
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
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: Colors.grey.shade600,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.crop, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    SmartReTranslator(
                      text: '${_formatNumber(crop['fieldsize'])} Acres',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: SmartReTranslator(
                        text: isActive ? 'Active' : 'Inactive',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (isExpanded) ...[
                  const SizedBox(height: 16),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChip(
                        Icons.calendar_today,
                        crop['plantingdate']?.toString() ?? 'No planting date',
                      ),
                      if (crop['harvestdate'] != null)
                        _buildChip(
                          Icons.event_available,
                          crop['harvestdate'].toString(),
                        ),
                      if (crop['surveynumber'] != null)
                        _buildChip(
                          Icons.location_on,
                          crop['surveynumber'] as String,
                        ),
                      if (crop['soiltype'] != null)
                        _buildChip(Icons.terrain, crop['soiltype'] as String),
                      if (crop['status'] != null)
                        _buildChip(
                          Icons.info_outline,
                          crop['status'] as String,
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () => _editCrop(crop),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const SmartReTranslator(
                        text: 'Edit Crop',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUniformStatItem({
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
          textAlign: TextAlign.center,
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
          textAlign: TextAlign.center,
        ),
      ],
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
            child: SmartReTranslator(
              text: text,
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
