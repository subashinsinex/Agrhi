import 'dart:io';
import 'package:light_compressor_v2/light_compressor_v2.dart';

/// Serializes trimming and upload compression through the native encoder.
class VideoProcessingService {
  static final _compressor = LightCompressor();
  static Future<void> _queue = Future.value();

  static Future<File> process(
    File input, {
    Duration? start,
    Duration? end,
    void Function(double)? onProgress,
  }) {
    if ((start == null) != (end == null) ||
        (start != null && (start.isNegative || end! <= start))) {
      return Future.error(ArgumentError('Invalid video trim range'));
    }
    final result = _queue.then((_) async {
      final subscription = _compressor.onProgressUpdated.listen(
        (percent) => onProgress?.call((percent / 100).clamp(0.0, 1.0)),
        onError: (Object _) {},
      );
      try {
        final output = await _compressor.compressVideo(
          path: input.path,
          videoQuality: start == null ? VideoQuality.medium : VideoQuality.high,
          android: AndroidConfig(isSharedStorage: false),
          ios: IOSConfig(saveInGallery: false),
          video: Video(
            videoName: 'agrhi_${DateTime.now().microsecondsSinceEpoch}',
          ),
          disableAudio: false,
          isMinBitrateCheckEnabled: false,
          edit: start == null
              ? null
              : VideoEdit(
                  trimStartMs: start.inMilliseconds,
                  trimEndMs: end!.inMilliseconds,
                ),
        );
        if (output is! OnSuccess) {
          throw StateError('Video processing failed: $output');
        }
        final file = File(output.destinationPath);
        if (!await file.exists() || await file.length() == 0) {
          throw StateError('Video processing returned an empty file');
        }
        return file;
      } finally {
        await subscription.cancel();
      }
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}
