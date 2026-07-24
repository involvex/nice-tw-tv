import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/emotes/data/emote.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';

class EmoteRepository {
  EmoteRepository({required this.helix, required this.plain});

  final Dio helix;
  final Dio plain;

  Future<EmoteCatalog> loadForChannel({
    required String broadcasterId,
    String? userToken,
  }) async {
    final results = await Future.wait([
      _loadTwitchGlobal(),
      _loadTwitchChannel(broadcasterId),
      _loadBttvGlobal(),
      _loadBttvChannel(broadcasterId),
      _loadFfzGlobal(),
      _loadFfzChannel(broadcasterId),
      _loadSevenTvGlobal(),
      _loadSevenTvChannel(broadcasterId),
    ]);
    return results.fold<EmoteCatalog>(
      EmoteCatalog(),
      (acc, next) => acc.merge(next),
    );
  }

  Future<EmoteCatalog> _loadTwitchGlobal() async {
    try {
      final response = await helix.get<Map<String, dynamic>>(
        '/helix/chat/emotes/global',
      );
      return _parseTwitch(response.data?['data'] as List<dynamic>? ?? []);
    } on Object {
      return EmoteCatalog();
    }
  }

  Future<EmoteCatalog> _loadTwitchChannel(String broadcasterId) async {
    try {
      final response = await helix.get<Map<String, dynamic>>(
        '/helix/chat/emotes',
        queryParameters: {'broadcaster_id': broadcasterId},
      );
      return _parseTwitch(response.data?['data'] as List<dynamic>? ?? []);
    } on Object {
      return EmoteCatalog();
    }
  }

