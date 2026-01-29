// lib/src/models/model_service.dart
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  static Interpreter? _gateInterpreter;
  static Interpreter? _mainInterpreter;

  static late List<int> _gateInputShape;
  static late List<int> _mainInputShape;

  static bool _gateModelLoaded = false;

  /// Load the plant/non-plant gate model (mandatory, runs once)
  static Future<void> loadGateModel(String modelPath) async {
    try {
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Gate model not found at: $modelPath');
      }

      debugPrint('🔧 Loading gate model from: $modelPath');
      _gateInterpreter = Interpreter.fromFile(modelFile);
      _gateInputShape = _gateInterpreter!.getInputTensor(0).shape;
      _gateModelLoaded = true;

      debugPrint('✅ Gate model loaded: $_gateInputShape');
      debugPrint(
        '📊 Gate input type: ${_gateInterpreter!.getInputTensor(0).type}',
      );
      debugPrint(
        '📊 Gate output type: ${_gateInterpreter!.getOutputTensor(0).type}',
      );
      debugPrint(
        '📊 Gate output shape: ${_gateInterpreter!.getOutputTensor(0).shape}',
      );
    } catch (e) {
      debugPrint('❌ Gate model load error: $e');
      rethrow;
    }
  }

  /// Load the selected crop disease model
  static Future<void> loadModel(String modelPath) async {
    try {
      final modelFile = File(modelPath);
      if (!await modelFile.exists()) {
        throw Exception('Model file not found at: $modelPath');
      }

      debugPrint('🔧 Loading disease model from: $modelPath');
      _mainInterpreter = Interpreter.fromFile(modelFile);
      _mainInputShape = _mainInterpreter!.getInputTensor(0).shape;
      debugPrint('✅ Disease model loaded: $modelPath');
      debugPrint('📐 Shape: $_mainInputShape');
    } catch (e) {
      debugPrint('❌ Model load error: $e');
      rethrow;
    }
  }

  /// ✅ FIXED: Run gate inference for smart camera
  static Future<Map<String, dynamic>> runGateInference(String imagePath) async {
    if (_gateInterpreter == null || !_gateModelLoaded) {
      debugPrint('❌ Gate model not loaded');
      return {'is_plant': false, 'confidence': 0.0};
    }

    try {
      debugPrint('🔍 Running gate inference on: $imagePath');

      // Load and decode image
      final imageData = await File(imagePath).readAsBytes();
      img.Image? image = img.decodeImage(imageData);

      if (image == null) {
        debugPrint('❌ Could not decode image');
        return {'is_plant': false, 'confidence': 0.0};
      }

      debugPrint('📸 Image decoded: ${image.width}×${image.height}');

      // Preprocess using the same method as runInference
      final gateInputBuffer = _preprocessGateUint8(image, _gateInputShape);

      // Reshape into proper tensor format
      final gateInput = gateInputBuffer.buffer.asUint8List().reshape(
        _gateInputShape,
      );

      // Output shape: [1, 1] (single probability)
      final gateOutput = List.filled(1, 0.0).reshape([1, 1]);

      // Run inference
      _gateInterpreter!.run(gateInput, gateOutput);

      // Get plant probability
      final plantProb = gateOutput[0][0] as double;

      debugPrint(
        '🌱 Plant probability: ${(plantProb * 100).toStringAsFixed(2)}%',
      );

      // Return result
      return {
        'is_plant':
            plantProb > 0.5, // Use 0.5 threshold for binary classification
        'confidence': plantProb,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Gate inference error: $e');
      debugPrint('Stack trace: $stackTrace');
      return {'is_plant': false, 'confidence': 0.0, 'error': e.toString()};
    }
  }

  /// Preprocess for gate model - returns Uint8List (0-255 range)
  static Uint8List _preprocessGateUint8(img.Image image, List<int> inputShape) {
    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];

    debugPrint('🎨 Preprocessing Details:');
    debugPrint('   Original image: ${image.width}×${image.height}');
    debugPrint('   Target size: $width×$height');
    debugPrint('   Channels: $channels');

    final resized = img.copyResize(image, width: width, height: height);
    debugPrint('   ✅ Resized complete');

    final totalSize = height * width * channels;
    final buffer = Uint8List(totalSize);
    var index = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixel = resized.getPixel(x, y);
        buffer[index++] = pixel.r.toInt().clamp(0, 255);
        buffer[index++] = pixel.g.toInt().clamp(0, 255);
        buffer[index++] = pixel.b.toInt().clamp(0, 255);
      }
    }

    debugPrint('   ✅ Buffer created: ${buffer.length} bytes');
    return buffer;
  }

  /// Preprocess for disease model (normalized 0-1 range)
  static List<List<List<List<double>>>> _preprocessDisease(
    img.Image image,
    List<int> inputShape,
  ) {
    final height = inputShape[1];
    final width = inputShape[2];

    debugPrint('🔬 Disease model preprocessing:');
    debugPrint('   Resizing to: $width×$height');

    final resized = img.copyResize(image, width: width, height: height);

    return List.generate(1, (_) {
      return List.generate(height, (y) {
        return List.generate(width, (x) {
          final p = resized.getPixel(x, y);
          return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
        });
      });
    });
  }

  /// Two-stage inference: gate → disease model
  static Future<List<Map<String, dynamic>>> runInference(
    String imagePath,
    List<String> labels,
    String cropName, {
    double gateThreshold = 0.7,
  }) async {
    try {
      debugPrint('\n${'=' * 60}');
      debugPrint('🚀 STARTING TWO-STAGE INFERENCE');
      debugPrint('=' * 60);

      if (!_gateModelLoaded) {
        throw Exception('Gate model not loaded. Call loadGateModel() first.');
      }

      debugPrint('📂 Loading image from: $imagePath');
      final imageBytes = await File(imagePath).readAsBytes();
      debugPrint('   File size: ${imageBytes.length} bytes');

      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception("❌ Could not decode image");

      debugPrint('   ✅ Image decoded successfully');

      // ════════════════════════════════════════════════════════════
      // STAGE 1: Plant/Non-Plant Gate Check
      // ════════════════════════════════════════════════════════════
      debugPrint('\n${'=' * 60}');
      debugPrint('🔍 STAGE 1: PLANT DETECTION');
      debugPrint('=' * 60);
      debugPrint('📸 Original image: ${image.width}×${image.height}');

      // Prepare uint8 input
      final gateInputBuffer = _preprocessGateUint8(image, _gateInputShape);

      debugPrint('\n🔧 Reshaping buffer to tensor format...');
      debugPrint('   Input shape: $_gateInputShape');

      // Reshape into proper tensor format [1, height, width, 3]
      final gateInput = gateInputBuffer.buffer.asUint8List().reshape(
        _gateInputShape,
      );
      debugPrint('   ✅ Reshaped successfully');

      // Output shape: [1, 1] (single probability)
      final gateOutput = List.filled(1, 0.0).reshape([1, 1]);

      debugPrint('\n⚙️ Running gate model inference...');
      _gateInterpreter!.run(gateInput, gateOutput);
      debugPrint('   ✅ Inference complete');

      final plantProb = gateOutput[0][0] as double;

      debugPrint('\n${'=' * 60}');
      debugPrint('📊 STAGE 1 RESULTS');
      debugPrint('=' * 60);
      debugPrint('🔍 Raw gate output: $plantProb');
      debugPrint(
        '🌱 Plant probability: ${(plantProb * 100).toStringAsFixed(2)}%',
      );
      debugPrint('🎯 Threshold: ${(gateThreshold * 100).toStringAsFixed(0)}%');

      // Calculate confidence
      final distance = (plantProb - gateThreshold).abs();
      debugPrint(
        '📏 Distance from threshold: ${(distance * 100).toStringAsFixed(2)}%',
      );

      // Check if probability is below threshold
      if (plantProb < gateThreshold) {
        final confidence = 1.0 - plantProb;
        debugPrint('\n${'=' * 60}');
        debugPrint('🚫 DECISION: NOT A PLANT');
        debugPrint('=' * 60);
        debugPrint('   Probability: ${(plantProb * 100).toStringAsFixed(2)}%');
        debugPrint(
          '   Non-plant confidence: ${(confidence * 100).toStringAsFixed(2)}%',
        );

        if (distance < 0.1) {
          debugPrint('   ⚠️ WARNING: Close to threshold');
        } else {
          debugPrint('   ✅ Clear decision');
        }

        return [
          {
            'label': 'undefined',
            'confidence': confidence,
            'is_plant': false,
            'gate_probability': plantProb,
          },
        ];
      }

      // ════════════════════════════════════════════════════════════
      // STAGE 2: Disease Classification
      // ════════════════════════════════════════════════════════════
      debugPrint('\n${'=' * 60}');
      debugPrint('✅ PLANT DETECTED!');
      debugPrint('=' * 60);
      debugPrint('   Confidence: ${(plantProb * 100).toStringAsFixed(2)}%');

      debugPrint('\n${'=' * 60}');
      debugPrint('🔬 STAGE 2: DISEASE CLASSIFICATION');
      debugPrint('=' * 60);
      debugPrint('🌿 Crop: $cropName');

      final diseaseInput = _preprocessDisease(image, _mainInputShape);

      final outputShape = _mainInterpreter!.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      debugPrint('\n⚙️ Running disease model inference...');
      _mainInterpreter!.run(diseaseInput, output);
      debugPrint('   ✅ Inference complete');

      // Log top 3 predictions
      debugPrint('\n📊 Top disease predictions:');
      final tempResults =
          List.generate(labels.length, (i) {
            return {'label': labels[i], 'confidence': output[0][i] as double};
          })..sort(
            (a, b) => (b['confidence'] as double).compareTo(
              a['confidence'] as double,
            ),
          );

      for (int i = 0; i < 3 && i < tempResults.length; i++) {
        final conf = (tempResults[i]['confidence'] as double) * 100;
        debugPrint(
          '   ${i + 1}. ${tempResults[i]['label']}: ${conf.toStringAsFixed(2)}%',
        );
      }

      final results =
          List.generate(labels.length, (i) {
            return {
              'label': labels[i],
              'confidence': output[0][i],
              'is_plant': true,
              'gate_probability': plantProb,
            };
          })..sort(
            (a, b) => (b['confidence'] as double).compareTo(
              a['confidence'] as double,
            ),
          );

      debugPrint('\n${'=' * 60}');
      debugPrint('✅ INFERENCE COMPLETE');
      debugPrint('=' * 60);

      return results;
    } catch (e, stackTrace) {
      debugPrint("\n❌ INFERENCE ERROR");
      debugPrint("=" * 60);
      debugPrint("Error: $e");
      debugPrint("\nStack trace:");
      debugPrint(stackTrace.toString());
      debugPrint("=" * 60);

      return [
        {
          'label': 'Error',
          'confidence': 0.0,
          'error': e.toString(),
          'is_plant': false,
        },
      ];
    }
  }
}
