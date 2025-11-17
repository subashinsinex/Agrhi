// lib/screens/features/disease_detection_screen.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../src/services/disease_analysis_service.dart';
import '../../src/services/sync_service.dart';
import '../../src/models/model_service.dart';
import '../../src/models/crop_preprocessors.dart';
import '../../src/models/disease_labels.dart';
import '../../src/services/language_service.dart';
import '../../src/services/model_download_service.dart'; // ADD THIS
import '../shared/widgets/custom_app_bar.dart';
import '../../utils/colors.dart';

class DetectDiseaseScreen extends StatefulWidget {
  const DetectDiseaseScreen({super.key});

  @override
  State<DetectDiseaseScreen> createState() => _DetectDiseaseScreenState();
}

class _DetectDiseaseScreenState extends State<DetectDiseaseScreen>
    with TickerProviderStateMixin {
  // CHANGED: Now populated dynamically from downloaded models
  List<String> availableCrops = [];
  bool _isCheckingModels = true; // ADD THIS

  String? selectedCrop;
  String? imagePath;
  Uint8List? imageBytes;
  Map<String, dynamic>? result;
  bool _isLoading = false;
  bool _isModelLoading = false;
  double _analysisProgress = 0.0;

  final ImagePicker _picker = ImagePicker();
  late AnimationController _progressController;
  late AnimationController _resultController;

  Map<String, String> translatedTexts = {};
  String _currentLanguage = '';

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
    _progressController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // CHANGED: Check downloaded models first
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkDownloadedModels();
      _loadTranslations();
    });
  }

  // NEW: Check which models are downloaded
  Future<void> _checkDownloadedModels() async {
    setState(() => _isCheckingModels = true);

    final downloadedModels = <String>[];

    for (final cropName in ModelDownloadService.modelInfo.keys) {
      final isDownloaded = await ModelDownloadService.instance
          .isModelDownloaded(cropName);
      if (isDownloaded) {
        downloadedModels.add(cropName);
      }
    }

    if (!mounted) return;

    if (downloadedModels.isEmpty) {
      _showNoModelsDialog();
      return;
    }

    setState(() {
      availableCrops = downloadedModels;
      _isCheckingModels = false;

      if (availableCrops.isNotEmpty) {
        selectedCrop = availableCrops.first;
        _loadModelForCrop(selectedCrop!);
      }
    });
  }

  // NEW: Show dialog and redirect to Model Manager
  void _showNoModelsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.download_outlined, color: AppColors.errorColor),
            const SizedBox(width: 12),
            const Text('No Models Downloaded'),
          ],
        ),
        content: const Text(
          'You need to download at least one AI model to use disease detection. '
          'Would you like to download models now?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              Navigator.pushNamed(context, '/model-manager');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Download Models'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final languageService = Provider.of<LanguageService>(context);
    if (_currentLanguage != languageService.currentLocale.languageCode) {
      _currentLanguage = languageService.currentLocale.languageCode;
      _loadTranslations();
    }
  }

  Future<String?> _readWithRetry(String key, {int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final value = await _storage.read(key: key);
        if (value != null && value.isNotEmpty) return value;
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(milliseconds: 100 * (i + 1)));
        }
      } catch (_) {
        if (i == maxRetries - 1) rethrow;
      }
    }
    return null;
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1];
      final mod4 = payload.length % 4;
      if (mod4 > 0) payload += '=' * (4 - mod4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded);
      if (map is Map<String, dynamic>) return map;
      if (map is Map) return Map<String, dynamic>.from(map);
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _readUserId() async {
    final direct = await _readWithRetry('user_id');
    if (direct != null && direct.isNotEmpty) return direct;

    final profileJson = await _readWithRetry('user_profile');
    if (profileJson != null && profileJson.isNotEmpty) {
      try {
        final map = jsonDecode(profileJson);
        if (map is Map) {
          final m = Map<String, dynamic>.from(map);
          final fromProfile = m['user_id']?.toString() ?? m['id']?.toString();
          if (fromProfile != null && fromProfile.isNotEmpty) return fromProfile;
        }
      } catch (_) {}
    }

    final token = await _readWithRetry('access_token');
    if (token != null && token.isNotEmpty) {
      final payload = _decodeJwtPayload(token);
      final fromJwt =
          payload?['sub']?.toString() ??
          payload?['user_id']?.toString() ??
          payload?['uid']?.toString();
      if (fromJwt != null && fromJwt.isNotEmpty) return fromJwt;
    }

    return null;
  }

  Future<void> _loadTranslations() async {
    final languageService = Provider.of<LanguageService>(
      context,
      listen: false,
    );

    final Map<String, String> keys = {
      'selectCrop': 'Select Crop',
      'selectACrop': 'Select a crop',
      'captureImage': 'Capture Image',
      'takePhoto': 'Take Photo',
      'chooseFromGallery': 'Choose From Gallery',
      'loadingAIModel': 'Loading AI model...',
      'removeImage': 'Remove image',
      'processingImage': 'Processing image data...',
      'runningDetection': 'Running disease detection...',
      'analyzingHealth': 'Analyzing crop health...',
      'generatingResults': 'Generating results...',
      'finalizingDiagnosis': 'Finalizing diagnosis...',
      'detectionResults': 'Detection Results',
      'diseaseLabel': 'Disease Label',
      'confidence': 'Confidence',
      'error': 'Error',
      'failedToLoadModel': 'Failed to load model for',
      'failedToPickImage': 'Failed to pick image',
      'analysisFailed': 'Analysis failed',
      'dismiss': 'Dismiss',
      'progress': 'Progress',
      'diseaseDetection': 'Disease Detection',
    };

    for (final crop in diseaseLabels.keys) {
      keys[crop.toLowerCase()] = crop;
      for (final label in diseaseLabels[crop] ?? []) {
        final key = label.replaceAll('_', ' ').toLowerCase();
        keys[key] = label.replaceAll('_', ' ');
      }
    }

    final translated = <String, String>{};
    final futures = <Future>[];
    for (final entry in keys.entries) {
      futures.add(
        languageService.translate(entry.value).then((tr) {
          translated[entry.key] = tr;
        }),
      );
    }
    await Future.wait(futures);

    if (!mounted) return;
    setState(() => translatedTexts = translated);
  }

  @override
  void dispose() {
    _progressController.dispose();
    _resultController.dispose();
    super.dispose();
  }

  Future<void> _loadModelForCrop(String cropName) async {
    setState(() => _isModelLoading = true);
    try {
      if (modelMap.containsKey(cropName)) {
        final modelPath = await modelMap[cropName]!();
        await ModelService.loadModel(modelPath);
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorSnackBar(
        '${translatedTexts['failedToLoadModel'] ?? 'Failed to load model for'} $cropName',
      );
    } finally {
      if (!mounted) return;
      setState(() => _isModelLoading = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isLoading || selectedCrop == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() {
        _isLoading = true;
        result = null;
        imagePath = picked.path;
        _analysisProgress = 0.0;
      });

      imageBytes = await picked.readAsBytes();
      _progressController
        ..reset()
        ..forward();

      await _analyzeImage(picked.path);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        result = {'label': 'Error', 'confidence': 0.0, 'error': e.toString()};
      });
      _showErrorSnackBar(
        '${translatedTexts['failedToPickImage'] ?? 'Failed to pick image'}: ${e.toString()}',
      );
    }
  }

  Future<void> _persistResultUsingPlant({
    required String plantName,
    required String detectedLabel,
    required double confidence0to1,
    required String localImagePath,
  }) async {
    const double healthyMinConfidence = 0.80;
    final isHealthy = detectedLabel.toLowerCase().contains('healthy');
    if (isHealthy && confidence0to1 >= healthyMinConfidence) return;

    final userId = await _readUserId();
    if (userId == null || userId.isEmpty) {
      _showErrorSnackBar('User not found in secure storage');
      return;
    }

    try {
      final saveResult = await DiseaseAnalysisService.instance
          .saveDetectionByPlantName(
            userId: userId,
            plantName: plantName,
            detectedLabel: detectedLabel,
            confidence: confidence0to1,
            localImagePath: localImagePath,
          );

      if (!mounted) return;

      if (saveResult['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.save, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Analysis saved - syncing to server...'),
                ),
              ],
            ),
            backgroundColor: AppColors.infoColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        await _triggerForcedSync();
      } else {
        _showErrorSnackBar('Save failed: ${saveResult['error']}');
      }
    } catch (e) {
      _showErrorSnackBar('Save failed: ${e.toString()}');
    }
  }

  Future<void> _triggerForcedSync() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ No access token - sync will happen later');
        return;
      }

      debugPrint('🔄 Triggering forced sync...');

      final syncResult = await SyncService.instance.performFullSync(
        accessToken,
      );

      final bool success = (syncResult['success'] as bool?) ?? false;

      if (success) {
        final twoWayResult =
            syncResult['two_way_sync'] as Map<String, dynamic>?;
        final uploaded = (twoWayResult?['upload']?['uploaded'] as int?) ?? 0;
        final imagesUploaded =
            (twoWayResult?['images']?['uploaded'] as int?) ?? 0;

        if (uploaded > 0 || imagesUploaded > 0) {
          debugPrint(
            '✅ Forced sync: uploaded $uploaded analyses, $imagesUploaded images',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.cloud_done, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Synced to server: $uploaded analysis, $imagesUploaded images',
                      ),
                    ),
                  ],
                ),
                backgroundColor: AppColors.successColor,
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        } else {
          debugPrint('ℹ️ No new data to upload');
        }
      } else {
        debugPrint('⚠️ Forced sync had issues: ${syncResult['error']}');
      }
    } catch (e) {
      debugPrint('❌ Forced sync error: $e');
    }
  }

  Future<void> _analyzeImage(String path) async {
    try {
      for (int i = 0; i <= 100; i += 5) {
        if (!mounted) return;
        setState(() => _analysisProgress = i / 100);
        await Future.delayed(const Duration(milliseconds: 175));
      }

      final preprocessor = preprocessMap[selectedCrop];
      final processedPath = preprocessor != null
          ? await preprocessor(path)
          : path;

      final cropName = selectedCrop!;
      final labels = diseaseLabels[cropName] ?? const ['Healthy', 'Unknown'];

      final outputs = await ModelService.runInference(
        processedPath,
        labels,
        cropName,
      );

      if (!mounted) return;
      final topResult = outputs.isNotEmpty
          ? outputs.first
          : {'label': 'Unknown', 'confidence': 0.0};

      setState(() {
        result = topResult;
        _analysisProgress = 1.0;
      });

      _resultController.forward();

      final hasError = topResult.containsKey('error');
      if (!hasError && path.isNotEmpty) {
        final label = (topResult['label'] ?? 'Unknown').toString();
        final conf = (topResult['confidence'] as num?)?.toDouble() ?? 0.0;
        await _persistResultUsingPlant(
          plantName: selectedCrop!,
          detectedLabel: label,
          confidence0to1: conf,
          localImagePath: path,
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = {'label': 'Error', 'confidence': 0.0, 'error': e.toString()};
      });
      _showErrorSnackBar(
        '${translatedTexts['analysisFailed'] ?? 'Analysis failed'}: ${e.toString()}',
      );
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14)),
            ),
          ],
        ),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: translatedTexts['dismiss'] ?? 'Dismiss',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  void _resetAnalysis() {
    setState(() {
      imagePath = null;
      imageBytes = null;
      result = null;
      _analysisProgress = 0.0;
    });
    _progressController.reset();
    _resultController.reset();
  }

  IconData _getCropIcon(String crop) {
    switch (crop.toLowerCase()) {
      case 'corn':
        return Icons.grain;
      case 'rice':
        return Icons.rice_bowl;
      case 'cotton':
        return Icons.agriculture;
      case 'banana':
        return Icons.food_bank;
      case 'coffee':
        return Icons.coffee;
      case 'tomato':
        return Icons.local_grocery_store;
      default:
        return Icons.eco;
    }
  }

  String _getTranslatedCropName(String crop) {
    final key = crop.toLowerCase();
    return translatedTexts[key] ?? crop;
  }

  String _getTranslatedLabel(String label) {
    final key = label.replaceAll('_', ' ').toLowerCase();
    return translatedTexts[key] ?? label.replaceAll('_', ' ');
  }

  Widget _buildCropAndCameraSection() {
    // NEW: Show loading while checking models
    if (_isCheckingModels) {
      return Card(
        elevation: 3,
        shadowColor: AppColors.primaryGreen.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Checking downloaded models...',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final isEnabled = selectedCrop != null && !_isLoading && !_isModelLoading;

    return Card(
      elevation: 3,
      shadowColor: AppColors.primaryGreen.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.agriculture,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    translatedTexts['selectCrop'] ?? 'Select Crop',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                // NEW: Add button to manage models
                TextButton.icon(
                  onPressed: () => Navigator.pushNamed(
                    context,
                    '/model-manager',
                  ).then((_) => _checkDownloadedModels()),
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Manage', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryGreen,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              width: double.infinity,
              decoration: BoxDecoration(
                color: _isModelLoading
                    ? AppColors.primaryGreen.withOpacity(0.05)
                    : Colors.transparent,
                border: Border.all(
                  color: AppColors.primaryGreen.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedCrop,
                  hint: Text(
                    // CHANGED: Show message if no models
                    availableCrops.isEmpty
                        ? 'No models downloaded'
                        : translatedTexts['selectACrop'] ?? 'Select a crop',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  isExpanded: true,
                  items: availableCrops
                      .map(
                        (crop) => DropdownMenuItem(
                          value: crop,
                          child: Row(
                            children: [
                              Icon(
                                _getCropIcon(crop),
                                color: AppColors.primaryGreen,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _getTranslatedCropName(crop),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  // CHANGED: Disable if checking or no models
                  onChanged: _isModelLoading || availableCrops.isEmpty
                      ? null
                      : (val) async {
                          if (val != null && val != selectedCrop) {
                            setState(() => selectedCrop = val);
                            await _loadModelForCrop(val);
                          }
                        },
                ),
              ),
            ),
            const SizedBox(height: 20),
            Divider(
              color: AppColors.primaryGreen.withOpacity(0.2),
              thickness: 1,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.camera_alt,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  translatedTexts['captureImage'] ?? 'Capture Image',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_camera, size: 20),
                      label: Flexible(
                        child: Text(
                          translatedTexts['takePhoto'] ?? 'Take Photo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: isEnabled
                          ? () => _pickImage(ImageSource.camera)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isEnabled
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withOpacity(0.5),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isEnabled ? 2 : 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.photo_library, size: 20),
                      label: Flexible(
                        child: Text(
                          translatedTexts['chooseFromGallery'] ??
                              'Choose From Gallery',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      onPressed: isEnabled
                          ? () => _pickImage(ImageSource.gallery)
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: isEnabled
                            ? AppColors.primaryGreen
                            : AppColors.primaryGreen.withOpacity(0.5),
                        side: BorderSide(
                          color: isEnabled
                              ? AppColors.primaryGreen
                              : AppColors.primaryGreen.withOpacity(0.5),
                          width: 2,
                        ),
                        minimumSize: const Size(double.infinity, 56),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: isEnabled ? 1 : 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!isEnabled && _isModelLoading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      translatedTexts['loadingAIModel'] ??
                          'Loading AI model...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Keep all your remaining widget builders (_buildImagePreview, _buildLoadingIndicator, _buildResults, etc.)
  // ... (continue with the rest of your original file)

  Widget _buildImagePreview() {
    return Card(
      elevation: 4,
      shadowColor: AppColors.primaryGreen.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Container(
            width: double.infinity,
            height: 280,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primaryGreen.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: imageBytes != null
                  ? Image.memory(
                      imageBytes!,
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                    )
                  : (imagePath != null
                        ? Image.file(
                            File(imagePath!),
                            width: double.infinity,
                            height: 280,
                            fit: BoxFit.cover,
                          )
                        : Container()),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                onPressed: _resetAnalysis,
                padding: const EdgeInsets.all(8),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: translatedTexts['removeImage'] ?? 'Remove image',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Card(
      elevation: 6,
      shadowColor: AppColors.primaryGreen.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withOpacity(0.95),
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return Transform.rotate(
                          angle: _progressController.value * 2 * math.pi,
                          child: Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryGreen.withOpacity(0.1),
                                width: 2,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _analysisProgress,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.primaryGreen,
                        ),
                        backgroundColor: AppColors.primaryGreen.withOpacity(
                          0.08,
                        ),
                      ),
                    ),
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withOpacity(0.1),
                      ),
                      child: const Icon(
                        Icons.biotech,
                        size: 24,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 600),
                child: Text(
                  _getStatusMessage(_analysisProgress),
                  key: ValueKey(_getStatusMessage(_analysisProgress)),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.primaryGreen.withOpacity(0.05),
                  border: Border.all(
                    color: AppColors.primaryGreen.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          translatedTexts['progress'] ?? 'Progress',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        AnimatedBuilder(
                          animation: _progressController,
                          builder: (context, child) {
                            return Text(
                              '${(_analysisProgress * 100).toInt()}%',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryGreen,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, child) {
                        return LinearProgressIndicator(
                          value: _analysisProgress,
                          backgroundColor: AppColors.primaryGreen.withOpacity(
                            0.1,
                          ),
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.primaryGreen,
                          ),
                          minHeight: 5,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getStatusMessage(double progress) {
    if (progress < 0.2) {
      return translatedTexts['processingImage'] ?? 'Processing image data...';
    } else if (progress < 0.4) {
      return translatedTexts['runningDetection'] ??
          'Running disease detection...';
    } else if (progress < 0.6) {
      return translatedTexts['analyzingHealth'] ?? 'Analyzing crop health...';
    } else if (progress < 0.8) {
      return translatedTexts['generatingResults'] ?? 'Generating results...';
    } else {
      return translatedTexts['finalizingDiagnosis'] ??
          'Finalizing diagnosis...';
    }
  }

  Widget _buildResults() {
    final isError = result!.containsKey('error');
    final labelText = _getTranslatedLabel(result!['label'].toString());
    final isHealthy =
        !isError &&
        result!['label'].toString().toLowerCase().contains('healthy');
    final confidence = isError ? 0.0 : (result!['confidence'] * 100);

    return AnimatedBuilder(
      animation: _resultController,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (_resultController.value * 0.2),
          child: Opacity(
            opacity: _resultController.value,
            child: Card(
              elevation: 4,
              shadowColor: isError
                  ? Colors.red.withOpacity(0.2)
                  : (isHealthy
                        ? Colors.green.withOpacity(0.2)
                        : Colors.orange.withOpacity(0.2)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isError
                        ? AppColors.errorColor.withOpacity(0.3)
                        : (isHealthy
                              ? AppColors.successColor.withOpacity(0.3)
                              : AppColors.warningColor.withOpacity(0.3)),
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isError
                                  ? AppColors.errorColor
                                  : (isHealthy
                                        ? AppColors.successColor
                                        : AppColors.warningColor),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      (isError
                                              ? AppColors.errorColor
                                              : (isHealthy
                                                    ? AppColors.successColor
                                                    : AppColors.warningColor))
                                          .withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(
                              isError
                                  ? Icons.error
                                  : (isHealthy
                                        ? Icons.health_and_safety
                                        : Icons.warning),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              translatedTexts['detectionResults'] ??
                                  'Detection Results',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Divider(),
                      const SizedBox(height: 20),
                      _buildResultRow(
                        icon: Icons.biotech,
                        label:
                            translatedTexts['diseaseLabel'] ?? 'Disease Label',
                        value: labelText,
                        valueColor: isError
                            ? AppColors.errorColor
                            : (isHealthy
                                  ? AppColors.successColor
                                  : AppColors.errorColor),
                      ),
                      const SizedBox(height: 16),
                      if (!isError)
                        _buildResultRow(
                          icon: Icons.analytics,
                          label: translatedTexts['confidence'] ?? 'Confidence',
                          value: '${confidence.toStringAsFixed(1)}%',
                          valueColor: AppColors.textPrimary,
                        ),
                      if (isError && result!['error'] != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.errorColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.errorColor.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  color: AppColors.errorColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${translatedTexts['error'] ?? 'Error'}: ${result!['error']}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.errorColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.textSecondary, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: translatedTexts['diseaseDetection'] ?? 'Disease Detection',
      ),
      backgroundColor: AppColors.backgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCropAndCameraSection(),
                      const SizedBox(height: 16),
                      if (_isLoading) _buildLoadingIndicator(),
                      if (imagePath != null && !_isLoading) ...[
                        _buildImagePreview(),
                        const SizedBox(height: 16),
                      ],
                      if (result != null && !_isLoading) _buildResults(),
                      const SizedBox(height: 32),
                      const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
