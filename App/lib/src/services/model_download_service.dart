import 'dart:io';
import '../models/model_file_validator.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../utils/constants.dart';

class ModelDownloadService {
  static final ModelDownloadService instance = ModelDownloadService._();
  ModelDownloadService._()
    : _dio = Dio(),
      _pathResolver = null,
      _validator = validateModelFile;
  ModelDownloadService({
    required this._dio,
    required this._pathResolver,
    required this._validator,
  });

  // Remove '/api' from base URL to get server root
  static final String serverUrl = AppConstants.baseUrl.replaceAll('/api', '');

  final Dio _dio;
  final Future<String> Function(String)? _pathResolver;
  final Future<bool> Function(String) _validator;
  final Map<String, Future<void>> _downloads = {};

  // Define your model information with actual file sizes from your server
  static final Map<String, ModelInfo> modelInfo = {
    'Banana': ModelInfo(
      url: '$serverUrl/models/banana_model.tflite',
      size: 12.76, // 13,070 KB ≈ 12.76 MB
      fileName: 'banana_model.tflite',
    ),
    'Coconut': ModelInfo(
      url: '$serverUrl/models/coconut_model.tflite',
      size: 32.08, // 32,851 KB ≈ 32.08 MB
      fileName: 'coconut_model.tflite',
    ),
    'Coffee': ModelInfo(
      url: '$serverUrl/models/coffee_model.tflite',
      size: 2.63, // 2,691 KB ≈ 2.63 MB
      fileName: 'coffee_model.tflite',
    ),
    'Corn': ModelInfo(
      url: '$serverUrl/models/corn_model.tflite',
      size: 42.62, // 43,639 KB ≈ 42.62 MB
      fileName: 'corn_model.tflite',
    ),
    'Cotton': ModelInfo(
      url: '$serverUrl/models/cotton_model.tflite',
      size: 32.08, // 32,850 KB ≈ 32.08 MB
      fileName: 'cotton_model.tflite',
    ),
    'Groundnut': ModelInfo(
      url: '$serverUrl/models/groundnut_model.tflite',
      size: 2.63, // 2,692 KB ≈ 2.63 MB
      fileName: 'groundnut_model.tflite',
    ),
    'Rice': ModelInfo(
      url: '$serverUrl/models/rice_model.tflite',
      size: 12.71, // 13,018 KB ≈ 12.71 MB
      fileName: 'rice_model.tflite',
    ),
    'Sugarcane': ModelInfo(
      url: '$serverUrl/models/sugarcane_model.tflite',
      size: 9.14, // 9,360 KB ≈ 9.14 MB
      fileName: 'sugarcane_model.tflite',
    ),
    'Tomato': ModelInfo(
      url: '$serverUrl/models/tomato_model.tflite',
      size: 12.77, // 13,075 KB ≈ 12.77 MB
      fileName: 'tomato_model.tflite',
    ),
    'Wheat': ModelInfo(
      url: '$serverUrl/models/wheat_model.tflite',
      size: 2.63, // 2,691 KB ≈ 2.63 MB
      fileName: 'wheat_model.tflite',
    ),
  };

  // Make this public so provider can access it
  Future<String> getModelFilePath(String cropName) async {
    if (_pathResolver != null) return _pathResolver(cropName);
    final dir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${dir.path}/models');
    if (!await modelDir.exists()) {
      await modelDir.create(recursive: true);
    }
    final info = modelInfo[cropName];
    if (info == null) throw Exception('Model info not found for: $cropName');
    return '${modelDir.path}/${info.fileName}';
  }

  Future<bool> isModelDownloaded(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      if (!await file.exists()) return false;
      final stat = await file.stat();
      final signature = '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
      final marker = File('$filePath.verified');
      if (await marker.exists() && await marker.readAsString() == signature) {
        return true;
      }
      if (!await _validator(filePath)) return false;
      await marker.writeAsString(signature, flush: true);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> downloadModel(
    String cropName, {
    required CancelToken cancelToken,
    required void Function(int received, int total) onProgress,
  }) {
    final active = _downloads[cropName];
    if (active != null) return active;
    final future = _downloadModel(
      cropName,
      cancelToken: cancelToken,
      onProgress: onProgress,
    );
    _downloads[cropName] = future;
    return future.whenComplete(() => _downloads.remove(cropName));
  }

  Future<void> waitForDownload(String cropName) async {
    try {
      await _downloads[cropName];
    } catch (_) {}
  }

  Future<void> _downloadModel(
    String cropName, {
    required CancelToken cancelToken,
    required void Function(int, int) onProgress,
  }) async {
    final info = modelInfo[cropName];
    if (info == null) throw Exception('Model not found: $cropName');

    final filePath = await getModelFilePath(cropName);

    try {
      await _dio.download(
        info.url,
        '$filePath.part',
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: onProgress,
        options: Options(
          headers: {'Accept': '*/*'},
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(minutes: 5),
        ),
      );
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      if (!await _validator('$filePath.part')) {
        throw const FormatException(
          'Downloaded model is incomplete or invalid',
        );
      }
      if (cancelToken.isCancelled) throw cancelToken.cancelError!;
      await File('$filePath.part').rename(filePath);
    } catch (e) {
      // If download fails, ensure partial file is deleted
      final partial = File('$filePath.part');
      if (await partial.exists()) await partial.delete();
      rethrow;
    }
  }

  Future<void> deleteModel(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
      }
      final marker = File('$filePath.verified');
      if (await marker.exists()) await marker.delete();
    } catch (e) {
      throw Exception('Failed to delete model: $e');
    }
  }

  Future<double> getTotalSize() async {
    double total = 0.0;
    for (final entry in modelInfo.entries) {
      final isDownloaded = await isModelDownloaded(entry.key);
      if (isDownloaded) {
        total += entry.value.size;
      }
    }
    return total;
  }

  // Get actual file size on disk (optional, for more accurate size tracking)
  Future<double> getActualFileSize(String cropName) async {
    try {
      final filePath = await getModelFilePath(cropName);
      final file = File(filePath);
      if (await file.exists()) {
        final bytes = await file.length();
        return bytes / (1024 * 1024); // Convert to MB
      }
      return 0.0;
    } catch (e) {
      return 0.0;
    }
  }
}

class ModelInfo {
  final String url;
  final double size; // in MB
  final String fileName;

  ModelInfo({required this.url, required this.size, required this.fileName});
}
