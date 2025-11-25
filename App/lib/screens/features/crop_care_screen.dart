// lib/screens/features/crop_care_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../utils/colors.dart';
import '../../src/services/crop_care_sync_service.dart';
import '../../src/database/database_helper.dart';
import '../shared/widgets/smart_retranslator.dart';
import 'add_farm_screen.dart';
import 'add_crop_screen.dart';

// No external file imports necessary for tabs; keep as below for in-file classes

class CropCareScreen extends StatefulWidget {
  const CropCareScreen({super.key});

  @override
  State<CropCareScreen> createState() => _CropCareScreenState();
}

class _CropCareScreenState extends State<CropCareScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // ADD THESE KEYS FOR REFRESH-TRIGGER
  final GlobalKey<_FarmsManagerTabState> _farmsTabKey = GlobalKey();
  final GlobalKey<_CropsManagerTabState> _cropsTabKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _refreshCurrentTab() {
    if (_tabController.index == 0) {
      _farmsTabKey.currentState?._loadFarms();
    } else {
      _cropsTabKey.currentState?._loadCrops();
    }
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
              icon: Icon(Icons.agriculture, size: 20),
              child: SmartReTranslator(
                text: 'Farms',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            Tab(
              icon: Icon(Icons.eco, size: 20),
              child: SmartReTranslator(
                text: 'Crops',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
              MaterialPageRoute(builder: (context) => const AddFarmScreen()),
            );
            // result should only be true if a farm was added/edited/deleted
            changed = result == true;
            if (changed) _farmsTabKey.currentState?._loadFarms();
          } else {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddCropScreen()),
            );
            // result should only be true if a crop was added/edited/deleted
            changed = result == true;
            if (changed) _cropsTabKey.currentState?._loadCrops();
          }
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          FarmsManagerTab(key: _farmsTabKey),
          CropsManagerTab(key: _cropsTabKey),
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
        // UPDATED: Also refresh active tab on successful sync
        _refreshCurrentTab();
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
  const FarmsManagerTab({super.key});

  @override
  State<FarmsManagerTab> createState() => _FarmsManagerTabState();
}

class _FarmsManagerTabState extends State<FarmsManagerTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _farms = [];
  bool _isLoading = true;
  String? _error;
  int _pendingCount = 0;

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
      if (added == true) _loadFarms();
    });
  }

  void _editFarm(Map<String, dynamic> farm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFarmScreen(farm: farm)),
    ).then((updated) {
      if (updated == true) _loadFarms();
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
              text: 'Syncing farms...',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
              onPressed: _loadFarms,
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
                    child: Text(
                      '$_pendingCount farm(s) pending sync',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadFarms,
                    child: const Text('Sync now'),
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
                    child: Text(
                      'Offline mode - showing local data',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_farms.isNotEmpty)
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
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.agriculture,
                      label: 'Total Farms',
                      value: _farms.length.toString(),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.landscape,
                      label: 'Total Area',
                      value: '${totalArea.toStringAsFixed(1)} Ac',
                    ),
                  ),
                ],
              ),
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

  Widget _buildFarmCard(Map<String, dynamic> farm) {
    final isPending = (farm['isdirty'] == 1 || farm['isuploaded'] == 0);

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
          onTap: () => _editFarm(farm),
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
                                child: Text(
                                  farm['surveynumber']?.toString() ?? 'N/A',
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
                                      Text(
                                        'Pending',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
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
                              Text(
                                '${_formatNumber(farm['farmsize'])} Acres',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _editFarm(farm),
                      color: Colors.grey.shade600,
                      icon: const Icon(Icons.arrow_forward_ios, size: 16),
                    ),
                  ],
                ),
                if (farm['soil_type'] != null ||
                    farm['irrigation'] != null ||
                    farm['water_source'] != null)
                  const SizedBox(height: 16),
                if (farm['soil_type'] != null ||
                    farm['irrigation'] != null ||
                    farm['water_source'] != null)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (farm['soil_type'] != null)
                        _buildChip(Icons.terrain, farm['soil_type'] as String),
                      if (farm['irrigation'] != null)
                        _buildChip(
                          Icons.water_drop,
                          farm['irrigation'] as String,
                        ),
                      if (farm['water_source'] != null)
                        _buildChip(Icons.water, farm['water_source'] as String),
                    ],
                  ),
              ],
            ),
          ),
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
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CROPS MANAGER TAB ====================

class CropsManagerTab extends StatefulWidget {
  const CropsManagerTab({super.key});

  @override
  State<CropsManagerTab> createState() => _CropsManagerTabState();
}

class _CropsManagerTabState extends State<CropsManagerTab>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _crops = [];
  bool _isLoading = true;
  String? _error;
  int _pendingCount = 0;

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
      if (token == null) {
        throw Exception('Not authenticated');
      }

      debugPrint('🔄 Starting crop sync...');

      final syncResult = await CropCareSyncService.instance.performFullSync(
        token,
      );
      debugPrint('📊 Sync result: $syncResult');

      final db = DatabaseHelper.instance;
      final cropsList = await db.getAllCrops();
      final pending = await db.getPendingCrops();

      debugPrint(
        '✅ Loaded ${cropsList.length} crops (${pending.length} pending)',
      );

      setState(() {
        _crops = cropsList;
        _pendingCount = pending.length;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ Error loading crops: $e');

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
      if (added == true) _loadCrops();
    });
  }

  void _editCrop(Map<String, dynamic> crop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCropScreen(crop: crop)),
    ).then((updated) {
      if (updated == true) _loadCrops();
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
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _loadCrops,
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

    final activeCrops = _crops.where((c) => c['isactive'] == 1).length;
    final totalArea = _crops.fold(
      0.0,
      (sum, c) => sum + _toDouble(c['fieldsize']),
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
                    child: Text(
                      '$_pendingCount crop(s) pending sync',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadCrops,
                    child: const Text('Sync now'),
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
                    child: Text(
                      'Offline mode - showing local data',
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
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
                    AppColors.successColor,
                    AppColors.successColor.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.successColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatItem(
                      icon: Icons.eco,
                      label: 'Active Crops',
                      value: activeCrops.toString(),
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
                      value: '${totalArea.toStringAsFixed(1)} Ac',
                    ),
                  ),
                ],
              ),
            ),
          ),
        _crops.isEmpty
            ? SliverFillRemaining(
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
                    final crop = _crops[index];
                    return _buildCropCard(crop);
                  }, childCount: _crops.length),
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

  Widget _buildCropCard(Map<String, dynamic> crop) {
    final isActive = crop['isactive'] == 1;
    final isPending = (crop['isdirty'] == 1 || crop['isuploaded'] == 0);
    final statusColor = isActive ? AppColors.successColor : Colors.orange;

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
          onTap: () => _editCrop(crop),
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
                                child: Text(
                                  crop['plant_name']?.toString() ?? 'Unknown',
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
                                      Text(
                                        'Pending',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
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
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isActive ? 'Active' : 'Inactive',
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
                      '${_formatNumber(crop['fieldsize'])} Acres',
                    ),
                    if (crop['plantingdate'] != null)
                      _buildChip(
                        Icons.calendar_today,
                        crop['plantingdate'].toString(),
                      ),
                    if (crop['survey_number'] != null)
                      _buildChip(
                        Icons.location_on,
                        crop['survey_number'] as String,
                      ),
                  ],
                ),
              ],
            ),
          ),
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
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
