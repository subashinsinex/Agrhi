import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../src/models/model_service.dart';
import '../../src/models/crop_preprocessors.dart';
import '../../src/models/disease_labels.dart';
import '../shared/widgets/custom_app_bar.dart';
import '../../utils/colors.dart';
import '../../flutter_gen/gen_l10n/app_localizations.dart';

class DetectDiseaseScreen extends StatefulWidget {
  const DetectDiseaseScreen({super.key});

  @override
  State<DetectDiseaseScreen> createState() => _DetectDiseaseScreenState();
}

class _DetectDiseaseScreenState extends State<DetectDiseaseScreen>
    with TickerProviderStateMixin {
  // Hardcoded crop list - no database needed
  final List<String> availableCrops = [
    'Corn',
    'Rice',
    'Sugarcane',
    'Cotton',
    'Coconut',
    'Groundnut',
    'Banana',
    'Coffee',
    'Wheat',
    'Tomato',
  ];

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

  @override
  void initState() {
    super.initState();
    // ✅ Production: Smooth animation timing
    _progressController = AnimationController(
      duration: const Duration(
        milliseconds: 2000,
      ), // Slightly slower for smoothness
      vsync: this,
    );
    _resultController = AnimationController(
      duration: const Duration(milliseconds: 1000), // Smooth result reveal
      vsync: this,
    );

    if (availableCrops.isNotEmpty) {
      selectedCrop = availableCrops.first;
      _loadModelForCrop(selectedCrop!);
    }
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
        await ModelService.loadModel(modelMap[cropName]!);
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to load model for $cropName');
      }
    } finally {
      if (mounted) {
        setState(() => _isModelLoading = false);
      }
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
      _progressController.reset();
      _progressController.forward();

      await _analyzeImage(picked.path);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          result = {'label': 'Error', 'confidence': 0.0, 'error': e.toString()};
        });
        _showErrorSnackBar('Failed to pick image: ${e.toString()}');
      }
    }
  }

  Future<void> _analyzeImage(String imagePath) async {
    try {
      // ✅ Production: Realistic AI analysis timing (3-4 seconds total)
      // 20 steps × 175ms = 3.5 seconds - feels professional and realistic
      for (int i = 0; i <= 100; i += 5) {
        // 5% increments = 20 smooth steps
        if (!mounted) return;
        setState(() => _analysisProgress = i / 100);
        await Future.delayed(
          const Duration(milliseconds: 175),
        ); // 175ms per step
      }

      final preprocessor = preprocessMap[selectedCrop];
      final processedPath = preprocessor != null
          ? await preprocessor(imagePath)
          : imagePath;

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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        result = {'label': 'Error', 'confidence': 0.0, 'error': e.toString()};
      });
      _showErrorSnackBar('Analysis failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          label: 'Dismiss',
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

  // ✅ Combined Crop Selection + Camera Actions Widget
  Widget _buildCropAndCameraSection() {
    final l10n = AppLocalizations.of(context);
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
            // Crop Selection Section
            Row(
              children: [
                Icon(
                  Icons.agriculture,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.selectCrop,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedContainer(
              // ✅ Production: Smooth dropdown animation
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
                    l10n.selectCropHint,
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  isExpanded: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                crop,
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
                  onChanged: _isModelLoading
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

            // Divider between sections
            const SizedBox(height: 20),
            Divider(
              color: AppColors.primaryGreen.withOpacity(0.2),
              thickness: 1,
            ),
            const SizedBox(height: 16),

            // Camera Actions Section
            Row(
              children: [
                Icon(Icons.camera_alt, color: AppColors.primaryGreen, size: 20),
                const SizedBox(width: 8),
                Text(
                  l10n.captureImage,
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
                    child: AnimatedContainer(
                      // ✅ Production: Smooth button animations
                      duration: const Duration(milliseconds: 250),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo_camera, size: 20),
                        label: Flexible(
                          child: Text(
                            l10n.takePhoto,
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
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedContainer(
                      // ✅ Production: Smooth button animations
                      duration: const Duration(milliseconds: 250),
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library, size: 20),
                        label: Flexible(
                          child: Text(
                            l10n.chooseFromGallery,
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
                  ),
                ],
              ),
            ),

            // Model loading indicator
            if (!isEnabled && _isModelLoading)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  children: [
                    SizedBox(
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

  Widget _buildImagePreview() {
    return Card(
      elevation: 4,
      shadowColor: AppColors.primaryGreen.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          // Image container
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
                  : Image.file(
                      File(imagePath!),
                      width: double.infinity,
                      height: 280,
                      fit: BoxFit.cover,
                    ),
            ),
          ),

          // Close button positioned at top-right
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
                tooltip: 'Remove image',
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
              // Sophisticated circular progress
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer rotating ring
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

                    // Main progress circle
                    SizedBox(
                      width: 80,
                      height: 80,
                      child: CircularProgressIndicator(
                        value: _analysisProgress,
                        strokeWidth: 5,
                        strokeCap: StrokeCap.round,
                        valueColor: AlwaysStoppedAnimation(
                          AppColors.primaryGreen,
                        ),
                        backgroundColor: AppColors.primaryGreen.withOpacity(
                          0.08,
                        ),
                      ),
                    ),

                    // Center icon
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primaryGreen.withOpacity(0.1),
                      ),
                      child: Icon(
                        Icons.biotech,
                        size: 24,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Dynamic status messages
              AnimatedSwitcher(
                // ✅ Production: Smooth text transitions
                duration: const Duration(milliseconds: 600),
                child: Text(
                  _getStatusMessage(_analysisProgress),
                  key: ValueKey(_getStatusMessage(_analysisProgress)),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 20),

              // Enhanced progress display
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
                          'Progress',
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
                              style: TextStyle(
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
                          valueColor: AlwaysStoppedAnimation(
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
    // ✅ Production: More detailed status messages for better UX
    if (progress < 0.2) {
      return 'Processing image data...';
    } else if (progress < 0.4) {
      return 'Running disease detection...';
    } else if (progress < 0.6) {
      return 'Analyzing crop health...';
    } else if (progress < 0.8) {
      return 'Generating results...';
    } else {
      return 'Finalizing diagnosis...';
    }
  }

  Widget _buildResults() {
    final l10n = AppLocalizations.of(context);
    final isError = result!.containsKey('error');
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
                      // Result header
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
                              l10n.detectionResults,
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

                      // Disease info
                      _buildResultRow(
                        icon: Icons.biotech,
                        label: l10n.diseaseLabel,
                        value: result!['label'].toString(),
                        valueColor: isError
                            ? AppColors.errorColor
                            : (isHealthy
                                  ? AppColors.successColor
                                  : AppColors.errorColor),
                      ),

                      const SizedBox(height: 16),

                      // Confidence info
                      if (!isError)
                        _buildResultRow(
                          icon: Icons.analytics,
                          label: l10n.confidenceLabel,
                          value: '${confidence.toStringAsFixed(1)}%',
                          valueColor: AppColors.textPrimary,
                        ),

                      // Error details
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
                                Icon(
                                  Icons.info_outline,
                                  color: AppColors.errorColor,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Error: ${result!['error']}',
                                    style: TextStyle(
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
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: CustomAppBar(title: l10n.diseaseDetection),
      body: RefreshIndicator(
        color: AppColors.primaryGreen,
        onRefresh: () async {
          if (selectedCrop != null) {
            await _loadModelForCrop(selectedCrop!);
          }
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Combined Crop Selection + Camera Actions
                _buildCropAndCameraSection(),

                const SizedBox(height: 16),

                // Loading Indicator
                if (_isLoading) _buildLoadingIndicator(),

                // Image Preview
                if (imagePath != null && !_isLoading) ...[
                  _buildImagePreview(),
                  const SizedBox(height: 16),
                ],

                // Results
                if (result != null && !_isLoading) _buildResults(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
