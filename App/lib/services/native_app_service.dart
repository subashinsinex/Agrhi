import 'dart:io';
import 'package:flutter/services.dart';

class NativeAppService {
  static const _channel = MethodChannel('app.agrhi.com/native');

  static Future<Map<String, String>> packageInfo() async {
    final info = await _channel.invokeMapMethod<String, String>('packageInfo');
    if (info == null ||
        info['buildNumber'] == null ||
        info['packageName'] == null) {
      throw StateError('Missing installed app metadata');
    }
    return info;
  }

  static Future<File> compressImage(String source, String destination) async {
    final path = await _channel.invokeMethod<String>('compressImage', {
      'source': source,
      'destination': destination,
    });
    if (path == null) throw StateError('Image compression returned no output');
    final file = File(path);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('Image compression returned an empty file');
    }
    return file;
  }
}
