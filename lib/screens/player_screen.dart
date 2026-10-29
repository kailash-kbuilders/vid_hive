import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import 'package:screen_brightness/screen_brightness.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/player_sheets.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  static const MethodChannel _pipChannel = MethodChannel('vidhive/pip');

  bool _controls = true;
  bool _locked = false;
  bool _landscape = false;
  Timer? _hideTimer;
  double? _seekTarget;
  double? _brightnessLevel;
  double? _volumeLevel;
  String _gestureSide = '';
  double _dragStart = 0;
  final ScreenBrightness _screen = ScreenBrightness();

  @override
  void initState() {
    super.initState();
    _scheduleHide();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _screen.resetApplicationScreenBrightness().catchError((Object _) {});
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    super.dispose();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controls = false);
    });
  }

  void _toggleControls() {
    setState(() => _controls = !_controls);
    if (_controls) _scheduleHide();
  }

  Future<void> _toggleOrientation() async {
    setState(() => _landscape = !_landscape);
    if (_landscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    }
  }

  Future<void> _enterPip() async {
    try {
      await _pipChannel.invokeMethod('enter');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Is device pe PiP available nahi hai')),
      );
    }
  }

  // ------------------------------------------------------------ gestures ---

  void _onVerticalStart(DragStartDetails details, double width) {
    final player = context.read<PlayerService>();
    _gestureSide = details.localPosition.dx < width / 2 ? 'brightness' : 'volume';
    _dragStart = _gestureSide == 'brightness' ? (_brightnessLevel ?? 0.6) : player.volume;
  }

  void _onVerticalUpdate(DragUpdateDetails details, double height) {
    final delta = -details.delta.dy / (height * 0.8);
    if (_gestureSide == 'brightness') {
      final next = (_dragStart + delta).clamp(0.02, 1.0);
      _dragStart = next;
      setState(() => _brightnessLevel = next);
      _screen.setApplicationScreenBrightness(next).catchError((Object _) {});
    } else {
      final player = context.read<PlayerService>();
      final next = (_dragStart + delta * 100).clamp(0.0, 100.0);
      _dragStart = next;
      setState(() => _volumeLevel = next);
      player.setVolume(next);
    }
  }

  void _onVerticalEnd(DragEndDetails details) {
    Future.delayed(const Duration(milliseconds: 700), () {
      if (!mounted) return;
      setState(() {
        _brightnessLevel = null;
        _volumeLevel = null;
      });
    });
  }

  void _onHorizontalStart(DragStartDetails details) {
    _dragStart = context.read<PlayerService>().position.inMilliseconds.toDouble();
  }

  void _onHorizontalUpdate(DragUpdateDetails details, double width) {
    final player = context.read<PlayerService>();
    final total = player.duration.inMilliseconds.toDouble();
    final delta = (details.delta.dx / width) * 90000;
    final next = ((_seekTarget ?? _dragStart) + delta).clamp(0.0, total <= 0 ? 1.0 : total);
    _dragStart = next;
    setState(() => _seekTarget = next);
  }

  void _onHorizontalEnd(DragEndDetails details) {
    final target = _seekTarget;
    if (target != null) {
      context.read<PlayerService>().seek(Duration(milliseconds: target.round()));
    }
    setState(() => _seekTarget = null);
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final video = player.current;
    if (video == null) {
      return Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kuch play nahi ho raha — wapas',
                style: TextStyle(color: AppColors.lime)),
          ),
        ),
      );
    }

    final total = player.duration;
    final position = _seekTarget != null
        ? Duration(milliseconds: _seekTarget!.round())
        : player.position;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTap: _toggleControls,
                  onDoubleTapDown: (details) {
                    final forward = details.localPosition.dx > constraints.maxWidth / 2;
                    player.skip(Duration(seconds: forward ? 10 : -10));
                    setState(() => _controls = true);
                    _scheduleHide();
                  },
                  onVerticalDragStart: _locked
                      ? null
                      : (details) => _onVerticalStart(details, constraints.maxWidth),
                  onVerticalDragUpdate: _locked
                      ? null
                      : (details) => _onVerticalUpdate(details, constraints.maxHeight),
                  onVerticalDragEnd: _locked ? null : _onVerticalEnd,
                  onHorizontalDragStart: _locked ? null : _onHorizontalStart,
                  onHorizontalDragUpdate: _locked
                      ? null
                      : (details) => _onHorizontalUpdate(details, constraints.maxWidth),
                  onHorizontalDragEnd: _locked ? null : _onHorizontalEnd,
                  child: Video(
                    controller: player.controller,
                    controls: NoVideoControls,
                    fit: player.videoFit,
                  ),
                );
              },
            ),
          ),
          if (player.isBuffering)
            const Center(child: CircularProgressIndicator(color: AppColors.lime)),
          if (_seekTarget != null)
            Positioned(
              top: 24,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xCC000000),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    '${timeLabel(position)} / ${timeLabel(total)}',
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                ),
              ),
            ),
          if (_brightnessLevel != null)
            _sideIndicator(
              top: 90,
              icon: Icons.brightness_6_rounded,
              value: _brightnessLevel!,
            ),
          if (_volumeLevel != null)
            _sideIndicator(
              top: 90,
              icon: Icons.volume_up_rounded,
              value: _volumeLevel! / 100,
            ),
          if (_controls) _overlay(context, player, position, total),
          if (_locked)
            Positioned(
              right: 16,
              top: 40,
              child: _roundButton(
                icon: Icons.lock_rounded,
                onTap: () {
                  setState(() {
                    _locked = false;
                    _controls = true;
                  });
                  _scheduleHide();
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _sideIndicator({required double top, required IconData icon, required double value}) {
    return Positioned(
      top: top,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xCC000000),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.lime),
              const SizedBox(width: 10),
              SizedBox(
                width: 90,
                height: 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: value.clamp(0.0, 1.0),
                    backgroundColor: const Color(0x33FFFFFF),
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text('${(value * 100).round()}',
                  style: const TextStyle(fontSize: 11, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _overlay(BuildContext context, PlayerService player, Duration position, Duration total) {
    final video = player.current!;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000), Color(0xCC000000)],
          stops: [0.0, 0.45, 1.0],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        video.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${video.resolution} · ${video.folder}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _locked = true;
                      _controls = false;
                    });
                  },
                  icon: const Icon(Icons.lock_open_rounded, size: 19),
                ),
                IconButton(
                  onPressed: _enterPip,
                  icon: const Icon(Icons.picture_in_picture_alt_rounded, size: 19),
                ),
                IconButton(
                  onPressed: _toggleOrientation,
                  icon: Icon(
                    _landscape
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    size: 21,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: player.previous,
                  icon: const Icon(Icons.skip_previous_rounded, size: 32),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: player.toggle,
                  child: Container(
                    height: 64,
                    width: 64,
                    decoration: BoxDecoration(
                      color: AppColors.lime,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.lime.withOpacity(0.3), blurRadius: 22),
                      ],
                    ),
                    child: Icon(
                      player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: 34,
                      color: const Color(0xFF10160A),
                    ),
                  ),
                ),
                const SizedBox(width: 18),
                IconButton(
                  onPressed: player.next,
                  icon: const Icon(Icons.skip_next_rounded, size: 32),
                ),
              ],
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Slider(
                value: position.inMilliseconds
                    .toDouble()
                    .clamp(0, total.inMilliseconds <= 0 ? 1 : total.inMilliseconds.toDouble()),
                max: total.inMilliseconds <= 0 ? 1 : total.inMilliseconds.toDouble(),
                onChanged: (value) => setState(() => _seekTarget = value),
                onChangeEnd: (value) {
                  player.seek(Duration(milliseconds: value.round()));
                  setState(() => _seekTarget = null);
                  _scheduleHide();
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(timeLabel(position),
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                  Text(timeLabel(total),
                      style: const TextStyle(fontSize: 10.5, color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _pill(
                    label: speedLabel(player.speed),
                    icon: Icons.speed_rounded,
                    onTap: () => showSpeedSheet(context),
                  ),
                  _pill(
                    label: 'Sync',
                    icon: Icons.sync_rounded,
                    active: player.audioDelay.abs() > 0.001,
                    onTap: () => showSyncSheet(context),
                  ),
                  _pill(
                    label: player.hdBoost ? 'HD on' : 'HD',
                    icon: Icons.hd_rounded,
                    active: player.hdBoost,
                    onTap: player.toggleHdBoost,
                  ),
                  _pill(
                    label: 'Picture',
                    icon: Icons.tune_rounded,
                    onTap: () => showFiltersSheet(context),
                  ),
                  _pill(
                    label: 'Captions',
                    icon: Icons.subtitles_rounded,
                    onTap: () => showSubtitleSheet(context),
                  ),
                  _pill(
                    label: 'Audio',
                    icon: Icons.audiotrack_rounded,
                    onTap: () => showAudioSheet(context),
                  ),
                  _pill(
                    label: switch (player.zoom) {
                      'fill' => 'Fill',
                      'stretch' => 'Stretch',
                      'crop' => 'Crop',
                      _ => 'Fit',
                    },
                    icon: Icons.aspect_ratio_rounded,
                    active: player.zoom != 'fit',
                    onTap: player.cycleZoom,
                  ),
                  _pill(
                    label: player.hardwareDecoding ? 'HW' : 'SW',
                    icon: Icons.memory_rounded,
                    active: !player.hardwareDecoding,
                    onTap: player.toggleDecoder,
                  ),
                  _pill(
                    label: 'Queue',
                    icon: Icons.queue_music_rounded,
                    onTap: () => showQueueSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        width: 42,
        decoration: BoxDecoration(
          color: const Color(0xAA000000),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.line),
        ),
        child: Icon(icon, size: 19, color: Colors.white),
      ),
    );
  }

  Widget _pill({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    bool active = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: active ? AppColors.lime : const Color(0x99000000),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.lime : AppColors.line),
          ),
          child: Row(
            children: [
              Icon(icon, size: 14, color: active ? const Color(0xFF10160A) : Colors.white),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: active ? const Color(0xFF10160A) : Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
