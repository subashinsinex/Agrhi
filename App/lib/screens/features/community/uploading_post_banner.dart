import 'package:flutter/material.dart';
import '../../../../src/services/post_upload_manager.dart';

class UploadingPostBanner extends StatelessWidget {
  const UploadingPostBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PostUploadManager.instance,
      builder: (context, _) {
        final tasks = PostUploadManager.instance.activeTasks;
        if (tasks.isEmpty) return const SizedBox.shrink();
        return Column(
          children: tasks.map((t) => _TaskBanner(task: t)).toList(),
        );
      },
    );
  }
}

class _TaskBanner extends StatelessWidget {
  final PostUploadTask task;
  const _TaskBanner({required this.task});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(width: 44, height: 44, child: _buildThumb()),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: task.isFailed ? Colors.red : Colors.black87,
                  ),
                ),
                if (!task.isFailed) ...[
                  const SizedBox(height: 5),
                  if (_progress != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: _progress,
                        minHeight: 4,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          task.phase == UploadPhase.done ? Colors.green : color,
                        ),
                      ),
                    ),
                ] else
                  Text(
                    task.errorMessage ?? 'Something went wrong',
                    style: const TextStyle(fontSize: 11, color: Colors.red),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (task.phase == UploadPhase.done)
            const Icon(Icons.check_circle, color: Colors.green, size: 22)
          else if (task.isFailed)
            TextButton(
              onPressed: () => PostUploadManager.instance.retryTask(
                task.tempId,
                (_) {},
                (_) {},
              ),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 32),
              ),
              child: const Text('Retry'),
            ),
          // X icon removed
        ],
      ),
    );
  }

  Widget _buildThumb() {
    final file = task.mediaFile;

    if (file == null) {
      return Container(
        color: Colors.grey.shade200,
        child: const Icon(Icons.article_outlined, color: Colors.grey, size: 20),
      );
    }

    final ext = file.path.split('.').last.toLowerCase();
    final isVideo = {'mp4', 'mov', 'avi', 'mkv', 'webm'}.contains(ext);

    if (isVideo) {
      return Container(
        color: Colors.black87,
        child: const Icon(
          Icons.videocam_rounded,
          color: Colors.white54,
          size: 20,
        ),
      );
    }

    return Image.file(
      file,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        color: Colors.grey.shade200,
        child: const Icon(
          Icons.broken_image_outlined,
          color: Colors.grey,
          size: 20,
        ),
      ),
    );
  }

  String get _label => switch (task.phase) {
    UploadPhase.preparing => 'Initializing',
    UploadPhase.compressing when task.compressProgress == 0 => 'Initializing',
    UploadPhase.compressing =>
      'Compressing ${(task.compressProgress * 100).toStringAsFixed(0)}%',
    UploadPhase.uploading =>
      'Posting ${(task.uploadProgress * 100).toStringAsFixed(0)}%',
    UploadPhase.done => 'Posted ✓',
    UploadPhase.failed => 'Failed to post',
  };

  double? get _progress => switch (task.phase) {
    UploadPhase.preparing => null,
    UploadPhase.compressing when task.compressProgress == 0 => null,
    UploadPhase.compressing => task.compressProgress * 0.5,
    UploadPhase.uploading => 0.5 + task.uploadProgress * 0.5,
    UploadPhase.done => 1.0,
    UploadPhase.failed => 0.0,
  };
}
