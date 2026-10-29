import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import 'player_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 220),
          children: [
            Text('Settings', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 22),
            const _GroupLabel('Library'),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Default sorting',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _chip(context, 'Newest', VideoSort.newest, library),
                      _chip(context, 'Oldest', VideoSort.oldest, library),
                      _chip(context, 'Name', VideoSort.name, library),
                      _chip(context, 'Longest', VideoSort.duration, library),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _Tile(
              icon: Icons.refresh_rounded,
              title: 'Rescan videos',
              subtitle: '${library.videoCount} videos mile',
              onTap: () => library.load(force: true),
            ),
            const SizedBox(height: 18),
            _Tile(
              icon: Icons.link_rounded,
              title: 'Open video link',
              subtitle: 'Direct MP4 / stream URL chalao',
              onTap: () => _openStream(context),
            ),
            _Tile(
              icon: Icons.folder_shared_rounded,
              title: 'All files access',
              subtitle: 'Storage se seedha videos padhne ke liye',
              onTap: () async {
                await library.requestPermission();
                await library.load(force: true);
              },
            ),
            const SizedBox(height: 18),
            const _GroupLabel('About'),
            _Tile(
              icon: Icons.lock_outline_rounded,
              title: 'Permissions',
              subtitle: 'Sirf video access',
              onTap: () => _dialog(
                context,
                'Permissions',
                'VidHive "All files access" maangta hai taaki gallery index pe depend na kare — jo videos gallery me nahi dikhti wo bhi mil jayein. Camera, microphone, location, contacts — kuch nahi.\n\nDelete karte waqt Android khud confirm karta hai.',
              ),
            ),
            _Tile(
              icon: Icons.info_outline_rounded,
              title: 'About VidHive',
              subtitle: 'Version 1.0.0',
              onTap: () => _dialog(
                context,
                'VidHive',
                'Version 1.0.0\n\nEk clean, minimal all-in-one video player. libmpv (media_kit) engine — MKV, MP4, HEVC, AV1, VP9, AC3/DTS audio sab chalta hai, hardware decoding ke saath, isliye 4K bhi smooth rehta hai.\n\nSab kuch offline — koi account nahi, koi internet nahi.',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openStream(BuildContext context) async {
    final player = context.read<PlayerService>();
    final controller = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('Video link', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Direct video URL paste karo (mp4, m3u8, mkv...).',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.url,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'https://...',
                hintStyle: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                filled: true,
                fillColor: AppColors.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: AppColors.muted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Play', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.isEmpty) return;
    await player.openUrl(url);
    if (!context.mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlayerScreen()));
  }

  Widget _chip(BuildContext context, String label, VideoSort sort, LibraryService library) {
    final active = library.sort == sort;
    return GestureDetector(
      onTap: () => library.setSort(sort),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.lime : AppColors.cardSoft,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? AppColors.lime : AppColors.line),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: active ? const Color(0xFF10160A) : AppColors.text,
          ),
        ),
      ),
    );
  }

  void _dialog(BuildContext context, String title, String body) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: Text(body, style: const TextStyle(fontSize: 12.5, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close', style: TextStyle(color: AppColors.lime)),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 18,
        onTap: onTap,
        child: Row(
          children: [
            Container(
              height: 38,
              width: 38,
              decoration: BoxDecoration(
                color: AppColors.cardSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: AppColors.lime),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
