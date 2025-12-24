import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../../utils/colors.dart';
import '../../../src/services/crop_care_sync_service.dart';
import '../../../src/database/database_helper.dart';
import '../../shared/smart_retranslator.dart';
import '../../shared/custom_app_bar.dart';
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

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _syncCropCareIfOnline();
  }

  Future<void> _syncCropCareIfOnline() async {
    // 1) Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    if (!isOnline) return;

    // 2) Read access token (same key you use elsewhere)
    final token = await _storage.read(key: 'accesstoken');
    if (token == null || token.isEmpty) return;

    // 3) Run Crop Care sync only
    final result = await CropCareSyncService.instance.performFullSync(token);

    // 4) If success, refresh both tabs from local DB
    if (result['success'] == true) {
      _cropsTabKey.currentState?._loadCrops();
      _farmsTabKey.currentState?._loadFarms();
    }
  }

  void _refreshBothTabs() {
    _cropsTabKey.currentState?._loadCrops();
    _farmsTabKey.currentState?._loadFarms();

    _syncCropCareOnChange();
  }

Future<void> _syncCropCareOnChange() async {
    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult != ConnectivityResult.none;
    if (!isOnline) return;

    // Get token
    final token = await _storage.read(key: 'accesstoken');
    if (token == null || token.isEmpty) return;

    // Sync Crop Care only
    final result = await CropCareSyncService.instance.performFullSync(token);

    // If success, refresh lists from local DB
    if (result['success'] == true) {
      _cropsTabKey.currentState?._loadCrops();
      _farmsTabKey.currentState?._loadFarms();
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
      // ✅ CustomAppBar WITHOUT TabBar
      appBar: CustomAppBar(
        title: 'Crop Care Manager',
        showOnlineStatus: true,
        showLanguageSwitcher: false,
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
          if (changed) _refreshBothTabs();
        },
        backgroundColor: AppColors.primaryGreen,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          // ✅ TabBar BELOW AppBar
          Container(
            color: AppColors.primaryGreen,
            child: TabBar(
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
          // ✅ TabBarView takes remaining space
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                CropsManagerTab(
                  key: _cropsTabKey,
                  onDataChanged: _refreshBothTabs,
                ),
                FarmsManagerTab(
                  key: _farmsTabKey,
                  onDataChanged: _refreshBothTabs,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== CROPS MANAGER TAB ====================

class CropsManagerTab extends StatefulWidget {
  final VoidCallback onDataChanged;

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

  Future<void> _loadCrops() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final db = DatabaseHelper.instance;
      final allCrops = await db.getAllCrops();
      final activeCrops = allCrops
          .where((crop) => crop['isactive'] == 1)
          .toList();
      final pending = await db.getPendingCrops();

      setState(() {
        _crops = activeCrops;
        _pendingCount = pending.length;
        _isLoading = false;
      });

      final token = await _getAccessToken();
      if (token != null) {
        CropCareSyncService.instance
            .performFullSync(token)
            .then((result) {
              if (result['success'] == true && mounted) {
                _refreshDataSilently();
              }
            })
            .catchError((e) {
              debugPrint('⚠️ Background sync error: $e');
            });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final db = DatabaseHelper.instance;
      final allCrops = await db.getAllCrops();
      final activeCrops = allCrops
          .where((crop) => crop['isactive'] == 1)
          .toList();
      final pending = await db.getPendingCrops();

      if (mounted) {
        setState(() {
          _crops = activeCrops;
          _pendingCount = pending.length;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Silent refresh error: $e');
    }
  }

  void _editCrop(Map<String, dynamic> crop) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCropScreen(crop: crop)),
    ).then((updated) {
      if (updated == true) widget.onDataChanged();
    });
  }

  Future<void> _deactivateCrop(Map<String, dynamic> crop) async {
    final cropId = crop['usercropid'].toString();
    final plantName =
        crop['plantname']?.toString() ??
        crop['plant_name']?.toString() ??
        'this crop';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartReTranslator(
          text: 'Deactivate Crop?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SmartReTranslator(
          text:
              'Are you sure you want to deactivate $plantName? It will be hidden from the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SmartReTranslator(text: 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const SmartReTranslator(text: 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = DatabaseHelper.instance;
      await db.updateCropActiveStatus(cropId: cropId, isActive: 0);
      debugPrint('✅ Crop $cropId deactivated');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: SmartReTranslator(
              text: 'Crop deactivated and hidden from list',
            ),
            backgroundColor: Colors.orange,
          ),
        );
        _loadCrops();
      }
    } catch (e) {
      debugPrint('❌ Error deactivating crop: $e');
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
    super.build(context);

    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            const SizedBox(height: 16),
            const SmartReTranslator(
              text: 'Loading crops...',
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

    final totalAcres = _crops.fold(
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
                    onPressed: widget.onDataChanged,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    icon: Icons.eco,
                    label: 'Active Crops',
                    value: _crops.length.toString(),
                  ),
                  Container(
                    width: 1,
                    height: 60,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  _buildStatItem(
                    icon: Icons.landscape,
                    label: 'Total Area',
                    value: '${totalAcres.toStringAsFixed(1)} Ac',
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
                          text: 'No Active Crops',
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
                              'You haven\'t added any active crops yet. Start by creating your first crop.',
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
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddCropScreen(),
                              ),
                            );
                            if (result == true) widget.onDataChanged();
                          },
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

  Widget _buildCropCard(Map<String, dynamic> crop) {
    final isPending = (crop['isdirty'] == 1 || crop['isuploaded'] == 0);

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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.successColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.eco,
                    color: AppColors.successColor,
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
                InkWell(
                  onTap: () => _deactivateCrop(crop),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.successColor,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const SmartReTranslator(
                      text: 'Active',
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
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.crop_landscape,
                                  size: 14,
                                  color: AppColors.primaryGreen,
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
                  Row(
                    children: [
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
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _editCrop(crop),
                icon: const Icon(Icons.edit, size: 16),
                label: const SmartReTranslator(
                  text: 'Edit',
                  style: TextStyle(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
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

// ==================== FARMS MANAGER TAB ====================

class FarmsManagerTab extends StatefulWidget {
  final VoidCallback onDataChanged;

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
      final db = DatabaseHelper.instance;
      final farmsList = await db.getAllFarmsWithRelations();
      final pending = await db.getPendingFarms();

      setState(() {
        _farms = farmsList;
        _pendingCount = pending.length;
        _isLoading = false;
      });

      final token = await _getAccessToken();
      if (token != null) {
        CropCareSyncService.instance
            .performFullSync(token)
            .then((result) {
              if (result['success'] == true && mounted) {
                _refreshDataSilently();
              }
            })
            .catchError((e) {
              debugPrint('⚠️ Background sync error: $e');
            });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshDataSilently() async {
    try {
      final db = DatabaseHelper.instance;
      final farmsList = await db.getAllFarmsWithRelations();
      final pending = await db.getPendingFarms();

      if (mounted) {
        setState(() {
          _farms = farmsList;
          _pendingCount = pending.length;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Silent refresh error: $e');
    }
  }

  void _editFarm(Map<String, dynamic> farm) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddFarmScreen(farm: farm)),
    ).then((updated) {
      if (updated == true) widget.onDataChanged();
    });
  }

  Future<void> _deleteFarm(Map<String, dynamic> farm) async {
    final farmId = farm['farmid'].toString();
    final surveyNumber = farm['surveynumber']?.toString() ?? 'this farm';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const SmartReTranslator(
          text: 'Delete Farm?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SmartReTranslator(
          text:
              'Are you sure you want to delete farm $surveyNumber? This will also delete all associated crops.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const SmartReTranslator(text: 'Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorColor),
            child: const SmartReTranslator(text: 'Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final db = DatabaseHelper.instance;
      final result = await db.markFarmAsDeleted(farmId);

      if (result['success'] == true) {
        debugPrint('✅ Farm deletion: ${result['message']}');

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SmartReTranslator(
                text: result['message'] ?? 'Farm deleted',
              ),
              backgroundColor: Colors.red,
            ),
          );
          widget.onDataChanged();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: SmartReTranslator(
                text: result['message'] ?? 'Failed to delete farm',
              ),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error deleting farm: $e');
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

  Future<Map<String, dynamic>> _calculateFarmStatistics() async {
    int totalCrops = 0;
    double totalUsedArea = 0.0;
    final totalArea = _farms.fold(
      0.0,
      (sum, f) => sum + _toDouble(f['farmsize']),
    );

    for (var farm in _farms) {
      final farmId = farm['farmid']?.toString() ?? '';
      final allCrops = await DatabaseHelper.instance.getCropsByFarmId(farmId);
      final activeCrops = allCrops
          .where((crop) => crop['isactive'] == 1)
          .toList();

      totalCrops += activeCrops.length;
      totalUsedArea += activeCrops.fold(
        0.0,
        (sum, crop) => sum + _toDouble(crop['fieldsize']),
      );
    }

    final availableArea = totalArea - totalUsedArea;
    final avgUtilization = totalArea > 0
        ? (totalUsedArea / totalArea) * 100
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
              text: 'Loading farms...',
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
                    onPressed: widget.onDataChanged,
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
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddFarmScreen(),
                              ),
                            );
                            if (result == true) widget.onDataChanged();
                          },
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

  Widget _buildFarmCard(Map<String, dynamic> farm) {
    final farmId = farm['farmid']?.toString() ?? '';
    final isPending = (farm['isdirty'] == 1 || farm['isuploaded'] == 0);

    final soilTypes = (farm['soil_types'] as List<dynamic>?) ?? [];
    final irrigations = (farm['irrigations'] as List<dynamic>?) ?? [];
    final waterSources = (farm['water_sources'] as List<dynamic>?) ?? [];

    final soilTypeNames = soilTypes
        .map((s) => s['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    final irrigationNames = irrigations
        .map((i) => i['methodname']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    final waterSourceNames = waterSources
        .map((w) => w['source']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getCropsByFarmId(farmId),
      builder: (context, snapshot) {
        final allCrops = snapshot.data ?? [];
        final activeCrops = allCrops
            .where((crop) => crop['isactive'] == 1)
            .toList();

        final totalFarmArea = _toDouble(farm['farmsize']);
        final usedArea = activeCrops.fold(
          0.0,
          (sum, crop) => sum + _toDouble(crop['fieldsize']),
        );
        final usagePercentage = totalFarmArea > 0
            ? (usedArea / totalFarmArea * 100).clamp(0, 100)
            : 0.0;

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
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.agriculture,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            farm['surveynumber']?.toString() ?? 'N/A',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Icon(
                                Icons.landscape,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${_formatNumber(farm['farmsize'])} ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SmartReTranslator(
                                text: 'Ac',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.eco,
                                size: 14,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${activeCrops.length} ',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SmartReTranslator(
                                text: 'Crops',
                                style: TextStyle(
                                  fontSize: 13,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: usagePercentage >= 90
                            ? Colors.red
                            : usagePercentage >= 70
                            ? Colors.orange
                            : AppColors.successColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${usagePercentage.toStringAsFixed(0)}%',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                if (soilTypeNames.isNotEmpty ||
                    irrigationNames.isNotEmpty ||
                    waterSourceNames.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (soilTypeNames.isNotEmpty)
                          _buildCompactInfo(
                            Icons.terrain,
                            soilTypeNames,
                            Colors.brown.shade700,
                          ),
                        if (soilTypeNames.isNotEmpty &&
                            irrigationNames.isNotEmpty)
                          const SizedBox(height: 6),
                        if (irrigationNames.isNotEmpty)
                          _buildCompactInfo(
                            Icons.water_drop,
                            irrigationNames,
                            Colors.blue.shade700,
                          ),
                        if (irrigationNames.isNotEmpty &&
                            waterSourceNames.isNotEmpty)
                          const SizedBox(height: 6),
                        if (waterSourceNames.isNotEmpty)
                          _buildCompactInfo(
                            Icons.water,
                            waterSourceNames,
                            Colors.cyan.shade700,
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton.icon(
                      onPressed: () => _editFarm(farm),
                      icon: const Icon(Icons.edit, size: 16),
                      label: const SmartReTranslator(
                        text: 'Edit',
                        style: TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () => _deleteFarm(farm),
                      icon: const Icon(Icons.delete, size: 16),
                      label: const SmartReTranslator(
                        text: 'Delete',
                        style: TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.errorColor,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompactInfo(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
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
}
