import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class VideoCompressor {
  static const int _maxSeconds = 30;
  static const int _targetWidth = 720;

  static Future<File> compress(
    File videoFile, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      final dir = await getTemporaryDirectory();
      final outputPath = p.join(
        dir.path,
        '${DateTime.now().millisecondsSinceEpoch}.mp4',
      );

      final durationMs = await _getDurationMs(videoFile.path);
      final totalMs = durationMs > 0
          ? durationMs.clamp(0, _maxSeconds * 1000)
          : (_maxSeconds * 1000);

      if (onProgress != null) {
        FFmpegKitConfig.enableStatisticsCallback((stats) {
          final timeMs = stats.getTime();
          if (timeMs > 0) {
            onProgress((timeMs / totalMs).clamp(0.0, 1.0));
          }
        });
      }

      final command =
          '-i "${videoFile.path}" '
          '-t $_maxSeconds '
          '-vf "scale=\'min($_targetWidth,iw)\':-2" '
          '-vcodec libx264 '
          '-crf 28 '
          '-preset fast '
          '-acodec aac '
          '-b:a 128k '
          '-movflags +faststart '
          '-y '
          '"$outputPath"';

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      FFmpegKitConfig.enableStatisticsCallback(null);

      if (ReturnCode.isSuccess(returnCode)) {
        onProgress?.call(1.0);
        final compressed = File(outputPath);
        debugPrint(
          '✅ Compressed: '
          '${(videoFile.lengthSync() / 1024 / 1024).toStringAsFixed(1)}MB → '
          '${(compressed.lengthSync() / 1024 / 1024).toStringAsFixed(1)}MB',
        );
        return compressed;
      } else {
        final logs = await session.getAllLogsAsString();
        debugPrint('⚠️ FFmpeg failed: $logs');
        return videoFile;
      }
    } catch (e) {
      FFmpegKitConfig.enableStatisticsCallback(null);
      debugPrint('⚠️ VideoCompressor exception: $e');
      return videoFile;
    }
  }

  static Future<int> _getDurationMs(String videoPath) async {
    try {
      final session = await FFmpegKit.execute('-i "$videoPath" -f null -');
      final logs = await session.getAllLogsAsString() ?? '';
      final match = RegExp(
        r'Duration:\s*(\d+):(\d+):(\d+)\.(\d+)',
      ).firstMatch(logs);
      if (match != null) {
        final h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        final s = int.parse(match.group(3)!);
        final ms = int.parse(match.group(4)!) * 10;
        return ((h * 3600 + m * 60 + s) * 1000) + ms;
      }
    } catch (_) {}
    return 0;
  }

  static void cancel() => FFmpegKit.cancel();
}
