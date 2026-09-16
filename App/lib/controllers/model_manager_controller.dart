import 'package:agrhi/models/model_download_status.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:agrhi/services/model_download_service.dart';
import 'package:agrhi/core/errors/app_failure.dart';
import 'package:agrhi/core/errors/error_reporter.dart';

class ModelManagerController extends ChangeNotifier {
  ModelManagerController({ModelDownloadService? downloadService})
    : _downloadService = downloadService ?? ModelDownloadService.instance;

  final ModelDownloadService _downloadService;
  final Map<String, CancelToken> _cancelTokens = {};

  Map<String, ModelDownloadStatus> _modelStatuses = {};
  final Map<String, double> _downloadProgress = {};
  bool _isLoading = false;
  bool _disposed = false;
  AppFailure? _failure;
  AppFailure? get failure => _failure;
  Future<void>? _initializing;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  double _totalSize = 0.0;

  Map<String, ModelDownloadStatus> get modelStatuses => _modelStatuses;
  Map<String, double> get downloadProgress => _downloadProgress;
  bool get isLoading => _isLoading;
  double get totalSize => _totalSize;

  Future<void> initialize() {
    if (_disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(
      () => _initializing = null,
    );
  }

  Future<void> _initialize() async {
    _isLoading = true;
    _failure = null;
    _notify();
    try {
      await _loadAllStatuses();
    } catch (error, stack) {
      ErrorReporter.report(error, stack, operation: 'model_library');
      _failure = AppFailure.from(error);
    } finally {
      _isLoading = false;
      _notify();
    }
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
    // Status inspection already validated the files; avoid a second disk scan.
    _totalSize = statuses.entries
        .where((entry) => entry.value == ModelDownloadStatus.downloaded)
        .fold(
          0.0,
          (size, entry) =>
              size + ModelDownloadService.modelInfo[entry.key]!.size,
        );
    for (final crop in _cancelTokens.keys) {
      statuses[crop] = ModelDownloadStatus.downloading;
    }
    _modelStatuses = statuses;
  }

  Future<void> downloadModel(String cropName) async {
    if (_disposed || _cancelTokens.containsKey(cropName)) return;
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
          if (!_disposed && total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            if (progress < 1 &&
                (progress - (_downloadProgress[cropName] ?? 0)).abs() < 0.01) {
              return;
            }
            _downloadProgress[cropName] = progress;
            _notify();
          }
        },
      );

      _modelStatuses[cropName] = ModelDownloadStatus.downloaded;
      _downloadProgress.remove(cropName);
      _cancelTokens.remove(cropName);
      await _refreshTotalSize();
      _notify();
    } catch (e) {
      // Check if error is due to cancellation
      if (e is DioException && CancelToken.isCancel(e)) {
        debugPrint('Download cancelled for $cropName');
        _modelStatuses[cropName] =
            await _downloadService.isModelDownloaded(cropName)
            ? ModelDownloadStatus.downloaded
            : ModelDownloadStatus.notDownloaded;
      } else {
        _modelStatuses[cropName] = ModelDownloadStatus.error;
        _downloadProgress.remove(cropName);
        _cancelTokens.remove(cropName);
        _notify();
        rethrow;
      }
    } finally {
      _downloadProgress.remove(cropName);
      _cancelTokens.remove(cropName);
      _notify();
    }
  }

  Future<void> _refreshTotalSize() =>
      ErrorReporter.background('model_storage_size', () async {
        final size = await _downloadService.getTotalSize();
        if (!_disposed) _totalSize = size;
      });

  Future<void> deleteModel(String cropName) async {
    await _downloadService.deleteModel(cropName);
    _modelStatuses[cropName] = ModelDownloadStatus.notDownloaded;
    await _refreshTotalSize();
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
      await _refreshTotalSize();
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
