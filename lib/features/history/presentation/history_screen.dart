import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/history/data/history_controller.dart';
import 'package:nice_tv/features/history/data/history_search_controller.dart';
import 'package:nice_tv/features/history/presentation/history_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyControllerProvider);
    final searchResults = ref.watch(filteredHistoryProvider);
    final searchText = ref.watch(historySearchQueryProvider);
    final theme = Theme.of(context);

    final displayList = _searching ? searchResults : history;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search watch history',
                  border: InputBorder.none,
                  isDense: true,
                  hintStyle: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                style: theme.textTheme.titleMedium,
                onChanged: (value) {
                  ref.read(historySearchQueryProvider.notifier).setQuery(value);
                },
              )
            : const Text('History'),
        actions: [
          if (_searching)
            IconButton(
              tooltip: 'Clear search',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.close),
              onPressed: () {
                _searchController.clear();
                ref.read(historySearchQueryProvider.notifier).clear();
                setState(() => _searching = false);
              },
            )
          else if (history.isNotEmpty)
            IconButton(
              tooltip: 'Search history',
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _searching = true),
            ),
          if (history.isNotEmpty)
            IconButton(
              tooltip: 'Clear history',
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Clear history?'),
                    content: const Text(
                      'This will permanently remove all watch history.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirm == true && context.mounted) {
                  await ref.read(historyControllerProvider.notifier).clearAll();
                  if (_searching) {
                    _searchController.clear();
                    ref.read(historySearchQueryProvider.notifier).clear();
                    setState(() => _searching = false);
                  }
                }
              },
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_outlined,
                      size: 56,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No watch history yet',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Streams you watch will appear here.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : displayList.isEmpty
          ? Center(
              child: Text(
                _searching
                    ? 'No results for "$searchText".'
                    : 'No watch history yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: displayList.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = displayList[index];
                return HistoryCard(entry: entry);
              },
            ),
    );
  }
}
