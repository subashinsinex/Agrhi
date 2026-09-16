import 'dart:io';
import 'dart:isolate';
import 'package:tflite_flutter/tflite_flutter.dart';

Future<bool> validateModelFile(String path) => Isolate.run(() {
  Interpreter? interpreter;
  try {
    interpreter = Interpreter.fromFile(File(path));
    return interpreter.getInputTensors().isNotEmpty &&
        interpreter.getOutputTensors().isNotEmpty;
  } catch (_) {
    return false;
  } finally {
    interpreter?.close();
  }
});
