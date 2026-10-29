import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/player_screen.dart';
import '../services/player_service.dart';
import '../theme/app_theme.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerService>();
    final video = player.current;
    if (video == null) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: AppColors.cardSoft,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const PlayerScreen()),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                child: Row(
                  children: [
                    const Icon(Icons.movie_rounded, size: 18, color: AppColors.lime),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            video.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            player.isPlaying ? 'Playing' : 'Paused',
                            style: const TextStyle(fontSize: 10.5, color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: player.previous,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_previous_rounded, size: 22),
                    ),
                    Container(
                      height: 36,
                      width: 36,
                      decoration: const BoxDecoration(color: AppColors.lime, shape: BoxShape.circle),
                      child: IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: player.toggle,
                        icon: Icon(
                          player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: const Color(0xFF10160A),
                          size: 21,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: player.next,
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.skip_next_rounded, size: 22),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: LinearProgressIndicator(
                  value: player.duration.inMilliseconds <= 0
                      ? 0
                      : (player.position.inMilliseconds / player.duration.inMilliseconds)
                          .clamp(0.0, 1.0),
                  minHeight: 2.5,
                  backgroundColor: const Color(0x1FFFFFFF),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
