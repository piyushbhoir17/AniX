import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database/database.dart';
import '../../providers/app_providers.dart';
import '../../widgets/empty_state.dart';

/// Download manager screen showing active and queued downloads
class DownloadManagerScreen extends ConsumerWidget {
  const DownloadManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDownloads = ref.watch(activeDownloadsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Download Manager',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, ref, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'pause_all',
                child: ListTile(
                  leading: Icon(Icons.pause),
                  title: Text('Pause All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'resume_all',
                child: ListTile(
                  leading: Icon(Icons.play_arrow),
                  title: Text('Resume All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'cancel_all',
                child: ListTile(
                  leading: Icon(Icons.cancel),
                  title: Text('Cancel All'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: activeDownloads.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return EmptyStates.noActiveDownloads();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _DownloadTaskCard(
                task: task,
                onPause: () => _pauseDownload(ref, task.taskId),
                onResume: () => _resumeDownload(ref, task.taskId),
                onCancel: () => _showCancelDialog(context, ref, task),
              ).animate().fadeIn(delay: (index * 50).ms);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => EmptyStates.error(
          message: error.toString(),
          onRetry: () => ref.invalidate(activeDownloadsProvider),
        ),
      ),
    );
  }

  void _handleMenuAction(BuildContext context, WidgetRef ref, String action) async {
    final downloadManager = ref.read(downloadManagerProvider);
    final tasks = await ref.read(activeDownloadsProvider.future);

    switch (action) {
      case 'pause_all':
        for (final task in tasks.where((t) => t.status == 'downloading')) {
          await downloadManager.pauseDownload(task.taskId);
        }
        break;
      case 'resume_all':
        for (final task in tasks.where((t) => t.status == 'paused' || t.status == 'failed')) {
          await downloadManager.resumeDownload(task.taskId);
        }
        break;
      case 'cancel_all':
        _showCancelAllDialog(context, ref);
        break;
    }
    ref.invalidate(activeDownloadsProvider);
  }

  void _pauseDownload(WidgetRef ref, String taskId) async {
    await ref.read(downloadManagerProvider).pauseDownload(taskId);
    ref.invalidate(activeDownloadsProvider);
  }

  void _resumeDownload(WidgetRef ref, String taskId) async {
    await ref.read(downloadManagerProvider).resumeDownload(taskId);
    ref.invalidate(activeDownloadsProvider);
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref, DownloadTask task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Download'),
        content: Text('Cancel download for "${task.episodeTitle}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(downloadManagerProvider).cancelDownload(task.taskId);
              ref.invalidate(activeDownloadsProvider);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  void _showCancelAllDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel All Downloads'),
        content: const Text('Are you sure you want to cancel all downloads?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              final tasks = await ref.read(activeDownloadsProvider.future);
              for (final task in tasks) {
                await ref.read(downloadManagerProvider).cancelDownload(task.taskId);
              }
              ref.invalidate(activeDownloadsProvider);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Yes, Cancel All'),
          ),
        ],
      ),
    );
  }
}

class _DownloadTaskCard extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const _DownloadTaskCard({
    required this.task,
    required this.onPause,
    required this.onResume,
    required this.onCancel,
  });

  double get _progress {
    if (task.totalSegments == 0) return 0.0;
    return (task.downloadedSegments / task.totalSegments).clamp(0.0, 1.0);
  }

  String get _progressPercent => '${(_progress * 100).toStringAsFixed(1)}%';

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  bool get _canPause => task.status == 'downloading';
  bool get _canResume => task.status == 'paused' || task.status == 'failed';

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.animeTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Episode ${task.episodeNumber}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(context),
              ],
            ),

            const SizedBox(height: 12),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 8,
                backgroundColor: AppColors.draculaCurrentLine,
              ),
            ),

            const SizedBox(height: 8),

            // Progress info row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_progressPercent • ${_formatBytes(task.downloadedBytes)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  '${task.downloadedSegments}/${task.totalSegments} segments',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_canPause)
                  IconButton(
                    icon: const Icon(Icons.pause),
                    onPressed: onPause,
                    tooltip: 'Pause',
                  ),
                if (_canResume)
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: onResume,
                    tooltip: 'Resume',
                  ),
                IconButton(
                  icon: Icon(Icons.cancel, color: Theme.of(context).colorScheme.error),
                  onPressed: onCancel,
                  tooltip: 'Cancel',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (task.status) {
      case 'queued':
        color = AppColors.draculaOrange;
        label = 'Queued';
        icon = Icons.schedule;
        break;
      case 'downloading':
        color = AppColors.draculaCyan;
        label = 'Downloading';
        icon = Icons.downloading;
        break;
      case 'paused':
        color = AppColors.draculaYellow;
        label = 'Paused';
        icon = Icons.pause;
        break;
      case 'failed':
        color = AppColors.draculaRed;
        label = 'Failed';
        icon = Icons.error;
        break;
      default:
        color = AppColors.draculaComment;
        label = 'Unknown';
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
