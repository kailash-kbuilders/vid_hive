import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/video_item.dart';
import 'library_service.dart';

/// The video engine. media_kit (libmpv) plays almost every container and codec,
/// so files the phone's own player refuses still play — and it decodes in
/// hardware where possible, which is what keeps 4K smooth on weaker phones.
class PlayerService extends ChangeNotifier {
  PlayerService(this._library) {
    _player = Player();
    controller = VideoController(_player);
    _bind();
  }

  final LibraryService _library;
  late final Player _player;
  late final VideoController controller;

  final List<VideoItem> _queue = [];
  int _index = 0;
  VideoItem? _current;

  bool _playing = false;
  bool _buffering = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _speed = 1.0;
  double _volume = 100;
  double _audioDelay = 0;
  bool _hdBoost = false;
  bool _filtersOpen = false;
  double _brightness = 0;
  double _contrast = 0;
  double _saturation = 0;
  double _gamma = 0;
  String? _subtitlePath;
  List<SubtitleTrack> _subtitleTracks = const [];
  String? _error;
  Timer? _resumeTimer;
  SharedPreferences? _prefs;

  VideoItem? get current => _current;
  List<VideoItem> get queue => List.unmodifiable(_queue);
  int get index => _index;
  bool get isPlaying => _playing;
  bool get isBuffering => _buffering;
  Duration get position => _position;
  Duration get duration => _duration == Duration.zero ? (_current?.duration ?? Duration.zero) : _duration;
  double get speed => _speed;
  double get volume => _volume;
  double get audioDelay => _audioDelay;
  bool get hdBoost => _hdBoost;
  bool get filtersOpen => _filtersOpen;
  double get brightness => _brightness;
  double get contrast => _contrast;
  double get saturation => _saturation;
  double get gamma => _gamma;
  String? get subtitlePath => _subtitlePath;
  List<SubtitleTrack> get subtitleTracks => _subtitleTracks;
  String? get error => _error;
  bool get hasNext => _index + 1 < _queue.length;
  bool get hasPrevious => _index > 0;

