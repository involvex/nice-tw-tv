import 'dart:convert';

import 'package:nice_tv/features/history/data/history_entry.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HistoryStore {
  HistoryStore(this._prefs);

  static const _key = 'watch_history';
  static const _maxEntries = 100;

  final SharedPreferences _prefs;

  List<HistoryEntry> readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> add(HistoryEntry entry) async {
    final current = readAll();
    final next = [entry, ...current];
    if (next.length > _maxEntries) {
      next.removeRange(_maxEntries, next.length);
    }
    await _writeAll(next);
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }

  Future<void> _writeAll(List<HistoryEntry> entries) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await _prefs.setString(_key, encoded);
  }
}
