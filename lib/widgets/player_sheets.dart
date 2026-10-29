import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' show AudioTrack, SubtitleTrack;
import 'package:provider/provider.dart';

import '../services/player_service.dart';
import '../theme/app_theme.dart';

const List<double> kSpeedOptions = [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0];

String speedLabel(double value) {
  final text = value.toStringAsFixed(2);
  return '${text.replaceAll(RegExp(r'0$'), '').replaceAll(RegExp(r'\.$'), '.0')}x';
}

String _clock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

Widget _handle() => Center(
      child: Container(
        width: 42,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 8),
        decoration: BoxDecoration(
          color: const Color(0x33FFFFFF),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );

Widget _title(BuildContext context, String title, {String? subtitle}) => Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ],
      ),
    );

Future<void> showSpeedSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          _title(sheetContext, 'Playback speed'),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: kSpeedOptions.map((value) {
                final active = (player.speed - value).abs() < 0.01;
                return GestureDetector(
                  onTap: () {
                    player.setSpeed(value);
                    Navigator.of(sheetContext).pop();
                  },
                  child: Container(
                    width: 76,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: active ? AppColors.lime : AppColors.cardSoft,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: active ? AppColors.lime : AppColors.line),
                    ),
                    child: Text(
                      speedLabel(value),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: active ? const Color(0xFF10160A) : AppColors.text,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 22),
        ],
      ),
    ),
  );
}

