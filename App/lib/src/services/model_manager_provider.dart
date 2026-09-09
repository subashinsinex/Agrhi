import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'model_download_service.dart';

class ModelManagerProvider extends ChangeNotifier {
  ModelManagerProvider({ModelDownloadService? downloadService})
    : _downloadService = downloadService ?? ModelDownloadService.instance;

  final ModelDownloadService _downloadService;
  final Map<String, CancelToken> _cancelTokens = {};

  Map<String, ModelDownloadStatus> _modelStatuses = {};
  final Map<String, double> _downloadProgress = {};
  bool _isLoading = false;
  bool _disposed = false;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  double _totalSize = 0.0;

  Map<String, ModelDownloadStatus> get modelStatuses => _modelStatuses;
  Map<String, double> get downloadProgress => _downloadProgress;
  bool get isLoading => _isLoading;
  double get totalSize => _totalSize;

  Future<void> initialize() async {
    _isLoading = true;
    _notify();

    await _loadAllStatuses();

    _isLoading = false;
    _notify();
  }

  Future<void> _loadAllStatuses() async {
    final statuses = <String, ModelDownloadStatus>{};

    for (final crop in ModelDownloadService.modelInfo.keys) {
      final isDownloaded = await _downloadService.isModelDownloaded(crop);
      statuses[crop] = isDownloaded
          ? ModelDownloadStatus.downloaded
          : ModelDownloadStatus.notDownloaded;
    }

    if (_disposed) return;
    for (final crop in _cancelTokens.keys) {
      statuses[crop] = ModelDownloadStatus.downloading;
    }
    _modelStatuses = statuses;
    _totalSize = await _downloadService.getTotalSize();
  }

  Future<void> downloadModel(String cropName) async {
    if (_cancelTokens.containsKey(cropName)) return;
    // Create a new cancel token for this download
    final cancelToken = CancelToken();
    _cancelTokens[cropName] = cancelToken;

    _modelStatuses[cropName] = ModelDownloadStatus.downloading;
    _downloadProgress[cropName] = 0.0;
    _notify();

    try {
      await _downloadService.downloadModel(
        cropName,
        cancelToken: cancelToken,
        onProgress: (received, total) {
          if (total > 0) {
            _downloadProgress[cropName] = received / total;
            _notify();
          }
        },
      );

      _modelStatuses[cropName] = ModelDownloadStatus.downloaded;
      _downloadProgress.remove(cropName);
      _cancelTokens.remove(cropName);
      _totalSize = await _downloadService.getTotalSize();
      _notify();
    } catch (e) {
      // Check if error is due to cancellation
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint('Download cancelled for $cropName');
      } else {
        _modelStatuses[cropName] = ModelDownloadStatus.error;
        _downloadProgress.remove(cropName);
        _cancelTokens.remove(cropName);
        _notify();
        rethrow;
      }
    }
  }

  Future<void> deleteModel(String cropName) async {
    await _downloadService.deleteModel(cropName);
    _modelStatuses[cropName] = ModelDownloadStatus.notDownloaded;
    _totalSize = await _downloadService.getTotalSize();
    _notify();
  }

  Future<void> cancelDownload(String cropName) async {
    try {
      // Cancel the HTTP request using the cancel token
      final cancelToken = _cancelTokens[cropName];
      if (cancelToken != null && !cancelToken.isCancelled) {
        cancelToken.cancel('Download cancelled by user');
      }

      // Delete any partial download file
      await _downloadService.waitForDownload(cropName);

      // A cancelled replacement can leave the previously installed model intact.
      final installed = await _downloadService.isModelDownloaded(cropName);
      _modelStatuses[cropName] = installed
          ? ModelDownloadStatus.downloaded
          : ModelDownloadStatus.notDownloaded;
      _totalSize = await _downloadService.getTotalSize();
      _downloadProgress.remove(cropName);
      _cancelTokens.remove(cropName);

      _notify();
    } catch (e) {
      debugPrint('Error canceling download for $cropName: $e');
      // Even if there's an error, ensure we clean up the state
      _modelStatuses[cropName] = ModelDownloadStatus.error;
      _downloadProgress.remove(cropName);
      _cancelTokens.remove(cropName);
      _notify();
    }
  }

  Future<void> refresh() async {
    await initialize();
  }

  @override
  void dispose() {
    _disposed = true;
    // Cancel all active downloads when provider is disposed
    for (final token in _cancelTokens.values) {
      if (!token.isCancelled) {
        token.cancel('Provider disposed');
      }
    }
    _cancelTokens.clear();
    super.dispose();
  }
}

enum ModelDownloadStatus { notDownloaded, downloading, downloaded, error }
