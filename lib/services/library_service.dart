import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/video_item.dart';

enum VideoSort { newest, oldest, name, duration }

/// Scans the device for videos through MediaStore (photo_manager), keeps the
/// folder structure, and can delete files the way a file manager does.
class LibraryService extends ChangeNotifier {
  final List<VideoItem> _videos = [];
  final List<AssetPathEntity> _paths = [];
  final Map<String, String> _pathCache = {};
  final Map<String, AssetEntity> _assets = {};

  bool _loading = false;
  bool _loadedOnce = false;
  bool _permissionDenied = false;
  String? _error;
  VideoSort _sort = VideoSort.newest;
  String _query = '';

  List<VideoItem> get videos => _sorted(_filtered());
  List<VideoItem> get all => List.unmodifiable(_videos);
  bool get isLoading => _loading;
  bool get permissionDenied => _permissionDenied;
  bool get loadedOnce => _loadedOnce;
  String? get error => _error;
  VideoSort get sort => _sort;
  String get query => _query;

  int get videoCount => _videos.length;

  List<String> get folders {
    final names = <String>{};
    for (final video in _videos) {
      if (video.folder.isNotEmpty) names.add(video.folder);
    }
    final list = names.toList()..sort();
    return list;
  }

  List<VideoItem> byFolder(String folder) =>
      _sorted(_videos.where((video) => video.folder == folder).toList());

  int countInFolder(String folder) =>
      _videos.where((video) => video.folder == folder).length;

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

  Future<void> load({bool force = false}) async {
    if (_loading) return;
    if (_loadedOnce && !force) return;
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final permission = await PhotoManager.requestPermissionExtend();
      if (!permission.isAuth && !permission.hasAccess) {
        _permissionDenied = true;
        _loading = false;
        _loadedOnce = true;
        notifyListeners();
        return;
      }
      _permissionDenied = false;

      final filter = FilterOptionGroup(
        orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      );
      final paths = await PhotoManager.getAssetPathList(
        type: RequestType.video,
        onlyAll: false,
        filterOption: filter,
      );
      _paths
        ..clear()
        ..addAll(paths);

      final collected = <VideoItem>[];
      for (final path in paths) {
        final total = await path.assetCountAsync;
        if (total == 0) continue;
        var page = 0;
        while (page * 200 < total && page < 10) {
          final assets = await path.getAssetListPaged(page: page, size: 200);
          if (assets.isEmpty) break;
          for (final asset in assets) {
            final item = _toVideo(asset, path.name);
            if (item == null) continue;
            _assets[item.id] = asset;
            collected.add(item);
          }
          page++;
        }
      }

      // The same file can appear in "All" and in its folder — keep one copy.
      final seen = <String>{};
      _videos.clear();
      for (final item in collected) {
        if (seen.add(item.id)) _videos.add(item);
      }
    } catch (e) {
      _error = 'Videos read nahi ho paye';
      if (kDebugMode) debugPrint('library scan failed: $e');
    } finally {
      _loading = false;
      _loadedOnce = true;
      notifyListeners();
    }
  }

  VideoItem? _toVideo(AssetEntity asset, String folder) {
    final title = (asset.title ?? '').trim();
    final name = title.isEmpty ? 'Video ${asset.id.substring(0, 4)}' : title;
    return VideoItem(
      id: asset.id,
      title: name,
      duration: Duration(seconds: asset.duration),
      date: asset.createDateTime,
      width: asset.width,
      height: asset.height,
      folder: folder,
      path: _pathCache[asset.id],
    );
  }

  /// Resolves the real file path (and remembers it).
  Future<String?> pathOf(VideoItem video) async {
    final cached = _pathCache[video.id] ?? video.path;
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final asset = _assets[video.id] ??
          (await AssetEntity.fromId(video.id));
      if (asset == null) return null;
      final file = await asset.file;
      final path = file?.path;
      if (path != null) _pathCache[video.id] = path;
      return path;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> thumbnail(VideoItem video, {int size = 320}) async {
    try {
      final asset = _assets[video.id] ?? (await AssetEntity.fromId(video.id));
      if (asset == null) return null;
      return asset.thumbnailDataWithSize(ThumbnailSize(size, (size * 9) ~/ 16));
    } catch (_) {
      return null;
    }
  }

  /// Deletes the file from the device (Android shows a system confirm dialog).
  Future<bool> delete(List<VideoItem> items) async {
    final ids = items.map((item) => item.id).toList();
    try {
      final result = await PhotoManager.editor.deleteWithIds(ids);
      if (result.isEmpty) return false;
      final removed = result.toSet();
      _videos.removeWhere((video) => removed.contains(video.id));
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<int> sizeOf(VideoItem video) async {
    final path = await pathOf(video);
    if (path == null) return 0;
    try {
      return await File(path).length();
    } catch (_) {
      return 0;
    }
  }

  Future<int> folderSize(String folder) async {
    var total = 0;
    for (final video in byFolder(folder).take(60)) {
      total += await sizeOf(video);
    }
    return total;
  }
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
