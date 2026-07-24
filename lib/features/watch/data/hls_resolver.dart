import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/network/dio_providers.dart';

class HlsVariant {
  const HlsVariant({
    required this.name,
    required this.url,
    this.height,
    this.bandwidth,
  });

  final String name;
  final Uri url;
  final int? height;
  final int? bandwidth;

  bool get isAudioOnly =>
      name.toLowerCase().contains('audio') || height == 0;
}

class HlsPlaylist {
  const HlsPlaylist({required this.masterUrl, required this.variants});

  final Uri masterUrl;
  final List<HlsVariant> variants;

  HlsVariant get best => variants.isEmpty
      ? HlsVariant(name: 'auto', url: masterUrl)
      : variants.first;
}

/// Resolves Twitch HLS playlists via GQL playback tokens + Usher.
///
/// Experimental / unofficial — prefer the embed player for stability.
class HlsResolver {
  HlsResolver(this._dio);

  /// Public Twitch web client id used by the site player.
  static const webClientId = 'kimne78kx3ncx6brgo4mv6wki5h1ko';

  static const _playbackQuery = r'''
query PlaybackAccessToken(
  $login: String!
  $isLive: Boolean!
  $vodID: ID!
  $isVod: Boolean!
  $playerType: String!
) {
  streamPlaybackAccessToken(
    channelName: $login
    params: {
      platform: "web"
      playerBackend: "mediaplayer"
      playerType: $playerType
    }
  ) @include(if: $isLive) {
    value
    signature
  }
  videoPlaybackAccessToken(
    id: $vodID
    params: {
      platform: "web"
      playerBackend: "mediaplayer"
      playerType: $playerType
    }
  ) @include(if: $isVod) {
    value
    signature
  }
}
''';

  final Dio _dio;

  Future<Uri> resolveLive(String channelLogin) async {
    final playlist = await resolveLivePlaylist(channelLogin);
    return playlist.masterUrl;
  }

  Future<Uri> resolveVod(String vodId) async {
    final playlist = await resolveVodPlaylist(vodId);
    return playlist.masterUrl;
  }

  Future<HlsPlaylist> resolveLivePlaylist(String channelLogin) async {
    final token = await _fetchToken(
      login: channelLogin.toLowerCase(),
      isLive: true,
      vodId: '',
      isVod: false,
    );
    final master = Uri.https(
      'usher.ttvnw.net',
      '/api/v2/channel/hls/$channelLogin.m3u8',
      {
        'client_id': webClientId,
        'token': token.value,
        'sig': token.signature,
        'allow_source': 'true',
        'allow_audio_only': 'true',
        'fast_bread': 'true',
        'p': '${DateTime.now().millisecondsSinceEpoch % 9999999}',
      },
    );
    return _loadPlaylist(master);
  }

  Future<HlsPlaylist> resolveVodPlaylist(String vodId) async {
    final token = await _fetchToken(
      login: '',
      isLive: false,
      vodId: vodId,
      isVod: true,
    );
    final master = Uri.https('usher.ttvnw.net', '/vod/$vodId.m3u8', {
      'client_id': webClientId,
      'token': token.value,
      'sig': token.signature,
      'allow_source': 'true',
      'allow_audio_only': 'true',
      'p': '${DateTime.now().millisecondsSinceEpoch % 9999999}',
    });
    return _loadPlaylist(master);
  }

  Future<HlsPlaylist> _loadPlaylist(Uri master) async {
    final response = await _dio.get<String>(
      master.toString(),
      options: Options(responseType: ResponseType.plain),
    );
    final body = response.data ?? '';
    final variants = parseMasterPlaylist(body, master);
    return HlsPlaylist(
      masterUrl: master,
      variants: variants.isEmpty
          ? [HlsVariant(name: 'auto', url: master)]
          : variants,
    );
  }

  /// Parses an HLS master playlist into named quality variants.
  static List<HlsVariant> parseMasterPlaylist(String body, Uri masterUrl) {
    final lines = body.split(RegExp(r'\r?\n'));
    final mediaNames = <String, String>{};
    final variants = <HlsVariant>[];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.startsWith('#EXT-X-MEDIA:') && line.contains('TYPE=VIDEO')) {
        final groupId = _attr(line, 'GROUP-ID');
        final name = _attr(line, 'NAME');
        if (groupId != null && name != null) {
          mediaNames[groupId] = name;
        }
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (!line.startsWith('#EXT-X-STREAM-INF:')) continue;
      final bandwidth = int.tryParse(_attr(line, 'BANDWIDTH') ?? '');
      final resolution = _attr(line, 'RESOLUTION');
      final videoGroup = _attr(line, 'VIDEO');
      final height = resolution != null && resolution.contains('x')
          ? int.tryParse(resolution.split('x').last)
          : null;
      String? uri;
      for (var j = i + 1; j < lines.length; j++) {
        final next = lines[j].trim();
        if (next.isEmpty || next.startsWith('#')) continue;
        uri = next;
        break;
      }
      if (uri == null) continue;
      final name =
          (videoGroup != null ? mediaNames[videoGroup] : null) ??
          (height != null ? '${height}p' : 'variant');
      variants.add(
        HlsVariant(
          name: name,
          url: masterUrl.resolve(uri),
          height: height,
          bandwidth: bandwidth,
        ),
      );
    }

    variants.sort((a, b) {
      final ah = a.height ?? -1;
      final bh = b.height ?? -1;
      if (ah != bh) return bh.compareTo(ah);
      return (b.bandwidth ?? 0).compareTo(a.bandwidth ?? 0);
    });
    return variants;
  }

  static String? _attr(String line, String key) {
    final match = RegExp('$key="?([^",]+)(?:"|,|\$)').firstMatch(line);
    return match?.group(1);
  }

  Future<({String value, String signature})> _fetchToken({
    required String login,
    required bool isLive,
    required String vodId,
    required bool isVod,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      'https://gql.twitch.tv/gql',
      data: {
        'operationName': 'PlaybackAccessToken',
        'query': _playbackQuery,
        'variables': {
          'isLive': isLive,
          'login': login,
          'isVod': isVod,
          'vodID': vodId,
          'playerType': 'site',
        },
      },
      options: Options(
        headers: {'Client-ID': webClientId, 'Content-Type': 'application/json'},
      ),
    );
    final data = response.data?['data'] as Map<String, dynamic>?;
    final node =
        (data?['streamPlaybackAccessToken'] ??
                data?['videoPlaybackAccessToken'])
            as Map<String, dynamic>?;
    if (node == null) {
      throw StateError('No playback access token returned for Twitch media');
    }
    final value = node['value'] as String? ?? '';
    final signature = node['signature'] as String? ?? '';
    if (value.isEmpty || signature.isEmpty) {
      throw StateError('Invalid playback access token');
    }
    if (!value.startsWith('{')) {
      jsonDecode(value); // validate
    }
    return (value: value, signature: signature);
  }
}

final hlsResolverProvider = Provider<HlsResolver>((ref) {
  return HlsResolver(ref.watch(dioProvider));
});
