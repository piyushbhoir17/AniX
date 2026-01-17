import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';
import '../data/database/database.dart';
import 'anime_card.dart';

/// Grid widget for displaying anime cards
class AnimeGrid extends StatelessWidget {
  final List<Anime> animeList;
  final void Function(Anime anime)? onAnimeTap;
  final void Function(Anime anime)? onAnimeLongPress;
  final bool showProgress;
  final Map<String, double>? progressMap;
  final EdgeInsets? padding;
  final bool isLoading;
  final int loadingItemCount;

  const AnimeGrid({
    super.key,
    required this.animeList,
    this.onAnimeTap,
    this.onAnimeLongPress,
    this.showProgress = false,
    this.progressMap,
    this.padding,
    this.isLoading = false,
    this.loadingItemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingGrid();
    }

    if (animeList.isEmpty) {
      return const SizedBox.shrink();
    }

    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(AppConstants.defaultPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: animeList.length,
      itemBuilder: (context, index) {
        final anime = animeList[index];
        return AnimeCard(
          anime: anime,
          onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
          onLongPress: onAnimeLongPress != null ? () => onAnimeLongPress!(anime) : null,
          showProgress: showProgress,
          progress: progressMap?[anime.animeId],
        );
      },
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: padding ?? const EdgeInsets.all(AppConstants.defaultPadding),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.55,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: loadingItemCount,
      itemBuilder: (context, index) => const AnimeCardShimmer(),
    );
  }
}

/// Sliver version of anime grid for use in CustomScrollView
class SliverAnimeGrid extends StatelessWidget {
  final List<Anime> animeList;
  final void Function(Anime anime)? onAnimeTap;
  final void Function(Anime anime)? onAnimeLongPress;
  final bool showProgress;
  final Map<String, double>? progressMap;
  final bool isLoading;
  final int loadingItemCount;

  const SliverAnimeGrid({
    super.key,
    required this.animeList,
    this.onAnimeTap,
    this.onAnimeLongPress,
    this.showProgress = false,
    this.progressMap,
    this.isLoading = false,
    this.loadingItemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = isLoading ? loadingItemCount : animeList.length;

    return SliverPadding(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.55,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (isLoading) {
              return const AnimeCardShimmer();
            }

            final anime = animeList[index];
            return AnimeCard(
              anime: anime,
              onTap: onAnimeTap != null ? () => onAnimeTap!(anime) : null,
              onLongPress: onAnimeLongPress != null ? () => onAnimeLongPress!(anime) : null,
              showProgress: showProgress,
              progress: progressMap?[anime.animeId],
            );
          },
          childCount: itemCount,
        ),
      ),
    );
  }
}
