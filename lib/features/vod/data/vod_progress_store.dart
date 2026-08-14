import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VodProgressEntry {
  const VodProgressEntry({
    required this.vodId,
    required this.position,
    required this.title,
    required this.userName,
    required this.userLogin,
    required this.thumbnailUrl,
    required this.duration,
  });

  final String vodId;
  final Duration position;
  final String title;
  final String userName;
  final String userLogin;
  final String thumbnailUrl;
  final Duration duration;

  Map<String, dynamic> toJson() {
    return {
      'vodId': vodId,
      'position': position.inMilliseconds,
      'title': title,
      'userName': userName,
      'userLogin': userLogin,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration.inMilliseconds,
    };
  }

  factory VodProgressEntry.fromJson(Map<String, dynamic> json) {
    return VodProgressEntry(
      vodId: json['vodId'] as String? ?? '',
      position: Duration(milliseconds: json['position'] as int? ?? 0),
      title: json['title'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      userLogin: json['userLogin'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      duration: Duration(milliseconds: json['duration'] as int? ?? 0),
    );
  }
}

class VodProgressStore {
  VodProgressStore(this._prefs);

  static const _key = 'vod_progress';

  final SharedPreferences _prefs;

  List<VodProgressEntry> readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.values
          .map((e) => VodProgressEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return [];
    }
  }

  Future<void> saveProgress(VodProgressEntry entry) async {
    final all = readAll();
    final index = all.indexWhere((e) => e.vodId == entry.vodId);
    if (index >= 0) {
      all[index] = entry;
    } else {
      all.add(entry);
    }
    await _writeAll(all);
  }

  Duration? readPosition(String vodId) {
    for (final e in readAll()) {
      if (e.vodId == vodId) return e.position;
    }
    return null;
  }

  VodProgressEntry? readEntry(String vodId) {
    for (final e in readAll()) {
      if (e.vodId == vodId) return e;
    }
    return null;
  }

  Future<void> clear(String vodId) async {
    final all = readAll();
    all.removeWhere((e) => e.vodId == vodId);
    await _writeAll(all);
  }

  Future<void> _writeAll(List<VodProgressEntry> entries) async {
    final map = <String, Map<String, dynamic>>{};
    for (final entry in entries) {
      map[entry.vodId] = entry.toJson();
    }
    await _prefs.setString(_key, jsonEncode(map));
  }
}

final vodProgressStoreProvider = Provider<VodProgressStore>((ref) {
  return VodProgressStore(ref.watch(sharedPreferencesProvider));
});
