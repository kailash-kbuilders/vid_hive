import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../services/library_service.dart';
import '../theme/app_theme.dart';

/// Thumbnail with a play badge; shows how much of the video is already watched.
class VideoThumb extends StatelessWidget {
  const VideoThumb({
    super.key,
    required this.video,
    required this.width,
    required this.height,
    this.radius = 16,
    this.resume,
  });

  final VideoItem video;
  final double width;
  final double height;
  final double radius;
  final Duration? resume;

  @override
  Widget build(BuildContext context) {
    final library = context.read<LibraryService>();
    final progress = (resume != null && video.duration.inSeconds > 0)
        ? (resume!.inMilliseconds / video.duration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: library.thumbnail(video, size: (width * 2).round()),
              builder: (context, snapshot) {
                final bytes = snapshot.data;
                if (bytes == null) {
                  return Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF33441C), Color(0xFF141B0D)],
                      ),
                    ),
                    child: Icon(Icons.movie_creation_outlined,
                        size: height * 0.35, color: AppColors.lime.withOpacity(0.7)),
                  );
                }
                return Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
              },
            ),
            Positioned(
              right: 6,
              bottom: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xAA000000),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  video.durationLabel,
                  style: const TextStyle(fontSize: 10, color: Colors.white),
                ),
              ),
            ),
            if (progress > 0)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: const Color(0x33000000),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class VideoTile extends StatelessWidget {
  const VideoTile({
    super.key,
    required this.video,
    required this.onTap,
    this.onMore,
    this.resume,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final VoidCallback? onMore;
  final Duration? resume;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              VideoThumb(video: video, width: 104, height: 62, radius: 12, resume: resume),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${video.resolution} · ${video.dateLabel} · ${video.folder}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (onMore != null)
                IconButton(
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.onTap,
    this.resume,
    this.width = 208,
  });

  final VideoItem video;
  final VoidCallback onTap;
  final Duration? resume;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoThumb(video: video, width: width, height: width * 0.56, radius: 18, resume: resume),
            const SizedBox(height: 8),
            Text(
              video.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              '${video.resolution} · ${video.durationLabel}',
              style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}
