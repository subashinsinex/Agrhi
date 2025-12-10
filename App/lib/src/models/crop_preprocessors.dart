// lib/src/models/crop_preprocessors.dart
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

// ═══════════════════════════════════════════════════════════════════
// ⚠️ IMPORTANT CHANGE: Preprocessors no longer resize images
//
// Why: The gate model (plant detector) must receive ORIGINAL images
// to work correctly. Pre-resizing to 128x128 or 224x224 destroys
// information and causes false positives.
//
// How it works now:
// 1. Original image → Gate model (resizes internally to 224x224)
// 2. If plant detected → Disease model (resizes internally to its size)
//
// The old preprocessing functions have been simplified to return
// the original path. ModelService handles all resizing.
// ═══════════════════════════════════════════════════════════════════

// Utility: Proper normalization for display purposes only
// (Not used in current pipeline, kept for potential future use)
img.Image _normalize01(img.Image image) {
  final normalized = img.Image(width: image.width, height: image.height);
  for (final pixel in image) {
    normalized.setPixelRgba(pixel.x, pixel.y, pixel.r, pixel.g, pixel.b, 255);
  }
  return normalized;
}

img.Image _mobilenetNormalize(img.Image image) => _normalize01(image);

// ═══════════════════════════════════════════════════════════════════
// PREPROCESSOR FUNCTIONS
// All now return original path - models handle their own resizing
// ═══════════════════════════════════════════════════════════════════

/// RICE - No preprocessing, model handles resizing
Future<String> ricePreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 224x224
  return imagePath;
}

/// SUGARCANE - No preprocessing, model handles resizing
Future<String> sugarcanePreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 224x224
  return imagePath;
}

/// WHEAT - No preprocessing, model handles resizing
Future<String> wheatPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 224x224
  return imagePath;
}

/// GROUNDNUT - No preprocessing, model handles resizing
Future<String> groundnutPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 256x256
  return imagePath;
}

/// COTTON - No preprocessing, model handles resizing
Future<String> cottonPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 128x128
  return imagePath;
}

/// BANANA - No preprocessing, model handles resizing
/// ✅ FIXED: Was resizing to 128x128, now returns original
Future<String> bananaPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Gate model resizes internally to 224x224
  // Disease model resizes internally to 256x256
  return imagePath;
}

/// CORN - No preprocessing, model handles resizing
Future<String> cornPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 224x224
  return imagePath;
}

/// COCONUT - No preprocessing, model handles resizing
Future<String> coconutPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 128x128
  return imagePath;
}

/// COFFEE - No preprocessing, model handles resizing
Future<String> coffeePreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 224x224
  return imagePath;
}

/// TOMATO - No preprocessing, model handles resizing
Future<String> tomatoPreprocessor(String imagePath) async {
  // Gate model needs original image resolution
  // Model internally resizes to 640x640
  return imagePath;
}

// ═══════════════════════════════════════════════════════════════════
// PREPROCESSOR MAP
// Maps crop names to their preprocessor functions
// ═══════════════════════════════════════════════════════════════════

/// Mapping functions to crop names
final Map<String, Future<String> Function(String)> preprocessMap = {
  'Rice': ricePreprocessor,
  'Sugarcane': sugarcanePreprocessor,
  'Groundnut': groundnutPreprocessor,
  'Cotton': cottonPreprocessor,
  'Corn': cornPreprocessor,
  'Coconut': coconutPreprocessor,
  'Banana': bananaPreprocessor,
  'Coffee': coffeePreprocessor,
  'Wheat': wheatPreprocessor,
  'Tomato': tomatoPreprocessor,
};

// ═══════════════════════════════════════════════════════════════════
// MODEL PATH HELPERS
// Functions to get the path to downloaded model files
// ═══════════════════════════════════════════════════════════════════

/// Helper function to get downloaded model path
Future<String> _getModelPath(String cropName) async {
  final dir = await getApplicationDocumentsDirectory();
  final modelDir = Directory('${dir.path}/models');

  // Map crop names to actual file names
  final fileNameMap = {
    'Rice': 'rice_model.tflite',
    'Sugarcane': 'sugarcane_model.tflite',
    'Cotton': 'cotton_model.tflite',
    'Corn': 'corn_model.tflite',
    'Coconut': 'coconut_model.tflite',
    'Groundnut': 'groundnut_model.tflite',
    'Banana': 'banana_model.tflite',
    'Coffee': 'coffee_model.tflite',
    'Wheat': 'wheat_model.tflite',
    'Tomato': 'tomato_model.tflite',
  };

  return '${modelDir.path}/${fileNameMap[cropName]}';
}

/// Model file paths now point to downloaded models
final Map<String, Future<String> Function()> modelMap = {
  'Rice': () => _getModelPath('Rice'),
  'Sugarcane': () => _getModelPath('Sugarcane'),
  'Cotton': () => _getModelPath('Cotton'),
  'Corn': () => _getModelPath('Corn'),
  'Coconut': () => _getModelPath('Coconut'),
  'Groundnut': () => _getModelPath('Groundnut'),
  'Banana': () => _getModelPath('Banana'),
  'Coffee': () => _getModelPath('Coffee'),
  'Wheat': () => _getModelPath('Wheat'),
  'Tomato': () => _getModelPath('Tomato'),
};

// ═══════════════════════════════════════════════════════════════════
// MODEL INPUT SHAPES
// Reference only - ModelService handles actual resizing
// ═══════════════════════════════════════════════════════════════════

/// Expected input shapes for each disease detection model
/// Note: These are for reference only. The ModelService class
/// handles all image resizing internally.
final Map<String, List<int>> inputShapeMap = {
  'Rice': [1, 224, 224, 3],
  'Sugarcane': [1, 224, 224, 3],
  'Groundnut': [1, 256, 256, 3],
  'Corn': [1, 224, 224, 3],
  'Cotton': [1, 128, 128, 3],
  'Banana': [1, 256, 256, 3],
  'Coconut': [1, 128, 128, 3],
  'Coffee': [1, 224, 224, 3],
  'Wheat': [1, 224, 224, 3],
  'Tomato': [1, 3, 640, 640],
};