Future<void> showSyncSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final delay = player.audioDelay;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(),
                _title(sheetContext, 'Audio sync',
                    subtitle: 'Aawaz aage-peeche karke lips se match karo'),
                Row(
                  children: [
                    const Text('Aawaz pehle',
                        style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                    Expanded(
                      child: Slider(
                        value: delay.clamp(-2.0, 2.0),
                        min: -2,
                        max: 2,
                        divisions: 80,
                        onChanged: (value) {
                          player.setAudioDelay(value);
                          setSheetState(() {});
                        },
                      ),
                    ),
                    const Text('Aawaz baad me',
                        style: TextStyle(fontSize: 10.5, color: AppColors.muted)),
                  ],
                ),
                Center(
                  child: Text(
                    '${delay >= 0 ? '+' : ''}${delay.toStringAsFixed(2)} s',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () {
                      player.setAudioDelay(0);
                      setSheetState(() {});
                    },
                    child: const Text('Reset', style: TextStyle(color: AppColors.lime)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showFiltersSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Widget slider(String label, double value, ValueChanged<double> onChange) {
          return Row(
            children: [
              SizedBox(
                width: 84,
                child: Text(label,
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ),
              Expanded(
                child: Slider(
                  value: value.clamp(-100.0, 100.0),
                  min: -100,
                  max: 100,
                  divisions: 40,
                  onChanged: (next) {
                    onChange(next);
                    setSheetState(() {});
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  value.round().toString(),
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(),
                _title(sheetContext, 'Picture & sound',
                    subtitle: 'Video ko sharpen karo ya colours badlo'),
                Row(
                  children: [
                    const Expanded(
                      child: Text('HD boost',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                    Switch(
                      value: player.hdBoost,
                      activeColor: AppColors.lime,
                      onChanged: (_) {
                        player.toggleHdBoost();
                        setSheetState(() {});
                      },
                    ),
                  ],
                ),
                slider('Brightness', player.brightness,
                    (v) => player.setFilter(brightness: v)),
                slider('Contrast', player.contrast, (v) => player.setFilter(contrast: v)),
                slider('Saturation', player.saturation,
                    (v) => player.setFilter(saturation: v)),
                slider('Gamma', player.gamma, (v) => player.setFilter(gamma: v)),
                const SizedBox(height: 8),
                Text(
                  'HD boost contrast aur saturation thoda badha deta hai — purane low-quality videos me farak dikhta hai.',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.muted.withOpacity(0.9), height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

Future<void> showSubtitleSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  final tracks = player.subtitleTracks;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          _title(sheetContext, 'Captions',
              subtitle: player.subtitlePath == null
                  ? 'Video ke andar ke subtitle tracks'
                  : 'Sidecar file mili: ${player.subtitlePath!.split('/').last}'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.close_rounded, size: 20, color: AppColors.muted),
            title: const Text('Off', style: TextStyle(fontSize: 13.5)),
            onTap: () {
              player.disableSubtitles();
              Navigator.of(sheetContext).pop();
            },
          ),
          ...tracks.map((track) {
            final label = track.title ?? track.language ?? 'Track';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.subtitles_rounded, size: 20, color: AppColors.lime),
              title: Text(label, style: const TextStyle(fontSize: 13.5)),
              subtitle: track.language == null
                  ? null
                  : Text(track.language!,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              onTap: () {
                player.useSubtitle(track);
                Navigator.of(sheetContext).pop();
              },
            );
          }),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.timer_outlined, size: 20, color: AppColors.lime),
            title: const Text('Caption delay', style: TextStyle(fontSize: 13.5)),
            onTap: () {
              Navigator.of(sheetContext).pop();
              showSubtitleDelaySheet(context);
            },
          ),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 24, 18),
              child: Text(
                'Is video me koi subtitle track nahi mila. Video ke saath wahi naam rakh ke .srt file rakho to app khud utha lega.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
              ),
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

Future<void> showQueueSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  final queue = player.queue;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: SizedBox(
        height: MediaQuery.of(sheetContext).size.height * 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _handle(),
            _title(sheetContext, 'Queue', subtitle: '${queue.length} videos'),
            Expanded(
              child: ListView.builder(
                itemCount: queue.length,
                itemBuilder: (context, index) {
                  final video = queue[index];
                  final active = index == player.index;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(
                      active ? Icons.play_arrow_rounded : Icons.movie_outlined,
                      size: 20,
                      color: active ? AppColors.lime : AppColors.muted,
                    ),
                    title: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: active ? AppColors.lime : AppColors.text,
                      ),
                    ),
                    subtitle: Text(
                      '${video.resolution} · ${video.durationLabel}',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                    ),
                    onTap: () {
                      player.playAt(index);
                      Navigator.of(sheetContext).pop();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

String timeLabel(Duration value) => _clock(value);


Future<void> showAudioSheet(BuildContext context) {
  final player = context.read<PlayerService>();
  final tracks = player.audioTracks;
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _handle(),
          _title(sheetContext, 'Audio track',
              subtitle: tracks.length > 1
                  ? '${tracks.length} tracks mile — jo chahiye chuno'
                  : 'Video me ek hi audio track hai'),
          ...tracks.map((track) {
            final label = track.title ?? track.language ?? 'Track ${track.id}';
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.audiotrack_rounded, size: 20, color: AppColors.lime),
              title: Text(label, style: const TextStyle(fontSize: 13.5)),
              subtitle: track.language == null
                  ? null
                  : Text(track.language!,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              onTap: () {
                player.useAudioTrack(track);
                Navigator.of(sheetContext).pop();
              },
            );
          }),
          if (tracks.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 6, 24, 18),
              child: Text('Abhi koi track list nahi mili.',
                  style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
            ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

Future<void> showSubtitleDelaySheet(BuildContext context) {
  final player = context.read<PlayerService>();
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        final delay = player.subtitleDelay;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _handle(),
                _title(sheetContext, 'Caption delay',
                    subtitle: 'Captions ko aage-peeche karo'),
                Slider(
                  value: delay.clamp(-10.0, 10.0),
                  min: -10,
                  max: 10,
                  divisions: 80,
                  onChanged: (value) {
                    player.setSubtitleDelay(value);
                    setSheetState(() {});
                  },
                ),
                Center(
                  child: Text('${delay >= 0 ? '+' : ''}${delay.toStringAsFixed(2)} s',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                Center(
                  child: TextButton(
                    onPressed: () {
                      player.setSubtitleDelay(0);
                      setSheetState(() {});
                    },
                    child: const Text('Reset', style: TextStyle(color: AppColors.lime)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
