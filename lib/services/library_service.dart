import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/video_item.dart';
import 'media_probe.dart';

enum VideoSort { newest, oldest, name, duration }

/// Scans the phone's storage directly for video files (All files access), so
/// nothing depends on the gallery having indexed them.
class LibraryService extends ChangeNotifier {
  static const Set<String> videoExtensions = {
    'mp4', 'mkv', 'avi', 'mov', 'm4v', 'webm', 'flv', 'wmv', '3gp', '3g2',
    'ts', 'm2ts', 'mts', 'mpg', 'mpeg', 'rmvb', 'rm', 'ogv', 'divx', 'asf',
    'vob', 'f4v', 'dat', 'm2v', 'mxf',
  };

  static const List<String> _skipParts = [
    '/Android/data',
    '/Android/obb',
    '/Android/media',
    '/.thumbnails',
    '/.trashed',
    '/LOST.DIR',
    '/.cache',
  ];

  final List<VideoItem> _videos = [];
  final Map<String, Uint8List?> _thumbCache = {};

  bool _loading = false;
  bool _loadedOnce = false;
  bool _permissionDenied = false;
  bool _probeRunning = false;
  String? _error;
  VideoSort _sort = VideoSort.newest;
  String _query = '';
  int _scannedFiles = 0;

  List<VideoItem> get videos => _sorted(_filtered());
  List<VideoItem> get all => List.unmodifiable(_videos);
  bool get isLoading => _loading;
  bool get permissionDenied => _permissionDenied;
  bool get loadedOnce => _loadedOnce;
  bool get isProbing => _probeRunning;
  String? get error => _error;
  VideoSort get sort => _sort;
  String get query => _query;
  int get scannedFiles => _scannedFiles;
  int get videoCount => _videos.length;

  int get totalBytes => _videos.fold(0, (sum, video) => sum + video.sizeBytes);

  List<String> get folders {
    final names = <String>{};
    for (final video in _videos) {
      if (video.folder.isNotEmpty) names.add(video.folder);
    }
    return names.toList()..sort();
  }

  List<VideoItem> byFolder(String folder) =>
      _sorted(_videos.where((video) => video.folder == folder).toList());

  int countInFolder(String folder) =>
      _videos.where((video) => video.folder == folder).length;

  int bytesInFolder(String folder) => _videos
      .where((video) => video.folder == folder)
      .fold(0, (sum, video) => sum + video.sizeBytes);