  EmoteCatalog _parseTwitch(List<dynamic> data) {
    final map = <String, Emote>{};
    for (final raw in data) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String? ?? '';
      final name = json['name'] as String? ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      map[name] = Emote(
        id: id,
        name: name,
        url: 'https://static-cdn.jtvnw.net/emoticons/v2/$id/default/dark/2.0',
        provider: EmoteProvider.twitch,
      );
    }
    return EmoteCatalog(byName: map);
  }

  Future<EmoteCatalog> _loadBttvGlobal() async {
    try {
      final response = await plain.get<List<dynamic>>(
        'https://api.betterttv.net/3/cached/emotes/global',
      );
      return _parseBttv(response.data ?? []);
    } on Object {
      return EmoteCatalog();
    }
  }

  Future<EmoteCatalog> _loadBttvChannel(String twitchId) async {
    try {
      final response = await plain.get<Map<String, dynamic>>(
        'https://api.betterttv.net/3/cached/users/twitch/$twitchId',
      );
      final data = response.data ?? {};
      final channel = data['channelEmotes'] as List<dynamic>? ?? [];
      final shared = data['sharedEmotes'] as List<dynamic>? ?? [];
      return _parseBttv([...channel, ...shared]);
    } on Object {
      return EmoteCatalog();
    }
  }

  EmoteCatalog _parseBttv(List<dynamic> data) {
    final map = <String, Emote>{};
    for (final raw in data) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String? ?? '';
      final code = json['code'] as String? ?? '';
      if (id.isEmpty || code.isEmpty) continue;
      map[code] = Emote(
        id: id,
        name: code,
        url: 'https://cdn.betterttv.net/emote/$id/2x',
        provider: EmoteProvider.bttv,
      );
    }
    return EmoteCatalog(byName: map);
  }

  Future<EmoteCatalog> _loadFfzGlobal() async {
    try {
      final response = await plain.get<Map<String, dynamic>>(
        'https://api.frankerfacez.com/v1/set/global',
      );
      final sets = response.data?['sets'] as Map<String, dynamic>? ?? {};
      final map = <String, Emote>{};
      for (final set in sets.values) {
        final emoticons =
            (set as Map<String, dynamic>)['emoticons'] as List<dynamic>? ?? [];
        map.addAll(_parseFfz(emoticons).byName);
      }
      return EmoteCatalog(byName: map);
    } on Object {
      return EmoteCatalog();
    }
  }

  Future<EmoteCatalog> _loadFfzChannel(String twitchId) async {
    try {
      final response = await plain.get<Map<String, dynamic>>(
        'https://api.frankerfacez.com/v1/room/id/$twitchId',
      );
      final sets = response.data?['sets'] as Map<String, dynamic>? ?? {};
      final map = <String, Emote>{};
      for (final set in sets.values) {
        final emoticons =
            (set as Map<String, dynamic>)['emoticons'] as List<dynamic>? ?? [];
        map.addAll(_parseFfz(emoticons).byName);
      }
      return EmoteCatalog(byName: map);
    } on Object {
      return EmoteCatalog();
    }
  }

  EmoteCatalog _parseFfz(List<dynamic> data) {
    final map = <String, Emote>{};
    for (final raw in data) {
      final json = raw as Map<String, dynamic>;
      final id = '${json['id']}';
      final name = json['name'] as String? ?? '';
      final urls = json['urls'] as Map<String, dynamic>? ?? {};
      final url = (urls['2'] ?? urls['1'] ?? urls['4']) as String?;
      if (name.isEmpty || url == null) continue;
      map[name] = Emote(
        id: id,
        name: name,
        url: url.startsWith('//') ? 'https:$url' : url,
        provider: EmoteProvider.ffz,
      );
    }
    return EmoteCatalog(byName: map);
  }

  Future<EmoteCatalog> _loadSevenTvGlobal() async {
    try {
      final response = await plain.get<Map<String, dynamic>>(
        'https://7tv.io/v3/emote-sets/global',
      );
      final emotes = response.data?['emotes'] as List<dynamic>? ?? [];
      return _parseSevenTv(emotes);
    } on Object {
      return EmoteCatalog();
    }
  }

  Future<EmoteCatalog> _loadSevenTvChannel(String twitchId) async {
    try {
      final response = await plain.get<Map<String, dynamic>>(
        'https://7tv.io/v3/users/twitch/$twitchId',
      );
      final set = response.data?['emote_set'] as Map<String, dynamic>?;
      final emotes = set?['emotes'] as List<dynamic>? ?? [];
      return _parseSevenTv(emotes);
    } on Object {
      return EmoteCatalog();
    }
  }

  EmoteCatalog _parseSevenTv(List<dynamic> data) {
    final map = <String, Emote>{};
    for (final raw in data) {
      final json = raw as Map<String, dynamic>;
      final id = json['id'] as String? ?? '';
      final name = json['name'] as String? ?? '';
      if (id.isEmpty || name.isEmpty) continue;
      final dataNode = json['data'] as Map<String, dynamic>?;
      final host = dataNode?['host'] as Map<String, dynamic>?;
      final hostUrl = host?['url'] as String?;
      final files = host?['files'] as List<dynamic>? ?? [];
      String? fileName;
      for (final file in files) {
        final f = file as Map<String, dynamic>;
        final namePart = f['name'] as String? ?? '';
        if (namePart.contains('2x') || namePart.contains('3x')) {
          fileName = namePart;
          break;
        }
      }
      fileName ??= files.isNotEmpty
          ? (files.first as Map<String, dynamic>)['name'] as String?
          : null;
      if (hostUrl == null || fileName == null) continue;
      final url = hostUrl.startsWith('//')
          ? 'https:$hostUrl/$fileName'
          : '$hostUrl/$fileName';
      final flags = json['flags'] as int? ?? 0;
      map[name] = Emote(
        id: id,
        name: name,
        url: url,
        provider: EmoteProvider.sevenTv,
        isZeroWidth: flags & 1 == 1,
      );
    }
    return EmoteCatalog(byName: map);
  }
}

final emoteRepositoryProvider = Provider<EmoteRepository>((ref) {
  return EmoteRepository(
    helix: ref.watch(helixDioProvider),
    plain: ref.watch(dioProvider),
  );
});

final channelEmotesProvider = FutureProvider.family<EmoteCatalog, String>((
  ref,
  broadcasterId,
) async {
  if (broadcasterId.isEmpty) return EmoteCatalog();
  return ref
      .read(emoteRepositoryProvider)
      .loadForChannel(broadcasterId: broadcasterId);
});