  Future<void> _bind() async {
    _prefs = await SharedPreferences.getInstance();
    _player.stream.playing.listen((value) {
      _playing = value;
      if (value) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
        _saveResume();
      }
      notifyListeners();
    });
    _player.stream.buffering.listen((value) {
      _buffering = value;
      notifyListeners();
    });
    _player.stream.position.listen((value) {
      _position = value;
      notifyListeners();
    });
    _player.stream.duration.listen((value) {
      _duration = value;
      final video = _current;
      if (video != null && value > Duration.zero && video.duration != value) {
        _library.rememberMeta(video.path, duration: value);
      }
      notifyListeners();
    });
    _player.stream.tracks.listen((value) {
      _subtitleTracks = value.subtitle;
      notifyListeners();
    });
    _player.stream.completed.listen((value) {
      if (value) {
        if (hasNext) {
          next();
        } else {
          _player.pause();
        }
      }
    });
    _player.stream.error.listen((value) {
      _error = 'Playback error: $value';
      notifyListeners();
    });
    _resumeTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_playing) _saveResume();
    });
  }

  // ------------------------------------------------------------- playback ---

  Future<void> open(List<VideoItem> videos, int startIndex) async {
    if (videos.isEmpty) return;
    _queue
      ..clear()
      ..addAll(videos);
    _index = startIndex.clamp(0, videos.length - 1);
    await _openCurrent();
  }

  Future<void> _openCurrent() async {
    final video = _queue[_index];
    _current = video;
    _error = null;
    _position = Duration.zero;
    _duration = video.duration;
    notifyListeners();

    final path = _library.pathOf(video);
    if (path == null) {
      _error = 'Ye video khol nahi paya';
      notifyListeners();
      return;
    }
    try {
      await _player.open(Media(path), play: true);
      await _player.setRate(_speed);
      await _player.setVolume(_volume);
      _applyFilters();
      await _applySubtitleFor(path);
      final resume = _resumeFor(video.id);
      if (resume > const Duration(seconds: 3) && resume < video.duration) {
        await _player.seek(resume);
      }
      WakelockPlus.enable();
    } catch (_) {
      _error = 'Video play nahi hua';
    }
    notifyListeners();
  }

  Future<void> toggle() => _player.playOrPause();

  Future<void> play() => _player.play();

  Future<void> pause() => _player.pause();

  Future<void> seek(Duration to) async {
    var target = to;
    if (target.isNegative) target = Duration.zero;
    final total = duration;
    if (total > Duration.zero && target > total) target = total;
    await _player.seek(target);
  }

  Future<void> skip(Duration by) => seek(_position + by);

  Future<void> next() async {
    if (!hasNext) return;
    _index++;
    await _openCurrent();
  }

  Future<void> previous() async {
    if (!hasPrevious) {
      await seek(Duration.zero);
      return;
    }
    _index--;
    await _openCurrent();
  }

  Future<void> playAt(int value) async {
    if (value < 0 || value >= _queue.length) return;
    _index = value;
    await _openCurrent();
  }

  Future<void> setSpeed(double value) async {
    _speed = value;
    await _player.setRate(value);
    notifyListeners();
  }

  Future<void> setVolume(double value) async {
    _volume = value.clamp(0, 100);
    await _player.setVolume(_volume);
    notifyListeners();
  }

  /// Positive moves the audio later, negative earlier — used to fix lip sync.
  Future<void> setAudioDelay(double seconds) async {
    _audioDelay = seconds.clamp(-10.0, 10.0);
    _setMpv('audio-delay', _audioDelay.toStringAsFixed(3));
    notifyListeners();
  }

  void toggleHdBoost() {
    _hdBoost = !_hdBoost;
    if (_hdBoost) {
      _contrast = 12;
      _saturation = 10;
      _brightness = 2;
    } else {
      _contrast = 0;
      _saturation = 0;
      _brightness = 0;
    }
    _applyFilters();
    notifyListeners();
  }

  void setFilter({double? brightness, double? contrast, double? saturation, double? gamma}) {
    if (brightness != null) _brightness = brightness;
    if (contrast != null) _contrast = contrast;
    if (saturation != null) _saturation = saturation;
    if (gamma != null) _gamma = gamma;
    _applyFilters();
    notifyListeners();
  }

  void setFiltersOpen(bool value) {
    _filtersOpen = value;
    notifyListeners();
  }

  void _applyFilters() {
    _setMpv('brightness', _brightness.round().toString());
    _setMpv('contrast', _contrast.round().toString());
    _setMpv('saturation', _saturation.round().toString());
    _setMpv('gamma', _gamma.round().toString());
  }

  /// mpv properties — silently ignored on platforms without them.
  void _setMpv(String name, String value) {
    try {
      (_player.platform as dynamic).setProperty(name, value);
    } catch (_) {
      // Property not supported here.
    }
  }

  // ------------------------------------------------------------ subtitles ---

  Future<void> _applySubtitleFor(String videoPath) async {
    _subtitlePath = null;
    try {
      final dot = videoPath.lastIndexOf('.');
      final base = dot > 0 ? videoPath.substring(0, dot) : videoPath;
      for (final extension in ['.srt', '.vtt', '.ass']) {
        final candidate = File('$base$extension');
        if (await candidate.exists()) {
          _subtitlePath = candidate.path;
          await _player.setSubtitleTrack(SubtitleTrack.uri(candidate.path));
          return;
        }
      }
    } catch (_) {
      // No sidecar subtitle.
    }
  }

  Future<void> useSubtitle(SubtitleTrack track) async {
    await _player.setSubtitleTrack(track);
    notifyListeners();
  }

  Future<void> disableSubtitles() async {
    await _player.setSubtitleTrack(SubtitleTrack.no());
    notifyListeners();
  }

  // -------------------------------------------------------------- resume ---

  Duration _resumeFor(String id) {
    final value = _prefs?.getInt('resume_$id') ?? 0;
    return Duration(milliseconds: value);
  }

  Duration resumePositionFor(VideoItem video) => _resumeFor(video.id);

  void _saveResume() {
    final video = _current;
    if (video == null) return;
    if (_position.inSeconds <= 3) return;
    _prefs?.setInt('resume_${video.id}', _position.inMilliseconds);
  }

  Future<void> clearResume(VideoItem video) async {
    await _prefs?.remove('resume_${video.id}');
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _saveResume();
    _resumeTimer?.cancel();
    WakelockPlus.disable();
    _player.dispose();
    super.dispose();
  }
}
