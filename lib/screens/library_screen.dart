import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/video_tile.dart';
import 'player_screen.dart';

class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key, this.folder, this.title});

  final String? folder;
  final String? title;

  Future<void> _open(BuildContext context, List<VideoItem> videos, int index) async {
    if (videos.isEmpty) return;
    context.read<PlayerService>().open(videos, index);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final videos = folder == null ? library.videos : library.byFolder(folder!);
    final canPop = Navigator.of(context).canPop();

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(canPop ? 8 : 20, 12, 16, 0),
              child: Row(
                children: [
                  if (canPop)
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                    ),
                  Expanded(
                    child: Text(
                      title ?? (folder ?? 'All videos'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
                    ),
                  ),
                  Text('${videos.length} videos',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.line),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 19, color: AppColors.muted),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        onChanged: library.setQuery,
                        style: const TextStyle(fontSize: 13),
                        decoration: const InputDecoration(
                          hintText: 'Video ka naam',
                          hintStyle: TextStyle(color: AppColors.muted, fontSize: 12.5),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 34,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _SortChip(
                    label: 'Newest',
                    active: library.sort == VideoSort.newest,
                    onTap: () => library.setSort(VideoSort.newest),
                  ),
                  _SortChip(
                    label: 'Oldest',
                    active: library.sort == VideoSort.oldest,
                    onTap: () => library.setSort(VideoSort.oldest),
                  ),
                  _SortChip(
                    label: 'Name',
                    active: library.sort == VideoSort.name,
                    onTap: () => library.setSort(VideoSort.name),
                  ),
                  _SortChip(
                    label: 'Longest',
                    active: library.sort == VideoSort.duration,
                    onTap: () => library.setSort(VideoSort.duration),
                  ),
                ],
              ),
            ),
            Expanded(
              child: videos.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'Koi video nahi mili.\nPhone me video ho to pull-down karke refresh karo.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.6),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(top: 8, bottom: 220),
                      itemCount: videos.length,
                      itemBuilder: (context, index) {
                        final video = videos[index];
                        return VideoTile(
                          video: video,
                          resume: player.resumePositionFor(video),
                          onTap: () => _open(context, videos, index),
                          onMore: () => showVideoMenu(context, video, videos),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.lime : Colors.transparent,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: active ? AppColors.lime : AppColors.line),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: active ? const Color(0xFF10160A) : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showVideoMenu(
  BuildContext context,
  VideoItem video,
  List<VideoItem> videos,
) async {
  final library = context.read<LibraryService>();
  final player = context.read<PlayerService>();
  final size = await library.sizeOf(video);
  if (!context.mounted) return;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.card,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          _info('Resolution', '${video.width} x ${video.height} (${video.resolution})'),
          _info('Duration', video.durationLabel),
          _info('Date', video.dateLabel),
          _info('Size', formatBytes(size)),
          _info('Folder', video.folder.isEmpty ? '—' : video.folder),
          if (player.resumePositionFor(video) > Duration.zero)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.restart_alt_rounded, size: 20, color: AppColors.lime),
              title: const Text('Resume point clear karo', style: TextStyle(fontSize: 13.5)),
              onTap: () async {
                await player.clearResume(video);
                if (sheetContext.mounted) Navigator.of(sheetContext).pop();
              },
            ),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 24),
            leading: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
            title: const Text('Delete video', style: TextStyle(fontSize: 13.5)),
            onTap: () async {
              Navigator.of(sheetContext).pop();
              final ok = await _confirmDelete(context, video.title);
              if (ok != true) return;
              final deleted = await library.delete([video]);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(deleted ? 'Video delete ho gayi' : 'Delete nahi hui')),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );
}

Widget _info(String label, String value) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(24, 3, 24, 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
        ),
        Expanded(child: Text(value, style: const TextStyle(fontSize: 12.5))),
      ],
    ),
  );
}

Future<bool?> _confirmDelete(BuildContext context, String title) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.cardSoft,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Text('Delete karein?', style: TextStyle(fontSize: 15)),
      content: Text('"$title" phone se delete ho jayegi. Ye wapas nahi aayegi.',
          style: const TextStyle(fontSize: 12.5, color: AppColors.muted, height: 1.5)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Delete', style: TextStyle(color: AppColors.danger)),
        ),
      ],
    ),
  );
}
