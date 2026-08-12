import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VodProgressStore {
  VodProgressStore(this._prefs);

  static const _key = 'vod_progress';

  final SharedPreferences _prefs;

  Map<String, int> readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as int)));
    } on Object {
      return {};
    }
  }

  Future<void> savePosition(String vodId, Duration position) async {
    final all = readAll();
    all[vodId] = position.inMilliseconds;
    await _writeAll(all);
  }

  Duration? readPosition(String vodId) {
    final all = readAll();
    final ms = all[vodId];
    if (ms == null) return null;
    return Duration(milliseconds: ms);
  }

  Future<void> clear(String vodId) async {
    final all = readAll();
    all.remove(vodId);
    await _writeAll(all);
  }

  Future<void> _writeAll(Map<String, int> map) async {
    final encoded = jsonEncode(map);
    await _prefs.setString(_key, encoded);
  }
}

final vodProgressStoreProvider = Provider<VodProgressStore>((ref) {
  return VodProgressStore(ref.watch(sharedPreferencesProvider));
});
