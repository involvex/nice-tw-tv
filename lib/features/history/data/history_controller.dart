import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';
import 'package:nice_tv/features/history/data/history_store.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class HistoryController extends Notifier<List<HistoryEntry>> {
  @override
  List<HistoryEntry> build() {
    final store = HistoryStore(ref.watch(sharedPreferencesProvider));
    return store.readAll();
  }

  Future<void> addEntry(HistoryEntry entry) async {
    final store = HistoryStore(ref.watch(sharedPreferencesProvider));
    await store.add(entry);
    state = [entry, ...state];
    if (state.length > 100) {
      state = state.sublist(0, 100);
    }
  }

  Future<void> clearAll() async {
    final store = HistoryStore(ref.watch(sharedPreferencesProvider));
    await store.clear();
    state = const [];
  }
}

final historyControllerProvider =
    NotifierProvider<HistoryController, List<HistoryEntry>>(
      HistoryController.new,
    );
