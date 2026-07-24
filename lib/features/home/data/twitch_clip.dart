class TwitchClip {
  const TwitchClip({
    required this.id,
    required this.url,
    required this.embedUrl,
    required this.broadcasterId,
    required this.broadcasterName,
    required this.creatorName,
    required this.videoId,
    required this.gameId,
    required this.title,
    required this.viewCount,
    required this.createdAt,
    required this.thumbnailUrl,
    required this.duration,
  });

  final String id;
  final String url;
  final String embedUrl;
  final String broadcasterId;
  final String broadcasterName;
  final String creatorName;
  final String videoId;
  final String gameId;
  final String title;
  final int viewCount;
  final DateTime createdAt;
  final String thumbnailUrl;
  final double duration;

  factory TwitchClip.fromJson(Map<String, dynamic> json) {
    return TwitchClip(
      id: json['id'] as String? ?? '',
      url: json['url'] as String? ?? '',
      embedUrl: json['embed_url'] as String? ?? '',
      broadcasterId: json['broadcaster_id'] as String? ?? '',
      broadcasterName: json['broadcaster_name'] as String? ?? '',
      creatorName: json['creator_name'] as String? ?? '',
      videoId: json['video_id'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      duration: (json['duration'] as num?)?.toDouble() ?? 0,
    );
  }

  String sizedThumbnail({int width = 480, int height = 272}) {
    return thumbnailUrl
        .replaceAll('%{width}', '$width')
        .replaceAll('%{height}', '$height')
        .replaceAll('{width}', '$width')
        .replaceAll('{height}', '$height');
  }
}

class ClipsPage {
  const ClipsPage({required this.clips, this.cursor});

  final List<TwitchClip> clips;
  final String? cursor;
}
