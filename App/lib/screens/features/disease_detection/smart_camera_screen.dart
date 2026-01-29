import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import '../../../src/models/model_service.dart';
import '../../../utils/colors.dart';
import '../../shared/smart_retranslator.dart';

class SmartCameraScreen extends StatefulWidget {
  final String cropName;

  const SmartCameraScreen({super.key, required this.cropName});

  @override
  State<SmartCameraScreen> createState() => _SmartCameraScreenState();
}

class _SmartCameraScreenState extends State<SmartCameraScreen>
    with TickerProviderStateMixin {
  CameraController? _cameraController;
  bool _isInitialized = false;
  bool _isDetecting = false;
  bool _isPlantDetected = false;
  double _plantConfidence = 0.0;

  // Capture states
  bool _showPreview = false;
  String? _croppedImagePath;
  bool _isVerifying = false;
  bool _isCapturing = false;
  Map<String, dynamic>? _verificationResult;

  late AnimationController _pulseController;
  late AnimationController _colorController;
  late AnimationController _captureController;
  late AnimationController _slideController;

  Timer? _detectionTimer;

  // Focus box dimensions (as ratios of screen size)
  static const double _boxWidthRatio = 0.85;
  static const double _boxHeightRatio = 0.60;
  static const double _boxOffsetY = -40.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _colorController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _captureController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _cameraController!.initialize();
      await _cameraController!.setFlashMode(FlashMode.off);

      if (!mounted) return;

      setState(() => _isInitialized = true);
      _startLiveDetection();
    } catch (e) {
      debugPrint('❌ Camera initialization error: $e');
      if (mounted) {
        _showErrorSnackBar('Camera error: ${e.toString()}');
      }
    }
  }

  void _startLiveDetection() {
    _detectionTimer = Timer.periodic(const Duration(milliseconds: 1000), (
      timer,
    ) async {
      if (_canDetect()) {
        await _detectPlantInFrame();
      }
    });
  }

  bool _canDetect() {
    return !_isDetecting &&
        !_showPreview &&
        !_isCapturing &&
        _cameraController != null &&
        _cameraController!.value.isInitialized &&
        !_cameraController!.value.isTakingPicture;
  }

  Future<String?> _cropImageToFocusBox(String imagePath) async {
    try {
      debugPrint('🔪 Starting image crop...');

      final imageBytes = await File(imagePath).readAsBytes();
      final originalImage = img.decodeImage(imageBytes);

      if (originalImage == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }

      debugPrint('📸 Original: ${originalImage.width}×${originalImage.height}');

      final screenSize = MediaQuery.of(context).size;
      final boxWidth = screenSize.width * _boxWidthRatio;
      final boxHeight = screenSize.height * _boxHeightRatio;

      // Calculate center of focus box
      final centerX = screenSize.width / 2;
      final centerY = (screenSize.height / 2) + _boxOffsetY;

      // Calculate focus box position (top-left corner)
      final boxLeft = centerX - (boxWidth / 2);
      final boxTop = centerY - (boxHeight / 2);

      // Calculate scale based on image/screen aspect ratio
      final imageAspect = originalImage.width / originalImage.height;
      final screenAspect = screenSize.width / screenSize.height;

      final scale = imageAspect > screenAspect
          ? originalImage.height / screenSize.height
          : originalImage.width / screenSize.width;

      // Convert box coordinates to image coordinates
      final cropX = (boxLeft * scale).round().clamp(0, originalImage.width - 1);
      final cropY = (boxTop * scale).round().clamp(0, originalImage.height - 1);
      final cropWidth = (boxWidth * scale).round().clamp(
        1,
        originalImage.width - cropX,
      );
      final cropHeight = (boxHeight * scale).round().clamp(
        1,
        originalImage.height - cropY,
      );

      debugPrint('✂️ Crop: ($cropX, $cropY) $cropWidth×$cropHeight');

      // Crop the image
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
      );

      debugPrint('✅ Cropped: ${croppedImage.width}×${croppedImage.height}');

      // Save cropped image
      final tempDir = await getTemporaryDirectory();
      final croppedPath =
          '${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await File(
        croppedPath,
      ).writeAsBytes(img.encodeJpg(croppedImage, quality: 90));

      debugPrint('💾 Saved: $croppedPath');
      return croppedPath;
    } catch (e) {
      debugPrint('❌ Crop error: $e');
      return null;
    }
  }

  Future<void> _detectPlantInFrame() async {
    if (!mounted) return;

    setState(() => _isDetecting = true);

    String? tempImagePath;
    String? croppedPath;

    try {
      final imageFile = await _cameraController!.takePicture();
      tempImagePath = imageFile.path;

      croppedPath = await _cropImageToFocusBox(tempImagePath);
      if (croppedPath == null) {
        throw Exception('Failed to crop image');
      }

      final result = await ModelService.runGateInference(croppedPath);

      if (!mounted) return;

      final isPlant = result['is_plant'] == true;
      final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _isPlantDetected = isPlant && confidence > 0.7;
        _plantConfidence = confidence;
      });

      _isPlantDetected
          ? _colorController.forward()
          : _colorController.reverse();
    } catch (e) {
      debugPrint('❌ Detection error: $e');
    } finally {
      // Clean up temp files
      await _cleanupTempFiles([tempImagePath, croppedPath]);

      if (mounted) {
        setState(() => _isDetecting = false);
      }
    }
  }

  // ✅ NEW: Save cropped image to permanent location
  Future<String?> _savePermanentImage(String tempCroppedPath) async {
    try {
      debugPrint('💾 Saving permanent image...');

      // Get app documents directory (permanent storage)
      final appDir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory('${appDir.path}/captured_images');

      // Create directory if it doesn't exist
      if (!await imagesDir.exists()) {
        await imagesDir.create(recursive: true);
      }

      // Create permanent file path
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final permanentPath = '${imagesDir.path}/plant_$timestamp.jpg';

      // Copy cropped image to permanent location
      await File(tempCroppedPath).copy(permanentPath);

      debugPrint('✅ Permanent image saved: $permanentPath');
      return permanentPath;
    } catch (e) {
      debugPrint('❌ Error saving permanent image: $e');
      return null;
    }
  }

  Future<void> _captureImage() async {
    if (!_canCapture()) return;

    setState(() => _isCapturing = true);
    _captureController.forward().then((_) => _captureController.reverse());

    String? tempImagePath;
    String? tempCroppedPath;

    try {
      _detectionTimer?.cancel();
      await Future.delayed(const Duration(milliseconds: 100));

      final imageFile = await _cameraController!.takePicture();
      tempImagePath = imageFile.path;

      tempCroppedPath = await _cropImageToFocusBox(tempImagePath);
      if (tempCroppedPath == null) {
        throw Exception('Failed to crop captured image');
      }

      // ✅ Save to permanent location
      final permanentPath = await _savePermanentImage(tempCroppedPath);
      if (permanentPath == null) {
        throw Exception('Failed to save permanent image');
      }

      if (!mounted) return;

      setState(() {
        _croppedImagePath = permanentPath; // ✅ Use permanent path
        _showPreview = true;
        _isVerifying = true;
      });

      _slideController.forward();

      // ✅ Verify using the permanent path
      await _verifyCapture(permanentPath);
    } catch (e) {
      debugPrint('❌ Capture error: $e');
      if (mounted) {
        _showErrorSnackBar('Capture failed. Please try again.');
        setState(() => _isCapturing = false);
        _startLiveDetection();
      }
    } finally {
      // Clean up temp files (not the permanent one)
      await _cleanupTempFiles([tempImagePath, tempCroppedPath]);
    }
  }

  bool _canCapture() {
    return _cameraController != null &&
        !_showPreview &&
        !_isCapturing &&
        !_cameraController!.value.isTakingPicture;
  }

  Future<void> _verifyCapture(String imagePath) async {
    try {
      final result = await ModelService.runGateInference(imagePath);

      if (!mounted) return;

      setState(() {
        _verificationResult = result;
        _isVerifying = false;
        _isCapturing = false;
      });
    } catch (e) {
      debugPrint('❌ Verification error: $e');
      if (mounted) {
        setState(() {
          _isVerifying = false;
          _isCapturing = false;
          _verificationResult = {'is_plant': false, 'confidence': 0.0};
        });
      }
    }
  }

  Future<void> _cleanupTempFiles(List<String?> paths) async {
    for (final path in paths) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }
  }

  void _resetCapture() {

    setState(() {
      _showPreview = false;
      _verificationResult = null;
      _isVerifying = false;
      _isCapturing = false;
    });

    _slideController.reverse();

    _croppedImagePath = null;

    _startLiveDetection();
  }

  void _confirmCapture() {
    if (_croppedImagePath == null) return;
    debugPrint('✅ Returning permanent image path: $_croppedImagePath');
    Navigator.pop(context, _croppedImagePath);
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getBoxColor() {
    if (_isPlantDetected) return const Color(0xFF4CAF50);
    if (_plantConfidence > 0.4) return const Color(0xFFFF9800);
    return const Color(0xFFF44336);
  }

  IconData _getStatusIcon() {
    if (_isPlantDetected) return Icons.check_circle;
    if (_plantConfidence > 0.4) return Icons.warning_amber_rounded;
    return Icons.error_outline;
  }

  String _getStatusText() {
    if (_isPlantDetected) return 'Ready - Tap to capture';
    if (_plantConfidence > 0.4) return 'Move closer to leaf';
    return 'Point at Crop leaf';
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController == null) {
      return _buildLoadingScreen();
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (!_showPreview) _buildCameraPreview(size),
          if (_showPreview && _croppedImagePath != null)
            _buildImagePreview(size),
          _buildCaptureFlash(),
          if (!_showPreview) _buildCameraUI(size) else _buildPreviewUI(size),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(color: AppColors.primaryGreen),
            SizedBox(height: 16),
            SmartReTranslator(
              text: 'Initializing smart camera...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview(Size size) {
    return SizedBox(
      width: size.width,
      height: size.height,
      child: CameraPreview(_cameraController!),
    );
  }

  Widget _buildImagePreview(Size size) {
    return SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: _slideController,
              curve: Curves.easeOutCubic,
            ),
          ),
      child: Container(
        width: size.width,
        height: size.height,
        color: Colors.black,
        child: Image.file(File(_croppedImagePath!), fit: BoxFit.contain),
      ),
    );
  }

  Widget _buildCaptureFlash() {
    return AnimatedBuilder(
      animation: _captureController,
      builder: (context, child) {
        return _captureController.value > 0
            ? Container(
                color: Colors.white.withOpacity(_captureController.value * 0.9),
              )
            : const SizedBox.shrink();
      },
    );
  }

  Widget _buildCameraUI(Size size) {
    return Stack(
      children: [_buildFocusBox(size), _buildTopBar(), _buildBottomControls()],
    );
  }

  Widget _buildFocusBox(Size size) {
    return Center(
      child: Transform.translate(
        offset: const Offset(0, _boxOffsetY),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            return AnimatedBuilder(
              animation: _colorController,
              builder: (context, child) {
                final boxColor = _getBoxColor();
                final pulseValue = _pulseController.value;

                return Container(
                  width: size.width * _boxWidthRatio,
                  height: size.height * _boxHeightRatio,
                  decoration: BoxDecoration(
                    border: Border.all(color: boxColor, width: 4),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: boxColor.withOpacity(0.4),
                        blurRadius: 20 + (pulseValue * 10),
                        spreadRadius: 2 + (pulseValue * 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      _buildCornerMarker(Alignment.topLeft, boxColor),
                      _buildCornerMarker(Alignment.topRight, boxColor),
                      _buildCornerMarker(Alignment.bottomLeft, boxColor),
                      _buildCornerMarker(Alignment.bottomRight, boxColor),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.7), Colors.transparent],
            ),
          ),
          child: Row(
            children: [
              _buildCloseButton(),
              const SizedBox(width: 12),
              Expanded(child: _buildStatusCard()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCloseButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: const Icon(Icons.close, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildStatusCard() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SmartReTranslator(
            text: widget.cropName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getBoxColor(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SmartReTranslator(
                  text: _getStatusText(),
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              _buildConfidenceBadge(),
              const SizedBox(height: 20),
              _buildCaptureButton(),
              const SizedBox(height: 12),
              _buildStatusText(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: _getBoxColor(),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _getBoxColor().withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getStatusIcon(), color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Text(
            '${(_plantConfidence * 100).toStringAsFixed(0)}% Confidence',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isCapturing ? null : _captureImage,
      child: AnimatedOpacity(
        opacity: _isCapturing ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            border: Border.all(
              color: _isPlantDetected ? _getBoxColor() : Colors.white70,
              width: 5,
            ),
            boxShadow: _isPlantDetected && !_isCapturing
                ? [
                    BoxShadow(
                      color: _getBoxColor().withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ]
                : [],
          ),
          child: _isCapturing
              ? const Center(
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(
                        AppColors.primaryGreen,
                      ),
                    ),
                  ),
                )
              : Icon(
                  Icons.camera_alt,
                  size: 36,
                  color: _isPlantDetected
                      ? AppColors.primaryGreen
                      : Colors.grey,
                ),
        ),
      ),
    );
  }

  Widget _buildStatusText() {
    return SmartReTranslator(
      text: _isCapturing
          ? 'Capturing...'
          : (_isPlantDetected ? 'Tap to capture' : 'Position leaf'),
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildPreviewUI(Size size) {
    final isPlant = _verificationResult?['is_plant'] == true;
    final confidence =
        (_verificationResult?['confidence'] as num?)?.toDouble() ?? 0.0;
    final isGoodQuality = isPlant && confidence > 0.7;

    return Stack(
      children: [
        _buildPreviewTopBar(),
        if (!_isVerifying)
          _buildVerificationResult(isGoodQuality, confidence, isPlant),
        if (_isVerifying) _buildVerificationLoading(),
        _buildPreviewActions(isGoodQuality),
      ],
    );
  }

  Widget _buildPreviewTopBar() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black.withOpacity(0.8), Colors.transparent],
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const SmartReTranslator(
                text: 'Preview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerificationResult(
    bool isGoodQuality,
    double confidence,
    bool isPlant,
  ) {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isGoodQuality
              ? const Color(0xFF4CAF50)
              : const Color(0xFFF44336),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color:
                  (isGoodQuality
                          ? const Color(0xFF4CAF50)
                          : const Color(0xFFF44336))
                      .withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isGoodQuality ? Icons.check_circle : Icons.error,
              color: Colors.white,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SmartReTranslator(
                    text: isGoodQuality
                        ? 'Perfect! Crop detected'
                        : isPlant
                        ? 'Low quality - Recapture required'
                        : 'Not a Crop - Recapture required',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${(confidence * 100).toStringAsFixed(0)}% confidence',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (!isGoodQuality) ...[
                    const SizedBox(height: 2),
                    const SmartReTranslator(
                      text: 'Please capture again closer to leaf',
                      style: TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationLoading() {
    return Positioned(
      top: 100,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primaryGreen,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
            SizedBox(width: 12),
            SmartReTranslator(
              text: 'Verifying image quality...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewActions(bool isGoodQuality) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [Colors.black.withOpacity(0.9), Colors.transparent],
            ),
          ),
          child: Column(
            children: [
              if (!_isVerifying && !isGoodQuality) _buildWarningMessage(),
              Row(
                children: [
                  Expanded(
                    flex: isGoodQuality ? 1 : 2,
                    child: _buildRetakeButton(isGoodQuality),
                  ),
                  if (isGoodQuality) ...[
                    const SizedBox(width: 16),
                    Expanded(flex: 2, child: _buildUsePhotoButton()),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWarningMessage() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Expanded(
            child: SmartReTranslator(
              text:
                  'Please Recapture - better quality needed for accurate diagnosis',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRetakeButton(bool isGoodQuality) {
    return ElevatedButton.icon(
      onPressed: _resetCapture,
      icon: const Icon(Icons.refresh, size: 20),
      label: SmartReTranslator(
        text: isGoodQuality ? 'Recapture' : 'Recapture Photo',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isGoodQuality
            ? Colors.white.withOpacity(0.2)
            : const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isGoodQuality ? Colors.white : Colors.orange,
            width: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildUsePhotoButton() {
    return ElevatedButton.icon(
      onPressed: _isVerifying ? null : _confirmCapture,
      icon: const Icon(Icons.check, size: 24),
      label: const SmartReTranslator(
        text: 'Use Photo',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
      ),
    );
  }

  Widget _buildCornerMarker(Alignment alignment, Color color) {
    return Align(
      alignment: alignment,
      child: Container(
        width: 30,
        height: 30,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          border: Border(
            top: alignment.y < 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            bottom: alignment.y > 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            left: alignment.x < 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
            right: alignment.x > 0
                ? BorderSide(color: color, width: 4)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    _cameraController?.dispose();
    _pulseController.dispose();
    _colorController.dispose();
    _captureController.dispose();
    _slideController.dispose();

    // Don't cleanup the permanent image - it's being used by disease detection

    super.dispose();
  }
}
