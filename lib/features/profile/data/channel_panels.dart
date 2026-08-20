class ChannelPanel {
  const ChannelPanel({
    required this.title,
    required this.linkUrl,
    required this.imageUrl,
  });

  final String title;
  final String linkUrl;
  final String imageUrl;
}

class ChannelPanels {
  const ChannelPanels({required this.panels});

  final List<ChannelPanel> panels;

  factory ChannelPanels.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List<dynamic>? ?? const [];
    final panels = <ChannelPanel>[];
    for (final raw in list) {
      final item = raw as Map<String, dynamic>;
      panels.add(
        ChannelPanel(
          title: item['title'] as String? ?? '',
          linkUrl: item['link_url'] as String? ?? item['url'] as String? ?? '',
          imageUrl: item['image_url'] as String? ?? '',
        ),
      );
    }
    return ChannelPanels(panels: panels);
  }
}
