// lib/src/models/model_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  static late Interpreter _gateInterpreter;
  static late Interpreter _mainInterpreter;

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

      print('🔧 Loading gate model from: $modelPath');
      _gateInterpreter = await Interpreter.fromFile(modelFile);
      _gateInputShape = _gateInterpreter.getInputTensor(0).shape;
      _gateModelLoaded = true;

      print('✅ Gate model loaded: $_gateInputShape');
      print('📊 Gate input type: ${_gateInterpreter.getInputTensor(0).type}');
      print('📊 Gate output type: ${_gateInterpreter.getOutputTensor(0).type}');
      print(
        '📊 Gate output shape: ${_gateInterpreter.getOutputTensor(0).shape}',
      );
    } catch (e) {
      print('❌ Gate model load error: $e');
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

      print('🔧 Loading disease model from: $modelPath');
      _mainInterpreter = await Interpreter.fromFile(modelFile);
      _mainInputShape = _mainInterpreter.getInputTensor(0).shape;
      print('✅ Disease model loaded: $modelPath');
      print('📐 Shape: $_mainInputShape');
    } catch (e) {
      print('❌ Model load error: $e');
      rethrow;
    }
  }

  /// Preprocess for gate model - returns Uint8List (0-255 range)
  static Uint8List _preprocessGateUint8(img.Image image, List<int> inputShape) {
    final height = inputShape[1];
    final width = inputShape[2];
    final channels = inputShape[3];

    print('🎨 Preprocessing Details:');
    print('   Original image: ${image.width}×${image.height}');
    print('   Target size: $width×$height');
    print('   Channels: $channels');

    final resized = img.copyResize(image, width: width, height: height);
    print('   ✅ Resized complete');

    // Sample first 5 pixels BEFORE putting in buffer
    print('   Sample pixels from resized image:');
    for (int i = 0; i < 5 && i < resized.width; i++) {
      final pixel = resized.getPixel(i, 0);
      print(
        '      Pixel $i: R=${pixel.r.toInt()}, G=${pixel.g.toInt()}, B=${pixel.b.toInt()}',
      );
    }

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

    print('   ✅ Buffer created: ${buffer.length} bytes');
    print('   Expected: $totalSize ($width×$height×$channels)');

    // Sample first 15 bytes from buffer (5 pixels as RGB)
    print('   First 15 buffer values (5 pixels as RGB):');
    for (int i = 0; i < 15 && i < buffer.length; i += 3) {
      if (i + 2 < buffer.length) {
        print(
          '      Buffer[$i-${i + 2}]: R=${buffer[i]}, G=${buffer[i + 1]}, B=${buffer[i + 2]}',
        );
      }
    }

    // Check for any anomalies
    int minVal = buffer[0];
    int maxVal = buffer[0];
    for (int i = 1; i < buffer.length; i++) {
      if (buffer[i] < minVal) minVal = buffer[i];
      if (buffer[i] > maxVal) maxVal = buffer[i];
    }
    print('   Buffer range: [$minVal, $maxVal]');

    return buffer;
  }

  /// Preprocess for disease model (normalized 0-1 range)
  static List<List<List<List<double>>>> _preprocessDisease(
    img.Image image,
    List<int> inputShape,
  ) {
    final height = inputShape[1];
    final width = inputShape[2];

    print('🔬 Disease model preprocessing:');
    print('   Resizing to: $width×$height');

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
      print('\n${'=' * 60}');
      print('🚀 STARTING TWO-STAGE INFERENCE');
      print('=' * 60);

      if (!_gateModelLoaded) {
        throw Exception('Gate model not loaded. Call loadGateModel() first.');
      }

      print('📂 Loading image from: $imagePath');
      final imageBytes = await File(imagePath).readAsBytes();
      print('   File size: ${imageBytes.length} bytes');

      final image = img.decodeImage(imageBytes);
      if (image == null) throw Exception("❌ Could not decode image");

      print('   ✅ Image decoded successfully');

      // ════════════════════════════════════════════════════════════
      // STAGE 1: Plant/Non-Plant Gate Check
      // ════════════════════════════════════════════════════════════
      print('\n${'=' * 60}');
      print('🔍 STAGE 1: PLANT DETECTION');
      print('=' * 60);
      print('📸 Original image: ${image.width}×${image.height}');

      // Prepare uint8 input
      final gateInputBuffer = _preprocessGateUint8(image, _gateInputShape);

      print('\n🔧 Reshaping buffer to tensor format...');
      print('   Input shape: $_gateInputShape');

      // Reshape into proper tensor format [1, height, width, 3]
      final gateInput = gateInputBuffer.buffer.asUint8List().reshape(
        _gateInputShape,
      );
      print('   ✅ Reshaped successfully');

      // Output shape: [1, 1] (single probability)
      final gateOutput = List.filled(1, 0.0).reshape([1, 1]);

      print('\n⚙️ Running gate model inference...');
      _gateInterpreter.run(gateInput, gateOutput);
      print('   ✅ Inference complete');

      final plantProb = gateOutput[0][0] as double;

      print('\n${'=' * 60}');
      print('📊 STAGE 1 RESULTS');
      print('=' * 60);
      print('🔍 Raw gate output: $plantProb');
      print('🌱 Plant probability: ${(plantProb * 100).toStringAsFixed(2)}%');
      print('🎯 Threshold: ${(gateThreshold * 100).toStringAsFixed(0)}%');

      // Calculate confidence
      final distance = (plantProb - gateThreshold).abs();
      print(
        '📏 Distance from threshold: ${(distance * 100).toStringAsFixed(2)}%',
      );

      // Check if probability is below threshold
      if (plantProb < gateThreshold) {
        final confidence = 1.0 - plantProb;
        print('\n${'=' * 60}');
        print('🚫 DECISION: NOT A PLANT');
        print('=' * 60);
        print('   Probability: ${(plantProb * 100).toStringAsFixed(2)}%');
        print(
          '   Non-plant confidence: ${(confidence * 100).toStringAsFixed(2)}%',
        );

        if (distance < 0.1) {
          print('   ⚠️ WARNING: Close to threshold');
        } else {
          print('   ✅ Clear decision');
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
      print('\n${'=' * 60}');
      print('✅ PLANT DETECTED!');
      print('=' * 60);
      print('   Confidence: ${(plantProb * 100).toStringAsFixed(2)}%');

      print('\n${'=' * 60}');
      print('🔬 STAGE 2: DISEASE CLASSIFICATION');
      print('=' * 60);
      print('🌿 Crop: $cropName');

      final diseaseInput = _preprocessDisease(image, _mainInputShape);

      final outputShape = _mainInterpreter.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      print('\n⚙️ Running disease model inference...');
      _mainInterpreter.run(diseaseInput, output);
      print('   ✅ Inference complete');

      // Log top 3 predictions
      print('\n📊 Top disease predictions:');
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
        print(
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

      print('\n${'=' * 60}');
      print('✅ INFERENCE COMPLETE');
      print('=' * 60);

      return results;
    } catch (e, stackTrace) {
      print("\n❌ INFERENCE ERROR");
      print("=" * 60);
      print("Error: $e");
      print("\nStack trace:");
      print(stackTrace);
      print("=" * 60);

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

  /// Dispose interpreters to free resources
  static void dispose() {
    print('🧹 Disposing interpreters...');
    if (_gateModelLoaded) {
      _gateInterpreter.close();
      _gateModelLoaded = false;
      print('   ✅ Gate interpreter closed');
    }
    try {
      _mainInterpreter.close();
      print('   ✅ Disease interpreter closed');
    } catch (_) {}
  }
}
