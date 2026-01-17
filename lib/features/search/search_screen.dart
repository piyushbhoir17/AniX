import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/app_providers.dart';
import '../../widgets/anime_grid.dart';
import '../../widgets/empty_state.dart';

/// Search screen for finding anime
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final searchResults = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          decoration: InputDecoration(
            hintText: 'Search anime...',
            border: InputBorder.none,
            filled: false,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            suffixIcon: query.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(searchQueryProvider.notifier).state = '';
                    },
                  )
                : null,
          ),
          onChanged: (value) {
            ref.read(searchQueryProvider.notifier).state = value;
          },
          textInputAction: TextInputAction.search,
        ),
      ),
      body: _buildBody(query, searchResults),
    );
  }

  Widget _buildBody(String query, AsyncValue searchResults) {
    if (query.isEmpty) {
      return _buildRecentSearches();
    }

    return searchResults.when(
      data: (results) {
        if (results.isEmpty) {
          return EmptyStates.noSearchResults(query);
        }

        return AnimeGrid(
          animeList: results,
          onAnimeTap: (anime) => _openAnimeDetails(anime.animeId),
        );
      },
      loading: () => const AnimeGrid(
        animeList: [],
        isLoading: true,
      ),
      error: (error, stack) => EmptyStates.error(
        message: error.toString(),
        onRetry: () => ref.invalidate(searchResultsProvider),
      ),
    );
  }

  Widget _buildRecentSearches() {
    // TODO: Implement recent searches storage
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: AppColors.draculaComment.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for your favorite anime',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.draculaComment,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a title to start searching',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  void _openAnimeDetails(String animeId) {
    // TODO: Navigate to anime details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening anime: $animeId')),
    );
  }
}
