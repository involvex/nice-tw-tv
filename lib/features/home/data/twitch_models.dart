class TwitchCategory {
  const TwitchCategory({
    required this.id,
    required this.name,
    required this.boxArtUrl,
  });

  final String id;
  final String name;
  final String boxArtUrl;

  factory TwitchCategory.fromJson(Map<String, dynamic> json) {
    return TwitchCategory(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      boxArtUrl: json['box_art_url'] as String? ?? '',
    );
  }

  String sizedBoxArt({int width = 144, int height = 192}) {
    return boxArtUrl
        .replaceAll('{width}', '$width')
        .replaceAll('{height}', '$height');
  }
}

class TwitchUserProfile {
  const TwitchUserProfile({
    required this.id,
    required this.login,
    required this.displayName,
    required this.description,
    required this.profileImageUrl,
    required this.offlineImageUrl,
    required this.viewCount,
    required this.createdAt,
  });

  final String id;
  final String login;
  final String displayName;
  final String description;
  final String profileImageUrl;
  final String offlineImageUrl;
  final int viewCount;
  final DateTime createdAt;

  factory TwitchUserProfile.fromJson(Map<String, dynamic> json) {
    return TwitchUserProfile(
      id: json['id'] as String? ?? '',
      login: json['login'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      profileImageUrl: json['profile_image_url'] as String? ?? '',
      offlineImageUrl: json['offline_image_url'] as String? ?? '',
      viewCount: json['view_count'] as int? ?? 0,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class TwitchChannelInfo {
  const TwitchChannelInfo({
    required this.broadcasterId,
    required this.broadcasterLogin,
    required this.broadcasterName,
    required this.gameId,
    required this.gameName,
    required this.title,
    required this.language,
    required this.isLive,
  });

  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterName;
  final String gameId;
  final String gameName;
  final String title;
  final String language;
  final bool? isLive;

  factory TwitchChannelInfo.fromJson(Map<String, dynamic> json) {
    return TwitchChannelInfo(
      broadcasterId: json['broadcaster_id'] as String? ?? '',
      broadcasterLogin: json['broadcaster_login'] as String? ?? '',
      broadcasterName: json['broadcaster_name'] as String? ?? '',
      gameId: json['game_id'] as String? ?? '',
      gameName: json['game_name'] as String? ?? '',
      title: json['title'] as String? ?? '',
      language: json['broadcaster_language'] as String? ?? '',
      isLive: json['is_live'] as bool?,
    );
  }
}
