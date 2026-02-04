import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/logger.dart';
import '../../data/models/anime.dart';
import '../../data/models/anime_detail.dart';
import '../../data/models/episode.dart';
import '../../data/services/m3u8_parser.dart';
import '../../data/services/scraper_service.dart';
import '../../providers/app_providers.dart';
import '../../widgets/quality_selector_dialog.dart';
import '../player/video_player_screen.dart';

class AnimeDetailsScreen extends ConsumerStatefulWidget {
  final Anime anime;

  const AnimeDetailsScreen({super.key, required this.anime});

  @override
  ConsumerState<AnimeDetailsScreen> createState() => _AnimeDetailsScreenState();
}

class _AnimeDetailsScreenState extends ConsumerState<AnimeDetailsScreen> {
  bool _isDescriptionExpanded = false;
  String? _selectedSeason;
  String _episodeSearchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  String? _loadingEpisodeId;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(animeDetailProvider(widget.anime));
    final bookmarkedAnime = ref.watch(animeDetailProvider(widget.anime)).valueOrNull?.anime;
    final isBookmarked = bookmarkedAnime?.isBookmarked ?? widget.anime.isBookmarked;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            icon: Icon(
              isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              color: isBookmarked ? AppColors.draculaPink : null,
            ),
            onPressed: () => _toggleBookmark(bookmarkedAnime ?? widget.anime),
          ),
        ],
      ),
      body: detail.when(
        data: (animeDetail) => _buildContent(context, animeDetail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Future<void> _toggleBookmark(Anime anime) async {
    try {
      final repository = ref.read(animeRepositoryProvider);
      
      // First ensure the anime exists in the database
      var existingAnime = await repository.getByAnimeId(anime.animeId);
      
      if (existingAnime == null) {
        // Anime not in DB yet, save it first
        await repository.save(anime);
        existingAnime = anime;
      }
      
      // Now toggle bookmark using the repository method
      final isNowBookmarked = await repository.toggleBookmark(anime.animeId);
      
      ref.invalidate(animeDetailProvider(widget.anime));
      ref.invalidate(bookmarkedAnimeProvider);
      
      if (mounted) {
        context.showSnackBar(
          isNowBookmarked ? 'Added to bookmarks' : 'Removed from bookmarks',
        );
      }
    } catch (e) {
      AppLogger.e('Failed to toggle bookmark', e);
      if (mounted) {
        context.showSnackBar('Failed to update bookmark');
      }
    }
  }

  Future<void> _playEpisode(Episode episode, Anime anime) async {
    if (episode.sourceUrl == null) {
      context.showSnackBar('Episode URL not available');
      return;
    }

    final episodeId = '${episode.animeId}-${episode.episodeNumber}';
    
    setState(() {
      _loadingEpisodeId = episodeId;
    });

    // Create a ValueNotifier for status updates
    final statusNotifier = ValueNotifier<String>('Initializing...');
    
    try {
      // Show loading dialog with status updates
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => _LoadingDialog(
            episodeNumber: episode.episodeNumber,
            statusNotifier: statusNotifier,
          ),
        );
      }

      // Step 1: Sniff the M3U8 URL from the episode page
      statusNotifier.value = 'Fetching episode page...';
      await Future.delayed(const Duration(milliseconds: 300));
      
      statusNotifier.value = 'Finding video source...';
      final scraperResult = await ScraperService.instance.sniffM3u8Url(episode.sourceUrl!);
      
      // Step 2: Fetch and parse master playlist
      statusNotifier.value = 'Loading M3U8 playlist...';
      final masterPlaylist = await ref.read(scraperServiceProvider).fetchMasterPlaylist(scraperResult);
      
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
      
      // Step 3: Show quality selector if multiple options available
      String videoUrl = scraperResult.m3u8Url;
      
      if (mounted && (masterPlaylist.videoStreams.length > 1 || masterPlaylist.audioTracks.isNotEmpty)) {
        final settings = ref.read(settingsProvider);
        final selection = await QualitySelectorDialog.show(
          context,
          playlist: masterPlaylist,
          defaultQuality: settings?.defaultQuality,
          defaultLanguage: settings?.defaultLanguage,
        );
        
        if (selection == null) {
          // User cancelled
          setState(() => _loadingEpisodeId = null);
          return;
        }
        
        // Save as default if requested
        if (selection.saveAsDefault) {
          ref.read(settingsProvider.notifier).setDefaultQuality(selection.videoStream.qualityLabel);
          if (selection.audioTrack != null) {
            ref.read(settingsProvider.notifier).setDefaultLanguage(selection.audioTrack!.displayName);
          }
        }
        
        // Build custom master playlist with only selected video + audio
        if (selection.audioTrack != null) {
          // Has separate audio track - build custom master playlist
          final customPlaylist = M3U8Parser.buildCustomMasterPlaylist(
            videoStream: selection.videoStream,
            audioTrack: selection.audioTrack,
            baseDomain: masterPlaylist.baseDomain ?? '',
          );
          
          // Write to temp file for media_kit to read
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/custom_master_${DateTime.now().millisecondsSinceEpoch}.m3u8');
          await tempFile.writeAsString(customPlaylist);
          videoUrl = tempFile.path;
          
          AppLogger.i('Created custom master playlist: $videoUrl');
          AppLogger.d('Playlist content:\n$customPlaylist');
        } else {
          // No separate audio - use video stream directly (audio is muxed)
          videoUrl = selection.videoStream.url;
          AppLogger.i('Using direct video stream (muxed audio): $videoUrl');
        }
      } else if (masterPlaylist.videoStreams.isNotEmpty) {
        // Single quality - check if it has separate audio tracks
        if (masterPlaylist.audioTracks.isNotEmpty) {
          // Build custom playlist with first video + first audio
          final customPlaylist = M3U8Parser.buildCustomMasterPlaylist(
            videoStream: masterPlaylist.videoStreams.first,
            audioTrack: masterPlaylist.audioTracks.first,
            baseDomain: masterPlaylist.baseDomain ?? '',
          );
          
          final tempDir = await getTemporaryDirectory();
          final tempFile = File('${tempDir.path}/custom_master_${DateTime.now().millisecondsSinceEpoch}.m3u8');
          await tempFile.writeAsString(customPlaylist);
          videoUrl = tempFile.path;
          
          AppLogger.i('Single quality with audio, created custom playlist: $videoUrl');
        } else {
          // Single muxed stream, use directly
          videoUrl = masterPlaylist.videoStreams.first.url;
          AppLogger.i('Single muxed stream: $videoUrl');
        }
      }

      
      }
    } catch (e) {
      AppLogger.e('Failed to load episode', e);
      
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        context.showSnackBar('Failed to load video: ${e.toString()}');
      }
    } finally {
      statusNotifier.dispose();
      if (mounted) {
        setState(() {
          _loadingEpisodeId = null;
        });
      }
    }
  }

  Widget _buildContent(BuildContext context, AnimeDetail detail) {
    final anime = detail.anime;
    final seasons = detail.episodesBySeason;
    final seasonKeys = seasons.key// Navigate to video player
if (mounted) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (context) => VideoPlayerScreen(
        animeId: anime.animeId,
        animeTitle: anime.title,
        episodeNumber: episode.episodeNumber,
        episodeTitle: episode.title,
        videoUrl: videoUrl,
        masterPlaylist: masterPlaylist,
        startPosition: episode.watchedPosition > 0 ? episode.watchedPosition : null,
      ),
    ),
  );
}
    s.toList()..sort(_compareSeasons);
    final hasSeasons = seasonKeys.isNotEmpty;
    
    // Initialize selected season if not set
    if (_selectedSeason == null && hasSeasons) {
      _selectedSeason = seasonKeys.first;
    }
    
    final selectedSeason = hasSeasons
        ? seasonKeys.firstWhere(
            (season) => season == _selectedSeason,
            orElse: () => seasonKeys.first,
          )
        : null;
    
    final allEpisodes = hasSeasons ? seasons[selectedSeason]! : const <Episode>[];
    
    // Filter episodes by search query
    final episodes = _episodeSearchQuery.isEmpty
        ? allEpisodes
        : allEpisodes.where((ep) {
            final query = _episodeSearchQuery.toLowerCase();
            final epNumStr = ep.episodeNumber.toString();
            final title = ep.title.toLowerCase();
            return epNumStr.contains(query) || title.contains(query);
          }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildHeader(anime),
        const SizedBox(height: 16),
        _buildDescription(context, anime.description),
        const SizedBox(height: 16),
        if (hasSeasons) ...[
          _buildSeasonDropdown(context, seasonKeys, selectedSeason!),
          const SizedBox(height: 16),
        ],
        _buildEpisodeSection(context, episodes, allEpisodes.length, anime),
      ],
    );
  }

  int _compareSeasons(String a, String b) {
    // Extract season numbers for proper sorting
    final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    return numA.compareTo(numB);
  }

  Widget _buildSeasonDropdown(BuildContext context, List<String> seasons, String selected) {
    return Row(
      children: [
        Text('Season:', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.draculaCurrentLine.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selected,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down),
                items: seasons.map((season) {
                  return DropdownMenuItem<String>(
                    value: season,
                    child: Text(season),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedSeason = value;
                      _episodeSearchQuery = '';
                      _searchController.clear();
                    });
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEpisodeSection(BuildContext context, List<Episode> episodes, int totalEpisodes, Anime anime) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Episodes (${episodes.length}${_episodeSearchQuery.isNotEmpty ? '/$totalEpisodes' : ''})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Episode search field
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search episodes (e.g., "25" or "title")',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _episodeSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      setState(() {
                        _episodeSearchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            filled: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
          onChanged: (value) {
            setState(() {
              _episodeSearchQuery = value;
            });
          },
        ),
        const SizedBox(height: 12),
        if (episodes.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              _episodeSearchQuery.isNotEmpty
                  ? 'No episodes match "$_episodeSearchQuery"'
                  : 'No episodes found',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          ...episodes.map((episode) => _EpisodeTile(
            episode: episode,
            isLoading: _loadingEpisodeId == '${episode.animeId}-${episode.episodeNumber}',
            onTap: () => _playEpisode(episode, anime),
          )),
      ],
    );
  }

  Widget _buildHeader(Anime anime) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 120,
            height: 170,
            color: AppColors.draculaCurrentLine,
            child: anime.coverUrl != null
                ? Image.network(
                    anime.coverUrl!,
                    fit: BoxFit.cover,
                    width: 120,
                    height: 170,
                    errorBuilder: (context, error, stackTrace) => const Center(
                      child: Icon(Icons.broken_image_outlined, size: 48, color: AppColors.draculaComment),
                    ),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                    },
                  )
                : const Center(
                    child: Icon(Icons.movie_outlined, size: 48, color: AppColors.draculaComment),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(anime.title, style: Theme.of(context).textTheme.titleLarge),
              if (anime.releaseYear != null) ...[
                const SizedBox(height: 8),
                Text('Year: ${anime.releaseYear}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (anime.status != null) ...[
                const SizedBox(height: 4),
                Text('Status: ${anime.status}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (anime.type != null) ...[
                const SizedBox(height: 4),
                Text('Type: ${anime.type}', style: Theme.of(context).textTheme.bodySmall),
              ],
              if (anime.genres.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: anime.genres.take(5).map((genre) => Chip(
                    label: Text(genre, style: const TextStyle(fontSize: 10)),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDescription(BuildContext context, String? description) {
    if (description == null || description.trim().isEmpty) {
      return Text('Description', style: Theme.of(context).textTheme.labelLarge);
    }

    final textTheme = Theme.of(context).textTheme;
    final maxLines = _isDescriptionExpanded ? null : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Description', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Text(description, style: textTheme.bodyMedium, maxLines: maxLines, overflow: _isDescriptionExpanded ? null : TextOverflow.ellipsis),
        const SizedBox(height: 4),
        TextButton(
          onPressed: () {
            setState(() {
              _isDescriptionExpanded = !_isDescriptionExpanded;
            });
          },
          child: Text(_isDescriptionExpanded ? 'View Less' : 'View More'),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.draculaOrange),
            const SizedBox(height: 12),
            Text('Failed to load anime details', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => ref.invalidate(animeDetailProvider(widget.anime)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EpisodeTile extends StatelessWidget {
  final Episode episode;
  final bool isLoading;
  final VoidCallback onTap;

  const _EpisodeTile({
    required this.episode,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasProgress = episode.watchProgress > 0 && episode.watchProgress < 1;
    
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: episode.isWatched 
                  ? AppColors.draculaGreen.withValues(alpha: 0.2)
                  : AppColors.draculaPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                '${episode.episodeNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: episode.isWatched ? AppColors.draculaGreen : AppColors.draculaPurple,
                ),
              ),
            ),
          ),
          if (episode.isWatched)
            const Positioned(
              right: 0,
              bottom: 0,
              child: Icon(Icons.check_circle, size: 16, color: AppColors.draculaGreen),
            ),
        ],
      ),
      title: Text(
        episode.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (episode.duration != null)
            Text('Duration: ${episode.duration!.formatDuration}'),
          if (hasProgress)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LinearProgressIndicator(
                value: episode.watchProgress,
                backgroundColor: AppColors.draculaComment.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.draculaPink),
              ),
            ),
        ],
      ),
      trailing: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.play_circle_outline, color: AppColors.draculaPink),
      onTap: isLoading ? null : onTap,
    );
  }
}

/// Loading dialog with spinning wheel and status text
class _LoadingDialog extends StatelessWidget {
  final int episodeNumber;
  final ValueNotifier<String> statusNotifier;

  const _LoadingDialog({
    required this.episodeNumber,
    required this.statusNotifier,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Spinning wheel
            const SizedBox(
              width: 60,
              height: 60,
              child: CircularProgressIndicator(
                strokeWidth: 4,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.draculaPink),
              ),
            ),
            const SizedBox(height: 24),
            
            // Episode title
            Text(
              'Loading Episode $episodeNumber',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            // Dynamic status text
            ValueListenableBuilder<String>(
              valueListenable: statusNotifier,
              builder: (context, status, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getStatusIcon(status),
                      size: 16,
                      color: AppColors.draculaComment,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      status,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.draculaComment,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    if (status.contains('Fetching')) return Icons.download_outlined;
    if (status.contains('Finding')) return Icons.search;
    if (status.contains('M3U8')) return Icons.playlist_play;
    if (status.contains('Initializing')) return Icons.hourglass_empty;
    return Icons.sync;
  }
}
