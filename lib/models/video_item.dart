/// One video on the device.
class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.duration,
    required this.date,
    required this.width,
    required this.height,
    required this.folder,
    this.path,
  });

  final String id;
  final String title;
  final Duration duration;
  final DateTime date;
  final int width;
  final int height;
  final String folder;

  /// Filled in when the file path has been resolved.
  final String? path;

  VideoItem withPath(String value) => VideoItem(
        id: id,
        title: title,
        duration: duration,
        date: date,
        width: width,
        height: height,
        folder: folder,
        path: value,
      );

  String get resolution {
    if (width <= 0 || height <= 0) return '—';
    final short = width < height ? width : height;
    if (short >= 2000) return '4K';
    if (short >= 1400) return '1440p';
    if (short >= 1000) return '1080p';
    if (short >= 700) return '720p';
    if (short >= 400) return '480p';
    return '${width}x$height';
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'duration': duration.inMilliseconds,
        'date': date.millisecondsSinceEpoch,
        'width': width,
        'height': height,
        'folder': folder,
        'path': path,
      };

  factory VideoItem.fromJson(Map<String, dynamic> json) => VideoItem(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? 'Video',
        duration: Duration(milliseconds: (json['duration'] as num?)?.toInt() ?? 0),
        date: DateTime.fromMillisecondsSinceEpoch((json['date'] as num?)?.toInt() ?? 0),
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        folder: json['folder'] as String? ?? '',
        path: json['path'] as String?,
      );
}
