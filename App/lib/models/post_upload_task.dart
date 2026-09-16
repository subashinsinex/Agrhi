import 'dart:io';

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
