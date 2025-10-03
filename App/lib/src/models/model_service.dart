import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class ModelService {
  static late Interpreter _interpreter;
  static late List<int> _inputShape;

  static Future<void> loadModel(String modelPath) async {
    try {
      _interpreter = await Interpreter.fromAsset(modelPath);
      _inputShape = _interpreter.getInputTensor(0).shape;
      print('✅ Model loaded: $modelPath');
      print('📐 Shape: $_inputShape');
    } catch (e) {
      print('❌ Model load error: $e');
      rethrow;
    }
  }

  static Future<List<Map<String, dynamic>>> runInference(
    String imagePath,
    List<String> labels,
    String cropName,
  ) async {
    try {
      final image = img.decodeImage(await File(imagePath).readAsBytes());
      if (image == null) throw Exception("❌ Could not decode image");

      final height = _inputShape[1];
      final width = _inputShape[2];

      final resizedImage = img.copyResize(image, width: width, height: height);

      final input = List.generate(1, (_) {
        return List.generate(height, (y) {
          return List.generate(width, (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          });
        });
      });

      final outputShape = _interpreter.getOutputTensor(0).shape;
      final output = List.filled(
        outputShape.reduce((a, b) => a * b),
        0.0,
      ).reshape(outputShape);

      _interpreter.run(input, output);

      return List.generate(labels.length, (i) {
        return {'label': labels[i], 'confidence': output[0][i]};
      })..sort(
        (a, b) =>
            (b['confidence'] as double).compareTo(a['confidence'] as double),
      );
    } catch (e) {
      print("❌ Inference error: $e");
      return [
        {'label': 'Error', 'confidence': 0.0},
      ];
    }
  }
}
