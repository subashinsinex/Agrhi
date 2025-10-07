import 'dart:io';
import 'package:image/image.dart' as img;

// Utility: Proper normalization for display purposes only
img.Image _normalize01(img.Image image) {
  final normalized = img.Image(width: image.width, height: image.height);
  for (final pixel in image) {
    normalized.setPixelRgba(pixel.x, pixel.y, pixel.r, pixel.g, pixel.b, 255);
  }
  return normalized;
}

img.Image _mobilenetNormalize(img.Image image) => _normalize01(image);

// RICE - Grayscale with contrast enhancement
Future<String> ricePreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final grayscale = img.grayscale(resized);
  final contrasted = img.adjustColor(grayscale, contrast: 1.5);
  final rgb = img.bakeOrientation(contrasted);
  final processedPath = '${imagePath}_rice.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(rgb));
  return processedPath;
}

// SUGARCANE - Standard preprocessing
Future<String> sugarcanePreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final processed = _mobilenetNormalize(resized);
  final processedPath = '${imagePath}_sugarcane.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(processed));
  return processedPath;
}

// WHEAT - Standard preprocessing
Future<String> wheatPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final processed = _mobilenetNormalize(resized);
  final processedPath = '${imagePath}_wheat.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(processed));
  return processedPath;
}

// GROUNDNUT - Standard preprocessing
Future<String> groundnutPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_groundnut.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// COTTON - Custom normalization for 128x128
Future<String> cottonPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 128, height: 128);
  final normalized = img.Image(width: 128, height: 128);

  for (final pixel in resized) {
    final r = (((pixel.r / 255.0) - 0.5) * 2 * 255).toInt().clamp(0, 255);
    final g = (((pixel.g / 255.0) - 0.5) * 2 * 255).toInt().clamp(0, 255);
    final b = (((pixel.b / 255.0) - 0.5) * 2 * 255).toInt().clamp(0, 255);
    normalized.setPixelRgba(pixel.x, pixel.y, r, g, b, 255);
  }

  final processedPath = '${imagePath}_cotton.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// BANANA - 128x128 standard preprocessing
Future<String> bananaPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 128, height: 128);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_banana.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// CORN - Standard preprocessing
Future<String> cornPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_corn.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// COCONUT - 128x128 standard preprocessing
Future<String> coconutPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 128, height: 128);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_coconut.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// COFFEE - Standard preprocessing
Future<String> coffeePreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 224, height: 224);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_coffee.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// TOMATO - Standard preprocessing
Future<String> tomatoPreprocessor(String imagePath) async {
  final image = img.decodeImage(await File(imagePath).readAsBytes())!;
  final resized = img.copyResize(image, width: 640, height: 640);
  final normalized = _normalize01(resized);
  final processedPath = '${imagePath}_tomato.jpg';
  await File(processedPath).writeAsBytes(img.encodeJpg(normalized));
  return processedPath;
}

// Mapping functions to crop names
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

// Model file paths
final Map<String, String> modelMap = {
  'Rice': 'assets/models/rice_model.tflite',
  'Sugarcane': 'assets/models/sugarcane_model.tflite',
  'Cotton': 'assets/models/cotton_model.tflite',
  'Corn': 'assets/models/corn_model.tflite',
  'Coconut': 'assets/models/coconut_model.tflite',
  'Groundnut': 'assets/models/groundnut_model.tflite',
  'Banana': 'assets/models/b3.tflite',
  'Coffee': 'assets/models/coffee_model.tflite',
  'Wheat': 'assets/models/wheatwork_model.tflite',
  'Tomato': 'assets/models/tomato_model.tflite',
};

// Expected input shapes for each model
final Map<String, List<int>> inputShapeMap = {
  'Rice': [1, 224, 224, 3],
  'Sugarcane': [1, 224, 224, 3],
  'Groundnut': [1, 224, 224, 3],
  'Corn': [1, 224, 224, 3],
  'Cotton': [1, 128, 128, 3],
  'Banana': [1, 256,256, 3],
  'Coconut': [1, 128, 128, 3],
  'Coffee': [1, 224, 224, 3],
  'Wheat': [1, 224, 224, 3],
  'Tomato': [1, 3, 640, 640],
};
