import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import 'dart:convert';
import '../../utils/colors.dart';
import '../../src/services/sync_service.dart';
import '../../src/services/crop_care_sync_service.dart';
import '../../src/services/auth_service.dart';
import '../../src/database/database_helper.dart';

class UpdateScreen extends StatefulWidget {
  final Map<String, dynamic> config;
  final bool hasUnsyncedData;

  const UpdateScreen({
    super.key,
    required this.config,
    required this.hasUnsyncedData,
  });

  @override
  State<UpdateScreen> createState() => _UpdateScreenState();
}

class _UpdateScreenState extends State<UpdateScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  final AuthService _authService = AuthService();

  UpdatePhase _phase = UpdatePhase.initial;
  double _syncProgress = 0.0;
  String _syncStatus = '';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
      synchronizable: false,
    ),
  );

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _determineInitialPhase();
  }

  void _setupAnimation() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
  }

  void _determineInitialPhase() {
    setState(() {
      _phase = widget.hasUnsyncedData
          ? UpdatePhase.syncRequired
          : UpdatePhase.readyToUpdate;
    });
  }

  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) {
          return value;
        }
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (e) {
        if (i == maxRetries - 1) {
          debugPrint('Storage read failed for $key: $e');
          rethrow;
        }
      }
    }
    return null;
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      String payload = parts[1];

      int mod4 = payload.length % 4;
      if (mod4 > 0) {
        payload += '=' * (4 - mod4);
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (e) {
      debugPrint('JWT decode error: $e');
      return null;
    }
  }

  DateTime? _getJwtExpiryUtc(String token) {
    final payload = _decodeJwtPayload(token);
    if (payload == null) return null;

    final exp = payload['exp'];

    if (exp is int) {
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } else if (exp is String) {
      final n = int.tryParse(exp);
      if (n != null) {
        return DateTime.fromMillisecondsSinceEpoch(n * 1000, isUtc: true);
      }
    }

    return null;
  }

  Future<String?> _getValidAccessToken() async {
    String? accessToken =
        await _readWithRetry('access_token') ??
        await _storage.read(key: 'access_token');

    String? expiryIso =
        await _readWithRetry('access_token_expires_at') ??
        await _storage.read(key: 'access_token_expires_at');

    String? expiryEpochMsStr =
        await _readWithRetry('access_token_expiry') ??
        await _storage.read(key: 'access_token_expiry');

    bool isExpired = false;
    final now = DateTime.now().toUtc();
    const skew = Duration(seconds: 60);

    if (accessToken != null && accessToken.isNotEmpty) {
      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        isExpired = now.add(skew).isAfter(jwtExp);
      } else {
        try {
          if (expiryIso != null && expiryIso.isNotEmpty) {
            final exp = DateTime.tryParse(expiryIso)?.toUtc();
            if (exp != null) isExpired = now.add(skew).isAfter(exp);
          } else if (expiryEpochMsStr != null && expiryEpochMsStr.isNotEmpty) {
            final ms = int.tryParse(expiryEpochMsStr);
            if (ms != null) {
              final exp = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
              isExpired = now.add(skew).isAfter(exp);
            }
          } else {
            isExpired = false;
          }
        } catch (_) {
          isExpired = true;
        }
      }
    } else {
      isExpired = true;
    }

    if (!isExpired && accessToken != null && accessToken.isNotEmpty) {
      return accessToken;
    }

    try {
      await _authService.refreshAccessToken();
      accessToken =
          await _readWithRetry('access_token') ??
          await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('Token refresh succeeded but no access_token found');
        return null;
      }

      final jwtExp = _getJwtExpiryUtc(accessToken);
      if (jwtExp != null) {
        final stillExpired = now.add(skew).isAfter(jwtExp);
        return stillExpired ? null : accessToken;
      }

      return accessToken;
    } catch (e) {
      debugPrint('Failed to refresh access token: $e');
      return null;
    }
  }

  Future<void> _performSync() async {
    setState(() {
      _phase = UpdatePhase.syncing;
      _syncStatus = 'Preparing to sync...';
      _syncProgress = 0.1;
    });

    try {
      final accessToken = await _getValidAccessToken();

      if (accessToken == null) {
        setState(() {
          _phase = UpdatePhase.syncFailed;
          _syncStatus = 'Authentication failed';
        });
        return;
      }

      setState(() {
        _syncStatus = 'Syncing farms and crops...';
        _syncProgress = 0.3;
      });

      final diseaseResult = await SyncService.instance.performFullSync(
        accessToken,
      );

      setState(() {
        _syncStatus = 'Syncing disease analyses...';
        _syncProgress = 0.6;
      });

      final cropCareResult = await CropCareSyncService.instance.performFullSync(
        accessToken,
      );

      if (diseaseResult['success'] == true &&
          cropCareResult['success'] == true) {
        setState(() {
          _syncStatus = 'Cleaning up database...';
          _syncProgress = 0.9;
        });

        // Drop database
        await DatabaseHelper.instance.close();
        final dbPath = await getDatabasesPath();
        final path = join(dbPath, 'agrhi_offline.db');
        await deleteDatabase(path);

        setState(() {
          _syncProgress = 1.0;
          _phase = UpdatePhase.syncComplete;
          _syncStatus = 'Sync complete!';
        });

        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          setState(() => _phase = UpdatePhase.readyToUpdate);
        }
      } else {
        setState(() {
          _phase = UpdatePhase.syncFailed;
          _syncStatus = 'Sync failed';
        });
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      setState(() {
        _phase = UpdatePhase.syncFailed;
        _syncStatus = 'An error occurred';
      });
    }
  }

  Future<void> _launchUpdate() async {
    final storeUrl = widget.config['store_url'] ?? '';
    if (storeUrl.isNotEmpty) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  void _skipSync() {
    setState(() => _phase = UpdatePhase.dataLossWarning);
  }

  Future<void> _proceedWithoutSync() async {
    try {
      // Drop database without syncing
      await DatabaseHelper.instance.close();
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, 'agrhi_offline.db');
      await deleteDatabase(path);

      if (mounted) {
        setState(() => _phase = UpdatePhase.readyToUpdate);
      }
    } catch (e) {
      debugPrint('Error dropping database: $e');
      if (mounted) {
        setState(() => _phase = UpdatePhase.readyToUpdate);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: AppColors.backgroundColor,
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Spacer(),
                  _buildContent(),
                  const Spacer(),
                  _buildActions(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_phase) {
      case UpdatePhase.initial:
        return _buildLoadingState();
      case UpdatePhase.syncRequired:
        return _buildSyncRequiredState();
      case UpdatePhase.syncing:
        return _buildSyncingState();
      case UpdatePhase.syncComplete:
        return _buildSyncCompleteState();
      case UpdatePhase.syncFailed:
        return _buildSyncFailedState();
      case UpdatePhase.dataLossWarning:
        return _buildDataLossWarningState();
      case UpdatePhase.readyToUpdate:
        return _buildReadyToUpdateState();
    }
  }

  Widget _buildSyncRequiredState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.sync_rounded,
            size: 64,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Update Available',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryGreen.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You have offline data that needs to be synced before updating.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          widget.config['update_message'] ??
              'A new version is available with improvements and bug fixes.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: _syncProgress,
                  strokeWidth: 6,
                  backgroundColor: AppColors.primaryGreen.withOpacity(0.2),
                  valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
                ),
              ),
              Text(
                '${(_syncProgress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Syncing Data',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _syncStatus,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.warningColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: AppColors.warningColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Please wait, do not close the app',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.warningColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSyncCompleteState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.successColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: AppColors.successColor,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Sync Complete!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your data has been safely synced to the server.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncFailedState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.errorColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.errorColor,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Sync Failed',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Unable to sync your data. Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildDataLossWarningState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.warningColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: AppColors.warningColor,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Data Loss Warning',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.errorColor,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.errorColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.errorColor.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delete_forever_rounded,
                size: 40,
                color: AppColors.errorColor,
              ),
              const SizedBox(height: 12),
              Text(
                'Updating without syncing will permanently delete all offline data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReadyToUpdateState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.primaryGreen.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.system_update_rounded,
            size: 64,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Ready to Update',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.config['update_message'] ??
              'A new version of Agrhi is available with improvements and new features.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
      ),
    );
  }

  Widget _buildActions() {
    switch (_phase) {
      case UpdatePhase.syncRequired:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _performSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.primaryWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 2,
                ),
                child: const Text(
                  'Sync & Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipSync,
              child: Text(
                'Skip Sync (Not Recommended)',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ),
          ],
        );

      case UpdatePhase.syncing:
        return const SizedBox.shrink();

      case UpdatePhase.syncFailed:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _performSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.primaryWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Retry Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipSync,
              child: Text(
                'Continue Without Syncing',
                style: TextStyle(color: AppColors.errorColor, fontSize: 14),
              ),
            ),
          ],
        );

      case UpdatePhase.dataLossWarning:
        return Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _performSync,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  foregroundColor: AppColors.primaryWhite,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Go Back & Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton(
                onPressed: _proceedWithoutSync,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.errorColor,
                  side: BorderSide(color: AppColors.errorColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Delete Data & Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );

      case UpdatePhase.readyToUpdate:
        return SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _launchUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              foregroundColor: AppColors.primaryWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
            ),
            child: const Text(
              'Update Now',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}

enum UpdatePhase {
  initial,
  syncRequired,
  syncing,
  syncComplete,
  syncFailed,
  dataLossWarning,
  readyToUpdate,
}
