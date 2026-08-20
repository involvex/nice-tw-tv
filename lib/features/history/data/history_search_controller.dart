import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/history/data/history_controller.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';

List<HistoryEntry> filterHistory(List<HistoryEntry> items, String query) {
  if (query.trim().isEmpty) {
    final all = List<HistoryEntry>.of(items);
    all.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
    return all;
  }
  final lower = query.toLowerCase();
  final results = items.where((entry) {
    return entry.userLogin.toLowerCase().contains(lower) ||
        entry.userName.toLowerCase().contains(lower) ||
        (entry.title?.toLowerCase().contains(lower) ?? false) ||
        (entry.gameName?.toLowerCase().contains(lower) ?? false);
  }).toList();
  results.sort((a, b) => b.watchedAt.compareTo(a.watchedAt));
  return results;
}

class HistorySearchQueryController extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String value) => state = value;

  void clear() => state = '';
}

final historySearchQueryProvider =
    NotifierProvider<HistorySearchQueryController, String>(
      HistorySearchQueryController.new,
    );

final filteredHistoryProvider = Provider<List<HistoryEntry>>((ref) {
  final query = ref.watch(historySearchQueryProvider);
  final history = ref.watch(historyControllerProvider);
  return filterHistory(history, query);
});
