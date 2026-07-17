import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;
import '../../utils/colors.dart';
import '../../src/services/sync_service.dart';
import '../../src/services/crop_care_sync_service.dart';
import '../../src/services/auth_service.dart';
import '../../src/database/database_helper.dart';
import '../shared/smart_retranslator.dart';

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
    _preloadPhrases();
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

  // ✅ NEW: Preload translations
  Future<void> _preloadPhrases() async {
    // Translation preloading can be added here if needed
    // For now, SmartReTranslator handles it automatically
  }

  Future<void> _performSync() async {
    setState(() {
      _phase = UpdatePhase.syncing;
      _syncStatus = 'Preparing to sync...';
      _syncProgress = 0.1;
    });

    try {
      // ✅ Use AuthService to get valid token (it handles refresh automatically)
      final accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        // Try to refresh token
        try {
          await _authService.refreshAccessToken();
          final newToken = await _storage.read(key: 'access_token');

          if (newToken == null || newToken.isEmpty) {
            setState(() {
              _phase = UpdatePhase.syncFailed;
              _syncStatus = 'Authentication failed';
            });
            return;
          }
        } catch (e) {
          setState(() {
            _phase = UpdatePhase.syncFailed;
            _syncStatus = 'Authentication failed';
          });
          return;
        }
      }

      final validToken = await _storage.read(key: 'access_token');

      setState(() {
        _syncStatus = 'Syncing disease analyses...';
        _syncProgress = 0.3;
      });

      // ✅ Sync disease analyses first
      final diseaseResult = await SyncService.instance.performFullSync(
        validToken!,
      );

      setState(() {
        _syncStatus = 'Syncing farms and crops...';
        _syncProgress = 0.6;
      });

      // ✅ Sync farms and crops
      final cropCareResult = await CropCareSyncService.instance.performFullSync(
        validToken,
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
          _syncStatus = 'Sync failed - please check your internet connection';
        });
      }
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      setState(() {
        _phase = UpdatePhase.syncFailed;
        _syncStatus = 'An error occurred during sync';
      });
    }
  }

  Future<void> _launchUpdate() async {
    final storeUrl = widget.config['store_url'] ?? '';
    if (storeUrl.isNotEmpty) {
      final uri = Uri.parse(storeUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const SmartReTranslator(
                text: 'Could not open app store',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: AppColors.errorColor,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
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
      debugPrint('❌ Error dropping database: $e');
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
    return PopScope(
      canPop: false, // ✅ Updated from WillPopScope
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
          child: const Icon(
            Icons.sync_rounded,
            size: 64,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Update Available',
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
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primaryGreen, size: 24),
              SizedBox(width: 12),
              Expanded(
                child: SmartReTranslator(
                  text:
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
        SmartReTranslator(
          text:
              widget.config['update_message'] ??
              'A new version is available with improvements and bug fixes.',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
                  valueColor: const AlwaysStoppedAnimation(
                    AppColors.primaryGreen,
                  ),
                ),
              ),
              Text(
                '${(_syncProgress * 100).toInt()}%',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Syncing Data',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SmartReTranslator(
          text: _syncStatus,
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.hourglass_empty,
                size: 16,
                color: AppColors.warningColor,
              ),
              SizedBox(width: 8),
              SmartReTranslator(
                text: 'Please wait, do not close the app',
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
          child: const Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: AppColors.successColor,
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Sync Complete!',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        const SmartReTranslator(
          text: 'Your data has been safely synced to the server.',
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
          child: const Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.errorColor,
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Sync Failed',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SmartReTranslator(
          text: _syncStatus.isNotEmpty
              ? _syncStatus
              : 'Unable to sync your data. Please check your internet connection and try again.',
          textAlign: TextAlign.center,
          style: const TextStyle(
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
          child: const Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: AppColors.warningColor,
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Data Loss Warning',
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
          child: const Column(
            children: [
              Icon(
                Icons.delete_forever_rounded,
                size: 40,
                color: AppColors.errorColor,
              ),
              SizedBox(height: 12),
              SmartReTranslator(
                text:
                    'Updating without syncing will permanently delete all offline data.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 8),
              SmartReTranslator(
                text: 'This action cannot be undone.',
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
          child: const Icon(
            Icons.system_update_rounded,
            size: 64,
            color: AppColors.primaryGreen,
          ),
        ),
        const SizedBox(height: 32),
        const SmartReTranslator(
          text: 'Ready to Update',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        SmartReTranslator(
          text:
              widget.config['update_message'] ??
              'A new version of Agrhi is available with improvements and new features.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return const Center(
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
                child: const SmartReTranslator(
                  text: 'Sync & Update',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipSync,
              child: const SmartReTranslator(
                text: 'Skip Sync (Not Recommended)',
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
                child: const SmartReTranslator(
                  text: 'Retry Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _skipSync,
              child: const SmartReTranslator(
                text: 'Continue Without Syncing',
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
                child: const SmartReTranslator(
                  text: 'Go Back & Sync',
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
                  side: const BorderSide(color: AppColors.errorColor, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const SmartReTranslator(
                  text: 'Delete Data & Update',
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
            child: const SmartReTranslator(
              text: 'Update Now',
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
