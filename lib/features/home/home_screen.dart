import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/app_providers.dart';
import '../../widgets/anime_grid.dart';
import '../../widgets/empty_state.dart';
import '../search/search_screen.dart';

/// Home screen showing bookmarked anime library
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarkedAnime = ref.watch(bookmarkedAnimeProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            floating: true,
            title: const Text(
              'AniX',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 24,
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.search),
                onPressed: () => _openSearch(context),
              ),
            ],
          ),

          // Content
          bookmarkedAnime.when(
            data: (animeList) {
              if (animeList.isEmpty) {
                return SliverFillRemaining(
                  child: EmptyStates.noBookmarks(
                    onAction: () => _openSearch(context),
                  ),
                );
              }

              return SliverAnimeGrid(
                animeList: animeList,
                onAnimeTap: (anime) => _openAnimeDetails(context, anime.animeId),
                showProgress: true,
                progressMap: _buildProgressMap(animeList),
              );
            },
            loading: () => const SliverAnimeGrid(
              animeList: [],
              isLoading: true,
            ),
            error: (error, stack) => SliverFillRemaining(
              child: EmptyStates.error(
                message: error.toString(),
                onRetry: () => ref.invalidate(bookmarkedAnimeProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, double> _buildProgressMap(List animeList) {
    final map = <String, double>{};
    for (final anime in animeList) {
      if (anime.totalEpisodes != null && anime.totalEpisodes! > 0) {
        map[anime.animeId] = anime.lastWatchedEpisode / anime.totalEpisodes!;
      }
    }
    return map;
  }

  void _openSearch(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SearchScreen()),
    );
  }

  void _openAnimeDetails(BuildContext context, String animeId) {
    // TODO: Navigate to anime details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening anime: $animeId')),
    );
  }
}
