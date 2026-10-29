/// One video file found on the device.
class VideoItem {
  const VideoItem({
    required this.path,
    required this.title,
    required this.folder,
    required this.date,
    this.duration = Duration.zero,
    this.width = 0,
    this.height = 0,
    this.sizeBytes = 0,
  });

  final String path;
  final String title;
  final String folder;
  final DateTime date;
  final Duration duration;
  final int width;
  final int height;
  final int sizeBytes;

  String get id => path;

  VideoItem copyWith({
    String? title,
    Duration? duration,
    int? width,
    int? height,
    int? sizeBytes,
  }) =>
      VideoItem(
        path: path,
        title: title ?? this.title,
        folder: folder,
        date: date,
        duration: duration ?? this.duration,
        width: width ?? this.width,
        height: height ?? this.height,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );

  String get resolution {
    if (width > 0 && height > 0) {
      final short = width < height ? width : height;
      if (short >= 2000) return '4K';
      if (short >= 1400) return '1440p';
      if (short >= 1000) return '1080p';
      if (short >= 700) return '720p';
      if (short >= 400) return '480p';
      return '${width}x$height';
    }
    final name = title.toLowerCase();
    if (name.contains('2160') || name.contains('4k')) return '4K';
    if (name.contains('1440')) return '1440p';
    if (name.contains('1080')) return '1080p';
    if (name.contains('720')) return '720p';
    if (name.contains('480')) return '480p';
    return '—';
  }

  String get durationLabel {
    final d = duration;
    if (d.inSeconds <= 0) return '--:--';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$s';
    return '$m:$s';
  }

  String get dateLabel {
    final d = date;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }
}
