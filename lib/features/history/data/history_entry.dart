class HistoryEntry {
  const HistoryEntry({
    required this.userLogin,
    required this.userName,
    this.title,
    this.gameName,
    required this.thumbnailUrl,
    required this.watchedAt,
    this.streamId,
  });

  final String userLogin;
  final String userName;
  final String? title;
  final String? gameName;
  final String thumbnailUrl;
  final DateTime watchedAt;
  final String? streamId;

  HistoryEntry copyWith({
    String? userLogin,
    String? userName,
    String? title,
    String? gameName,
    String? thumbnailUrl,
    DateTime? watchedAt,
    String? streamId,
  }) {
    return HistoryEntry(
      userLogin: userLogin ?? this.userLogin,
      userName: userName ?? this.userName,
      title: title ?? this.title,
      gameName: gameName ?? this.gameName,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      watchedAt: watchedAt ?? this.watchedAt,
      streamId: streamId ?? this.streamId,
    );
  }

  Map<String, dynamic> toJson() => {
    'userLogin': userLogin,
    'userName': userName,
    'title': title,
    'gameName': gameName,
    'thumbnailUrl': thumbnailUrl,
    'watchedAt': watchedAt.toIso8601String(),
    'streamId': streamId,
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      userLogin: json['userLogin'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      title: json['title'] as String?,
      gameName: json['gameName'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      watchedAt:
          DateTime.tryParse(json['watchedAt'] as String? ?? '') ??
          DateTime.now(),
      streamId: json['streamId'] as String?,
    );
  }
}
