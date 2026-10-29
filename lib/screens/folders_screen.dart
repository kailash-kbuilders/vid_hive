import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/library_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_bg.dart';
import 'library_screen.dart';

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryService>();
    final folders = library.folders;

    return GradientBg(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Folders',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  Text('${library.videoCount} videos',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                ],
              ),
            ),
            const SizedBox(height: 6),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'Phone ki video folders — file manager ki tarah. Kisi folder ko khol ke videos dekh sakte ho ya delete kar sakte ho.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: folders.isEmpty
                  ? const Center(
                      child: Text('Koi folder nahi mila',
                          style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 220),
                      itemCount: folders.length,
                      itemBuilder: (context, index) {
                        final folder = folders[index];
                        final count = library.countInFolder(folder);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: AppCard(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            radius: 18,
                            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                              builder: (_) => LibraryScreen(folder: folder, title: folder),
                            )),
                            child: Row(
                              children: [
                                Container(
                                  height: 44,
                                  width: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.cardSoft,
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                  child: const Icon(Icons.folder_rounded,
                                      size: 20, color: AppColors.lime),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(folder,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontSize: 13.5, fontWeight: FontWeight.w500)),
                                      const SizedBox(height: 2),
                                      Text(
                                          '$count videos · ${formatBytes(library.bytesInFolder(folder))}',
                                          style: const TextStyle(
                                              fontSize: 11, color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _confirmDeleteFolder(
                                      context, library, folder, count),
                                  icon: const Icon(Icons.delete_outline_rounded,
                                      size: 18, color: AppColors.muted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFolder(
    BuildContext context,
    LibraryService library,
    String folder,
    int count,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.cardSoft,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('"$folder" ki videos delete karein?',
            style: const TextStyle(fontSize: 15)),
        content: Text('$count videos phone se delete ho jayengi.',
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
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
    if (confirmed != true) return;
    final deleted = await library.delete(library.byFolder(folder));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(deleted ? 'Videos delete ho gayi' : 'Delete nahi hui')),
    );
  }
}
