class VodChapter {
  const VodChapter({required this.title, required this.seekSeconds});

  final String title;
  final int seekSeconds;

  factory VodChapter.fromJson(Map<String, dynamic> json) {
    return VodChapter(
      title: json['title'] as String? ?? '',
      seekSeconds:
          json['seek_seconds'] as int? ?? json['seekSeconds'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'seek_seconds': seekSeconds,
  };
}

class VodChapters {
  const VodChapters({required this.chapters});

  final List<VodChapter> chapters;

  factory VodChapters.fromJson(Map<String, dynamic> json) {
    final list =
        json['data'] as List<dynamic>? ??
        json['chapters'] as List<dynamic>? ??
        [];
    return VodChapters(
      chapters: list
          .map((e) => VodChapter.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
