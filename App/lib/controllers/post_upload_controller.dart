import 'package:agrhi/models/post_upload_task.dart';
import 'package:agrhi/services/session_coordinator.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:agrhi/services/native_app_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:agrhi/services/video_processing_service.dart';
import 'package:agrhi/services/community_service.dart';

class PostUploadController extends ChangeNotifier {
  PostUploadController._();
  static final PostUploadController instance = PostUploadController._();

  final List<PostUploadTask> _tasks = [];
  List<PostUploadTask> get activeTasks => List.unmodifiable(_tasks);

  void _notify() => notifyListeners();
  void clearFinishedTasks() {
    _tasks.removeWhere(
      (task) => task.isFailed || task.phase == UploadPhase.done,
    );
    _notify();
  }

  // ── Determine media type from file extension ──────────────────────────────
  static String? _detectMediaType(File? file) {
    if (file == null) return null;
    final ext = file.path.split('.').last.toLowerCase();
    const videoExts = {'mp4', 'mov', 'avi', 'mkv', 'webm', '3gp'};
    const imageExts = {'jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'};
    if (videoExts.contains(ext)) return 'video';
    if (imageExts.contains(ext)) return 'image';
    return null;
  }

  // ── Real compression — returns compressed File or original on failure ──────
  static Future<File> _compress(
    PostUploadTask task,
    File original,
    void Function() notify,
  ) async {
    final mediaType = task.mediaType ?? _detectMediaType(original);

    try {
      if (mediaType == 'video') {
        return await VideoProcessingService.process(
          original,
          onProgress: (progress) {
            task.compressProgress = progress.clamp(0.0, 0.95);
            notify();
          },
        );
      } else if (mediaType == 'image') {
        // ── Image compression via native codecs ────────────────────
        task.compressProgress = 0.2;
        notify();

        final outDir = await getTemporaryDirectory();
        final outPath =
            '${outDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        task.compressProgress = 0.5;
        notify();

        final result = await NativeAppService.compressImage(
          original.path,
          outPath,
        );

        task.compressProgress = 0.9;
        notify();

        return result;
      }
    } catch (e) {
      // Compression failed — fall back to original file, upload continues
      debugPrint('[PostUploadController] Compression error: $e');
    }

    return original; // fallback
  }

  // ── Submit a new post ─────────────────────────────────────────────────────
  Future<void> submitPost({
    required String content,
    required String category,
    File? mediaFile,
    String? mediaType,
    required void Function(Map<String, dynamic> post) onSuccess,
    required void Function(Object error) onError,
  }) async {
    return SessionCoordinator.instance.run(() async {
      final task = PostUploadTask(
        tempId: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        category: category,
        mediaFile: mediaFile,
        mediaType: mediaType ?? _detectMediaType(mediaFile),
      );
      _tasks.add(task);
      _notify();

      try {
        // ── Compression phase ────────────────────────────────────────────────
        File? fileToUpload = mediaFile;
        if (mediaFile != null) {
          task.phase = UploadPhase.compressing;
          task.compressProgress = 0.0;
          _notify();

          fileToUpload = await _compress(task, mediaFile, _notify);

          task.compressProgress = 1.0;
          _notify();
        }

        // ── Upload phase ─────────────────────────────────────────────────────
        task.phase = UploadPhase.uploading;
        task.uploadProgress = 0.0;
        _notify();

        final created = await CommunityService.createPost(
          content: content,
          category: category,
          mediaFile: fileToUpload,
          onSendProgress: (sent, total) {
            if (total > 0) {
              task.uploadProgress = sent / total;
              _notify();
            }
          },
        );

        task.phase = UploadPhase.done;
        task.uploadProgress = 1.0;
        _notify();

        onSuccess(created);

        // Keep task visible briefly so listeners see the done state
        await Future.delayed(const Duration(seconds: 1));
        _tasks.removeWhere((t) => t.tempId == task.tempId);
        _notify();
      } catch (e) {
        task.phase = UploadPhase.failed;
        task.errorMessage = e.toString();
        _notify();
        onError(e);
      }
    });
  }

  // ── Retry a failed task ───────────────────────────────────────────────────
  Future<void> retryTask(
    String tempId,
    void Function(Map<String, dynamic> post) onSuccess,
    void Function(Object error) onError,
  ) async {
    final taskIndex = _tasks.indexWhere((t) => t.tempId == tempId);
    if (taskIndex == -1) return;

    final task = _tasks[taskIndex];

    // Reset state on the same task object
    task.phase = UploadPhase.preparing;
    task.compressProgress = 0.0;
    task.uploadProgress = 0.0;
    task.errorMessage = null;
    _notify();

    try {
      // ── Compression phase ────────────────────────────────────────────────
      File? fileToUpload = task.mediaFile;
      if (task.mediaFile != null) {
        task.phase = UploadPhase.compressing;
        task.compressProgress = 0.0;
        _notify();

        fileToUpload = await _compress(task, task.mediaFile!, _notify);

        task.compressProgress = 1.0;
        _notify();
      }

      // ── Upload phase ─────────────────────────────────────────────────────
      task.phase = UploadPhase.uploading;
      task.uploadProgress = 0.0;
      _notify();

      final created = await CommunityService.createPost(
        content: task.content,
        category: task.category,
        mediaFile: fileToUpload,
        onSendProgress: (sent, total) {
          if (total > 0) {
            task.uploadProgress = sent / total;
            _notify();
          }
        },
      );

      task.phase = UploadPhase.done;
      task.uploadProgress = 1.0;
      _notify();
      onSuccess(created);

      await Future.delayed(const Duration(seconds: 1));
      _tasks.removeAt(taskIndex);
      _notify();
    } catch (e) {
      task.phase = UploadPhase.failed;
      task.errorMessage = e.toString();
      _notify();
      onError(e);
    }
  }

  // ── Cancel / dismiss a failed task ───────────────────────────────────────
  void dismissTask(String tempId) {
    _tasks.removeWhere((t) => t.tempId == tempId);
    _notify();
  }
}
