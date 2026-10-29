import 'dart:typed_data';

import 'package:flutter/services.dart';

class VideoMeta {
  const VideoMeta({required this.duration, required this.width, required this.height});

  final Duration duration;
  final int width;
  final int height;
}

/// Talks to the small native helper in MainActivity.kt, which uses Android's
/// MediaMetadataRetriever — so we get a real thumbnail, duration and
/// resolution for any file, not just the ones the gallery indexed.
class MediaProbe {
  MediaProbe._();

  static const MethodChannel _channel = MethodChannel('vidhive/media');

  static Future<VideoMeta?> meta(String path) async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('meta', {'path': path});
      if (result == null) return null;
      return VideoMeta(
        duration: Duration(milliseconds: (result['duration'] as num?)?.toInt() ?? 0),
        width: (result['width'] as num?)?.toInt() ?? 0,
        height: (result['height'] as num?)?.toInt() ?? 0,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> thumbnail(String path, {int width = 360}) async {
    try {
      return await _channel.invokeMethod<Uint8List>('thumb', {
        'path': path,
        'width': width,
      });
    } catch (_) {
      return null;
    }
  }
}
