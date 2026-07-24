class TwitchVod {
  const TwitchVod({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.title,
    required this.url,
    required this.thumbnailUrl,
    required this.viewCount,
    required this.duration,
    required this.createdAt,
    required this.type,
  });

  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String title;
  final String url;
  final String thumbnailUrl;
  final int viewCount;
  final String duration;
  final DateTime createdAt;
  final String type;

  factory TwitchVod.fromJson(Map<String, dynamic> json) {
    return TwitchVod(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      userLogin: json['user_login'] as String? ?? '',
      userName: json['user_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      url: json['url'] as String? ?? '',
      thumbnailUrl: json['thumbnail_url'] as String? ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      duration: json['duration'] as String? ?? '',
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      type: json['type'] as String? ?? 'archive',
    );
  }

  String sizedThumbnail({int width = 440, int height = 248}) {
    return thumbnailUrl
        .replaceAll('%{width}', '$width')
        .replaceAll('%{height}', '$height')
        .replaceAll('{width}', '$width')
        .replaceAll('{height}', '$height');
  }
}

class VodsPage {
  const VodsPage({required this.vods, this.cursor});

  final List<TwitchVod> vods;
  final String? cursor;
}