  void setSort(VideoSort value) {
    _sort = value;
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  List<VideoItem> _filtered() {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return List<VideoItem>.from(_videos);
    return _videos
        .where((video) =>
            video.title.toLowerCase().contains(q) ||
            video.folder.toLowerCase().contains(q))
        .toList();
  }

  List<VideoItem> _sorted(List<VideoItem> list) {
    final copy = List<VideoItem>.from(list);
    switch (_sort) {
      case VideoSort.newest:
        copy.sort((a, b) => b.date.compareTo(a.date));
        break;
      case VideoSort.oldest:
        copy.sort((a, b) => a.date.compareTo(b.date));
        break;
      case VideoSort.name:
        copy.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case VideoSort.duration:
        copy.sort((a, b) => b.duration.compareTo(a.duration));
        break;
    }
    return copy;
  }

  /// Asks for "All files access" (Android 11+) or storage permission.
  Future<bool> requestPermission() async {
    try {
      if (Platform.isAndroid) {
        final manage = await Permission.manageExternalStorage.status;
        if (manage.isGranted) return true;
        final requested = await Permission.manageExternalStorage.request();
        if (requested.isGranted) return true;
        if (requested.isPermanentlyDenied) {
          await openAppSettings();
          return false;
        }
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
      final storage = await Permission.storage.request();
      return storage.isGranted;
    } catch (_) {
      return false;
    }
  }

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final granted = await requestPermission();
      if (!granted) {
        _permissionDenied = true;
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
        return;
      }
      _permissionDenied = false;
      await _scan();
    } catch (e) {
      _error = 'Storage read nahi hui';
      if (kDebugMode) debugPrint('scan failed: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
    unawaited(_probeMissing());
  }

  Future<void> _scan() async {
    final found = <VideoItem>[];
    _scannedFiles = 0;
    for (final root in await _roots()) {
      await _walk(Directory(root), found, depth: 0);
    }
    found.sort((a, b) => b.date.compareTo(a.date));
    _videos
      ..clear()
      ..addAll(found);
    _thumbCache.clear();
  }

  Future<List<String>> _roots() async {
    final roots = <String>[];
    const primary = '/storage/emulated/0';
    if (await Directory(primary).exists()) roots.add(primary);
    try {
      await for (final entity in Directory('/storage').list(followLinks: false)) {
        if (entity is! Directory) continue;
        final path = entity.path;
        if (path.contains('emulated') || path.contains('/self')) continue;
        roots.add(path);
      }
    } catch (_) {
      // Only the primary volume is readable.
    }
    return roots;
  }

  Future<void> _walk(Directory directory, List<VideoItem> out, {required int depth}) async {
    if (depth > 12 || out.length > 4000) return;
    List<FileSystemEntity> entries;
    try {
      entries = await directory.list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final entity in entries) {
      final path = entity.path;
      if (_skipParts.any(path.contains)) continue;
      if (entity is Directory) {
        await _walk(entity, out, depth: depth + 1);
        continue;
      }
      if (entity is! File) continue;
      final name = path.split('/').last;
      final dot = name.lastIndexOf('.');
      if (dot <= 0) continue;
      final extension = name.substring(dot + 1).toLowerCase();
      if (!videoExtensions.contains(extension)) continue;
      _scannedFiles++;
      try {
        final stat = await entity.stat();
        if (stat.size < 200 * 1024) continue;
        out.add(VideoItem(
          path: path,
          title: name.substring(0, dot),
          folder: _folderOf(path),
          date: stat.modified,
          sizeBytes: stat.size,
        ));
      } catch (_) {
        continue;
      }
    }
  }

  String _folderOf(String path) {
    final parts = path.split('/');
    if (parts.length < 2) return '';
    return parts[parts.length - 2];
  }

  /// Reads duration and resolution for videos that do not have them yet.
  Future<void> _probeMissing() async {
    if (_probeRunning) return;
    _probeRunning = true;
    try {
      final pending = _videos.where((video) => video.duration == Duration.zero).take(60).toList();
      for (final video in pending) {
        final meta = await MediaProbe.meta(video.path);
        if (meta == null) continue;
        final index = _videos.indexWhere((item) => item.path == video.path);
        if (index < 0) continue;
        _videos[index] = _videos[index].copyWith(
          duration: meta.duration,
          width: meta.width,
          height: meta.height,
        );
        notifyListeners();
      }
    } finally {
      _probeRunning = false;
      notifyListeners();
    }
  }

  /// Duration discovered during playback is remembered for the list.
  void rememberMeta(String path, {Duration? duration, int? width, int? height}) {
    final index = _videos.indexWhere((video) => video.path == path);
    if (index < 0) return;
    _videos[index] = _videos[index].copyWith(duration: duration, width: width, height: height);
    notifyListeners();
  }

  Future<Uint8List?> thumbnail(VideoItem video, {int width = 360}) async {
    if (_thumbCache.containsKey(video.path)) return _thumbCache[video.path];
    final bytes = await MediaProbe.thumbnail(video.path, width: width);
    _thumbCache[video.path] = bytes;
    return bytes;
  }

  Future<bool> delete(List<VideoItem> items) async {
    var deleted = false;
    for (final video in items) {
      try {
        final file = File(video.path);
        if (await file.exists()) await file.delete();
        _videos.removeWhere((item) => item.path == video.path);
        _thumbCache.remove(video.path);
        deleted = true;
      } catch (_) {
        // Some files are read-only; skip them.
      }
    }
    notifyListeners();
    return deleted;
  }

  Future<int> sizeOf(VideoItem video) async {
    if (video.sizeBytes > 0) return video.sizeBytes;
    try {
      return await File(video.path).length();
    } catch (_) {
      return 0;
    }
  }

  String? pathOf(VideoItem video) => video.path;
}

String formatBytes(int bytes) {
  if (bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes.toDouble();
  var unit = 0;
  while (value >= 1024 && unit < units.length - 1) {
    value /= 1024;
    unit++;
  }
  return '${value.toStringAsFixed(value >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
}
