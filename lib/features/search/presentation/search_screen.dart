import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/search/data/search_history_controller.dart';

class SearchQuery {
  const SearchQuery(this.value);
  final String value;

  @override
  bool operator ==(Object other) =>
      other is SearchQuery && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

class SearchResults {
  const SearchResults({required this.streams, required this.categories});

  final List<TwitchStream> streams;
  final List<TwitchCategory> categories;
}

final searchResultsProvider = FutureProvider.family<SearchResults, SearchQuery>(
  (ref, query) async {
    final helix = ref.watch(helixRepositoryProvider);
    if (query.value.trim().isEmpty) {
      final categories = await helix.getTopGames();
      return SearchResults(streams: const [], categories: categories);
    }
    final streams = await helix.searchLiveChannels(query.value);
    final categories = await helix.searchCategories(query.value);
    return SearchResults(streams: streams.streams, categories: categories);
  },
);

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  var _query = const SearchQuery('');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      ref.read(searchHistoryControllerProvider.notifier).addQuery(trimmed);
    }
    setState(() => _query = SearchQuery(trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider(_query));
    final history = ref.watch(searchHistoryControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: _submit,
          decoration: const InputDecoration(
            hintText: 'Search streams or categories',
            border: InputBorder.none,
            filled: false,
          ),
        ),
        actions: [
          if (_query.value.isNotEmpty)
            IconButton(
              tooltip: 'Clear query',
              onPressed: () {
                _controller.clear();
                _submit('');
              },
              icon: const Icon(Icons.close),
            ),
          IconButton(
            onPressed: () => _submit(_controller.text),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              if (_query.value.isEmpty && history.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Recent searches', style: theme.textTheme.titleMedium),
                    TextButton(
                      onPressed: () => ref
                          .read(searchHistoryControllerProvider.notifier)
                          .clearAll(),
                      child: const Text('Clear all'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: history.map((item) {
                    return InputChip(
                      label: Text(item),
                      onPressed: () {
                        _controller.text = item;
                        _submit(item);
                      },
                      onDeleted: () => ref
                          .read(searchHistoryControllerProvider.notifier)
                          .removeQuery(item),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 20),
              ],
              Text(
                _query.value.isEmpty ? 'Popular categories' : 'Categories',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (data.categories.isEmpty)
                Text(
                  'No categories found.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                SizedBox(
                  height: 150,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: data.categories.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final cat = data.categories[index];
                      return InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => context.push(
                          '/category/${cat.id}?name=${Uri.encodeComponent(cat.name)}',
                        ),
                        child: SizedBox(
                          width: 96,
                          child: Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: CachedNetworkImage(
                                  imageUrl: cat.sizedBoxArt(),
                                  width: 96,
                                  height: 128,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelMedium,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 20),
              Text(
                _query.value.isEmpty
                    ? 'Type to find live channels'
                    : 'Live channels',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (data.streams.isEmpty)
                Text(
                  _query.value.isEmpty
                      ? 'Search for a channel name to see live results.'
                      : 'No live channels matched.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ...data.streams.map((stream) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: stream.sizedThumbnail(width: 120, height: 68),
                        width: 96,
                        height: 54,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      stream.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${stream.userName} · ${stream.gameName}'),
                    onTap: () {
                      final uri = Uri(
                        path: '/watch/${stream.userLogin}',
                        queryParameters: {
                          'title': stream.title,
                          'userId': stream.userId,
                        },
                      );
                      context.push(uri.toString());
                    },
                    onLongPress: () => context.push(
                      '/profile/${stream.userLogin}?userId=${stream.userId}',
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
