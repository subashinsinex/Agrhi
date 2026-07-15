import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_compress/video_compress.dart';
import '../services/community_service.dart';

enum UploadPhase { preparing, compressing, uploading, done, failed }

class PostUploadTask {
  final String tempId;
  final String content;
  final String category;
  final File? mediaFile;
  final String? mediaType; // 'image' | 'video' | null

  UploadPhase phase;
  double compressProgress;
  double uploadProgress;
  bool get isFailed => phase == UploadPhase.failed;
  String? errorMessage;

  PostUploadTask({
    required this.tempId,
    required this.content,
    required this.category,
    required this.mediaFile,
    this.mediaType,
    this.phase = UploadPhase.preparing,
    this.compressProgress = 0.0,
    this.uploadProgress = 0.0,
    this.errorMessage,
  });
}

class PostUploadManager extends ChangeNotifier {
  PostUploadManager._();
  static final PostUploadManager instance = PostUploadManager._();

  final List<PostUploadTask> _tasks = [];
  List<PostUploadTask> get activeTasks => List.unmodifiable(_tasks);

  void _notify() => notifyListeners();

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
        // ── Video compression via video_compress ────────────────────────────
        final subscription = VideoCompress.compressProgress$.subscribe((p) {
          task.compressProgress = (p / 100).clamp(0.0, 0.95);
          notify();
        });

        final info = await VideoCompress.compressVideo(
          original.path,
          quality: VideoQuality.MediumQuality,
          deleteOrigin: false,
          includeAudio: true,
        );

        subscription.unsubscribe();

        if (info?.file != null) return info!.file!;
      } else if (mediaType == 'image') {
        // ── Image compression via flutter_image_compress ────────────────────
        task.compressProgress = 0.2;
        notify();

        final outDir = await getTemporaryDirectory();
        final outPath =
            '${outDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

        task.compressProgress = 0.5;
        notify();

        final result = await FlutterImageCompress.compressAndGetFile(
          original.path,
          outPath,
          quality: 82,
          minWidth: 1280,
          minHeight: 1280,
          keepExif: false,
        );

        task.compressProgress = 0.9;
        notify();

        if (result != null) return File(result.path);
      }
    } catch (e) {
      // Compression failed — fall back to original file, upload continues
      debugPrint('[PostUploadManager] Compression error: $e');
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
