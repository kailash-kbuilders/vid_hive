import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import '../widgets/video_tile.dart';
import 'library_screen.dart';
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LibraryService>().load();
    });
  }

  Future<void> _open(List<VideoItem> videos, int index) async {
    if (videos.isEmpty) return;
    final player = context.read<PlayerService>();
    unawaitedOpen(player, videos, index);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  void unawaitedOpen(PlayerService player, List<VideoItem> videos, int index) {
    player.open(videos, index);
  }

  void _openLibrary(BuildContext context, {String? folder, String? title}) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LibraryScreen(folder: folder, title: title),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final player = context.watch<PlayerService>();
    final all = library.videos;
    final continueWatching = all
        .where((video) => player.resumePositionFor(video) > const Duration(seconds: 3))
        .take(6)
        .toList();
    final recent = all.take(6).toList();
    final folders = library.folders.take(6).toList();

    return GradientBg(
      child: RefreshIndicator(
        color: AppColors.lime,
        backgroundColor: AppColors.card,
        onRefresh: () => library.load(force: true),
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 230),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Row(
                children: [
                  Container(
                    height: 44,
                    width: 44,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Image.asset('assets/images/logo.png'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Good to see you,',
                            style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                        const SizedBox(height: 2),
                        Text(
                          library.videoCount == 0
                              ? 'No videos yet'
                              : '${library.videoCount} videos ready',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (library.videoCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF3B4D1F), Color(0xFF161D0E)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sd_storage_rounded, size: 22, color: AppColors.lime),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${library.videoCount} videos',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${formatBytes(library.totalBytes)} · ${library.folders.length} folders',
                              style: const TextStyle(fontSize: 11, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => library.load(force: true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.lime,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Rescan',
                            style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF10160A)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (library.isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppColors.lime)),
              ),
            if (library.permissionDenied)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('All files access chahiye',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      const Text(
                        'Gallery me saari videos index nahi hoti — isliye VidHive seedha storage padhta hai. Settings me "All files access" on karna padega. Camera, location, contacts — kuch nahi maangta.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () async {
                          await library.requestPermission();
                          await library.load(force: true);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.lime,
                          foregroundColor: const Color(0xFF10160A),
                        ),
                        child: const Text('Access do'),
                      ),
                    ],
                  ),
                ),
              ),
            if (library.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: AppCard(
                  child: Text(library.error!,
                      style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                ),
              ),
            if (!library.isLoading && !library.permissionDenied && all.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 30, 20, 0),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Koi video nahi mili',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                      SizedBox(height: 6),
                      Text(
                        'Phone me video download karke app dobara kholo — saari videos folder ke saath yahan aa jayengi.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            if (continueWatching.isNotEmpty) ...[
              _header(context, 'Continue watching'),
              SizedBox(
                height: 172,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: continueWatching.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final video = continueWatching[index];
                    return VideoCard(
                      video: video,
                      resume: player.resumePositionFor(video),
                      onTap: () => _open(continueWatching, index),
                    );
                  },
                ),
              ),
            ],
            if (folders.isNotEmpty) ...[
              _header(context, 'Folders', action: 'All', onAction: () => _openLibrary(context)),
              SizedBox(
                height: 96,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: folders.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return GestureDetector(
                      onTap: () => _openLibrary(context, folder: folder, title: folder),
                      child: Container(
                        width: 190,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF3B4D1F), Color(0xFF161D0E)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.folder_rounded, size: 22, color: AppColors.lime),
                            Text(
                              folder,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            Text(
                                '${library.countInFolder(folder)} · ${formatBytes(library.bytesInFolder(folder))}',
                                style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            if (recent.isNotEmpty) ...[
              _header(
                context,
                'Recent videos',
                action: 'See all',
                onAction: () => _openLibrary(context, title: 'All videos'),
              ),
              ...recent.asMap().entries.map((entry) {
                final video = entry.value;
                return VideoTile(
                  video: video,
                  resume: player.resumePositionFor(video),
                  onTap: () => _open(recent, entry.key),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String title, {String? action, VoidCallback? onAction}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
      child: Row(
        children: [
          Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
          if (action != null && onAction != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Row(
                children: [
                  Text(action,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 2),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
