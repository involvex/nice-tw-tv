import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/network/dio_providers.dart';

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
    final token = await _fetchToken(
      login: channelLogin.toLowerCase(),
      isLive: true,
      vodId: '',
      isVod: false,
    );
    return Uri.https(
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
  }

  Future<Uri> resolveVod(String vodId) async {
    final token = await _fetchToken(
      login: '',
      isLive: false,
      vodId: vodId,
      isVod: true,
    );
    return Uri.https('usher.ttvnw.net', '/vod/$vodId.m3u8', {
      'client_id': webClientId,
      'token': token.value,
      'sig': token.signature,
      'allow_source': 'true',
      'allow_audio_only': 'true',
      'p': '${DateTime.now().millisecondsSinceEpoch % 9999999}',
    });
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
    // Token value is a JSON string — Usher expects it URL-encoded as-is.
    // Ensure it stays a string (Dio may leave it as String).
    if (value.startsWith('{')) {
      // already fine
    } else {
      jsonDecode(value); // validate
    }
    return (value: value, signature: signature);
  }
}

final hlsResolverProvider = Provider<HlsResolver>((ref) {
  return HlsResolver(ref.watch(dioProvider));
});
