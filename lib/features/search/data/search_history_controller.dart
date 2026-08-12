import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryStore {
  SearchHistoryStore(this._prefs);

  static const _key = 'search_history';
  static const _maxEntries = 20;

  final SharedPreferences _prefs;

  List<String> readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).toList();
    } on Object {
      return const [];
    }
  }

  Future<void> add(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return;
    final current = readAll();
    final next = [trimmed, ...current.where((q) => q != trimmed)];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _writeAll(next);
  }

  Future<void> remove(String query) async {
    final current = readAll();
    final next = current.where((q) => q != query).toList();
    await _writeAll(next);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  Future<void> _writeAll(List<String> queries) async {
    final encoded = jsonEncode(queries);
    await _prefs.setString(_key, encoded);
  }
}

class SearchHistoryController extends Notifier<List<String>> {
  @override
  List<String> build() {
    final store = SearchHistoryStore(ref.watch(sharedPreferencesProvider));
    return store.readAll();
  }

  Future<void> addQuery(String query) async {
    final store = SearchHistoryStore(ref.watch(sharedPreferencesProvider));
    await store.add(query);
    state = store.readAll();
  }

  Future<void> removeQuery(String query) async {
    final store = SearchHistoryStore(ref.watch(sharedPreferencesProvider));
    await store.remove(query);
    state = store.readAll();
  }

  Future<void> clearAll() async {
    final store = SearchHistoryStore(ref.watch(sharedPreferencesProvider));
    await store.clear();
    state = const [];
  }
}

final searchHistoryControllerProvider =
    NotifierProvider<SearchHistoryController, List<String>>(
      SearchHistoryController.new,
    );
