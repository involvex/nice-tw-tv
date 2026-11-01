class TwitchStream {
  const TwitchStream({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.gameName,
    required this.gameId,
    required this.title,
    required this.viewerCount,
    required this.thumbnailUrl,
    required this.startedAt,
    required this.isMature,
    required this.language,
  });

  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String gameName;
  final String gameId;
  final String title;
  final int viewerCount;
  final String thumbnailUrl;
  final DateTime startedAt;
  final bool isMature;
  final String language;

  factory TwitchStream.fromJson(Map<String, dynamic> json) {
    return TwitchStream(
      id: json['id'] as String? ?? '',
      userId:
          (json['user_id'] ?? json['broadcaster_id'] ?? json['id'])
              as String? ??
          '',
      userLogin:
          (json['user_login'] ?? json['broadcaster_login']) as String? ?? '',
      userName:
          (json['user_name'] ??
                  json['broadcaster_name'] ??
                  json['display_name'])
              as String? ??
          '',
      gameName: json['game_name'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      viewerCount: json['viewer_count'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      isMature: json['is_mature'] as bool? ?? false,
      language:
          (json['language'] ?? json['broadcaster_language']) as String? ?? 'en',
    );
  }

  TwitchStream copyWith({
    String? id,
    String? userId,
    String? userLogin,
    String? userName,
    String? gameName,
    String? gameId,
    String? title,
    int? viewerCount,
    String? thumbnailUrl,
    DateTime? startedAt,
    bool? isMature,
    String? language,
  }) {
    return TwitchStream(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userLogin: userLogin ?? this.userLogin,
      userName: userName ?? this.userName,
      gameName: gameName ?? this.gameName,
      gameId: gameId ?? this.gameId,
      title: title ?? this.title,
      viewerCount: viewerCount ?? this.viewerCount,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      startedAt: startedAt ?? this.startedAt,
      isMature: isMature ?? this.isMature,
      language: language ?? this.language,
    );
  }

  String sizedThumbnail({int width = 440, int height = 248}) {
    return thumbnailUrl
        .replaceAll('{width}', '$width')
        .replaceAll('{height}', '$height');
  }
}

/// Splits Helix multi-value query IDs into chunks of [maxPerRequest].
///
/// Empty strings are dropped. Used so map-style query params do not overwrite
/// duplicate keys (e.g. only the last `broadcaster_id` would be sent).
List<List<String>> batchHelixIds(List<String> ids, int maxPerRequest) {
  assert(maxPerRequest > 0);
  final valid = ids.where((id) => id.isNotEmpty).toList();
  if (valid.isEmpty) return const [];
  final batches = <List<String>>[];
  for (var i = 0; i < valid.length; i += maxPerRequest) {
    final end = (i + maxPerRequest).clamp(0, valid.length);
    batches.add(valid.sublist(i, end));
  }
  return batches;
}

/// Merges Search Channels hits with `/helix/streams` rows.
///
/// Search Channels lacks `viewer_count` and uses the profile image as
/// `thumbnail_url`. Prefer live stream fields when a matching user is online;
/// drop hits that are no longer live.
List<TwitchStream> mergeSearchWithLiveStreams(
  List<TwitchStream> searchHits,
  List<TwitchStream> liveStreams,
) {
  final byUserId = <String, TwitchStream>{
    for (final s in liveStreams)
      if (s.userId.isNotEmpty) s.userId: s,
  };
  final merged = <TwitchStream>[];
  for (final hit in searchHits) {
    final live = byUserId[hit.userId];
    if (live == null) continue;
    merged.add(
      live.copyWith(
        userLogin: live.userLogin.isNotEmpty ? live.userLogin : hit.userLogin,
        userName: live.userName.isNotEmpty ? live.userName : hit.userName,
      ),
    );
  }
  return merged;
}

class StreamsPage {
  const StreamsPage({required this.streams, this.cursor});

  final List<TwitchStream> streams;
  final String? cursor;
}
