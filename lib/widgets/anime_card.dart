import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../data/database/database.dart';

/// Anime card widget for grid display
class AnimeCard extends StatelessWidget {
  final Anime anime;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showProgress;
  final double? progress;

  const AnimeCard({
    super.key,
    required this.anime,
    this.onTap,
    this.onLongPress,
    this.showProgress = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: AppTheme.cardRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: AppTheme.cardRadius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    _buildCoverImage(),
                    
                    // Gradient overlay at bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 60,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Status badge
                    if (anime.status != null)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(anime.status!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            anime.status!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                    // Progress indicator
                    if (showProgress && progress != null && progress! > 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: LinearProgressIndicator(
                          value: progress!,
                          backgroundColor: Colors.black26,
                          valueColor: const AlwaysStoppedAnimation(
                            AppColors.draculaPurple,
                          ),
                          minHeight: 3,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Title
          Text(
            anime.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),

          // Episode info
          if (anime.totalEpisodes != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${anime.totalEpisodes} Episodes',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).scale(
          begin: const Offset(0.95, 0.95),
          end: const Offset(1, 1),
          duration: 300.ms,
          curve: Curves.easeOut,
        );
  }

  Widget _buildCoverImage() {
    if (anime.coverUrl == null || anime.coverUrl!.isEmpty) {
      return Container(
        color: AppColors.draculaCurrentLine,
        child: const Center(
          child: Icon(
            Icons.movie_outlined,
            size: 48,
            color: AppColors.draculaComment,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: anime.coverUrl!,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: AppColors.draculaCurrentLine,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: AppColors.draculaCurrentLine,
        child: const Center(
          child: Icon(
            Icons.broken_image_outlined,
            size: 48,
            color: AppColors.draculaComment,
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ongoing':
        return AppColors.draculaGreen;
      case 'completed':
        return AppColors.draculaPurple;
      case 'upcoming':
        return AppColors.draculaOrange;
      default:
        return AppColors.draculaComment;
    }
  }
}

/// Shimmer loading placeholder for anime card
class AnimeCardShimmer extends StatelessWidget {
  const AnimeCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.draculaCurrentLine : Colors.grey.shade300;
    final highlightColor = isDark ? AppColors.draculaComment : Colors.grey.shade100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: AppTheme.cardRadius,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 12,
          width: 80,
          decoration: BoxDecoration(
            color: baseColor,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ],
    ).animate(onPlay: (controller) => controller.repeat()).shimmer(
          duration: 1500.ms,
          color: highlightColor.withOpacity(0.3),
        );
  }
}
