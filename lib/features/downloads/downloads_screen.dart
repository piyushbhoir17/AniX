import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/app_providers.dart';
import '../../widgets/anime_grid.dart';
import '../../widgets/empty_state.dart';

/// Downloads screen showing anime with downloaded episodes
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedAnime = ref.watch(downloadedAnimeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          const SliverAppBar(
            floating: true,
            title: Text(
              'Downloads',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
          ),

          // Content
          downloadedAnime.when(
            data: (animeList) {
              if (animeList.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyStates.noDownloads(),
                );
              }

              return SliverAnimeGrid(
                animeList: animeList,
                onAnimeTap: (anime) => _openDownloadedAnime(context, ref, anime.animeId),
                onAnimeLongPress: (anime) => _showDeleteDialog(context, ref, anime),
              );
            },
            loading: () => const SliverAnimeGrid(
              animeList: [],
              isLoading: true,
            ),
            error: (error, stack) => SliverFillRemaining(
              child: EmptyStates.error(
                message: error.toString(),
                onRetry: () => ref.invalidate(downloadedAnimeProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openDownloadedAnime(BuildContext context, WidgetRef ref, String animeId) {
    // TODO: Navigate to downloaded episodes screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening downloaded anime: $animeId')),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, dynamic anime) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Downloads'),
        content: Text('Delete all downloaded episodes for "${anime.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              // TODO: Delete downloads
              ref.invalidate(downloadedAnimeProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Downloads deleted')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
