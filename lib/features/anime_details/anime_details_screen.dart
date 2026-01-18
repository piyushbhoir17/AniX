import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/extensions.dart';
import '../../data/models/anime.dart';
import '../../data/models/anime_detail.dart';
import '../../data/models/episode.dart';
import '../../providers/app_providers.dart';

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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(animeDetailProvider(widget.anime));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.anime.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: detail.when(
        data: (animeDetail) => _buildContent(context, animeDetail),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildError(context, error.toString()),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AnimeDetail detail) {
    final anime = detail.anime;
    final seasons = detail.episodesBySeason;
    final seasonKeys = seasons.keys.toList()..sort(_compareSeasons);
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
        _buildEpisodeSection(context, episodes, allEpisodes.length),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.draculaComment),
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildEpisodeSection(BuildContext context, List<Episode> episodes, int totalEpisodes) {
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
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _episodeSearchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      setState(() {
                        _episodeSearchQuery = '';
                        _searchController.clear();
                      });
                    },
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
          ...episodes.map((episode) => _EpisodeTile(episode: episode)),
      ],
    );
  }

  Widget _buildHeader(Anime anime) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
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
              if (anime.genres != null && anime.genres!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: anime.genres!.take(5).map((genre) => Chip(
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

  const _EpisodeTile({required this.episode});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text('Episode ${episode.episodeNumber}: ${episode.title}'),
      subtitle: episode.duration != null
          ? Text('Duration: ${episode.duration!.formatDuration}')
          : null,
      trailing: const Icon(Icons.play_circle_outline),
      onTap: () {
        context.showSnackBar('Play ${episode.title}');
      },
    );
  }
}
