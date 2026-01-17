import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../core/theme/app_colors.dart';

/// Empty state widget for when there's no content
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 80,
              color: AppColors.draculaComment,
            )
                .animate()
                .fadeIn(duration: 400.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 400.ms),
            const SizedBox(height: 24),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.draculaComment,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            ],
          ],
        ),
      ),
    );
  }
}

/// Predefined empty states
class EmptyStates {
  EmptyStates._();

  static EmptyState noBookmarks({VoidCallback? onAction}) => EmptyState(
        icon: Icons.bookmark_border,
        title: 'No Bookmarks Yet',
        subtitle: 'Your bookmarked anime will appear here',
        actionLabel: onAction != null ? 'Browse Anime' : null,
        onAction: onAction,
      );

  static EmptyState noDownloads({VoidCallback? onAction}) => EmptyState(
        icon: Icons.download_outlined,
        title: 'No Downloads',
        subtitle: 'Downloaded episodes will appear here for offline viewing',
        actionLabel: onAction != null ? 'Browse Anime' : null,
        onAction: onAction,
      );

  static EmptyState noActiveDownloads() => const EmptyState(
        icon: Icons.downloading_outlined,
        title: 'No Active Downloads',
        subtitle: 'Your download queue is empty',
      );

  static EmptyState noSearchResults(String query) => EmptyState(
        icon: Icons.search_off,
        title: 'No Results Found',
        subtitle: 'No anime found for "$query"',
      );

  static EmptyState error({String? message, VoidCallback? onRetry}) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: message ?? 'An error occurred',
        actionLabel: onRetry != null ? 'Retry' : null,
        onAction: onRetry,
      );
}
