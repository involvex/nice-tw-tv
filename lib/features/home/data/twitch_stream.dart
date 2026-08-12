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
      userId: json['user_id'] as String? ?? '',
      userLogin: json['user_login'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      gameName: json['game_name'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      viewerCount: json['viewer_count'] as int? ?? 0,
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      startedAt:
          DateTime.tryParse(json['started_at'] as String? ?? '') ??
          DateTime.now(),
      isMature: json['is_mature'] as bool? ?? false,
      language: json['language'] as String? ?? 'en',
    );
  }

  String sizedThumbnail({int width = 440, int height = 248}) {
    return thumbnailUrl
        .replaceAll('{width}', '$width')
        .replaceAll('{height}', '$height');
  }
}

class StreamsPage {
  const StreamsPage({required this.streams, this.cursor});

  final List<TwitchStream> streams;
  final String? cursor;
}
