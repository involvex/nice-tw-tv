enum EmoteProvider { twitch, bttv, ffz, sevenTv }

class Emote {
  const Emote({
    required this.id,
    required this.name,
    required this.url,
    required this.provider,
    this.isZeroWidth = false,
  });

  final String id;
  final String name;
  final String url;
  final EmoteProvider provider;
  final bool isZeroWidth;
}

class EmoteCatalog {
  EmoteCatalog({Map<String, Emote>? byName})
    : byName = byName ?? <String, Emote>{};

  final Map<String, Emote> byName;

  Emote? operator [](String name) => byName[name];

  List<Emote> get all =>
      byName.values.toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  List<Emote> suggest(String prefix, {int limit = 12}) {
    if (prefix.isEmpty) return const [];
    final lower = prefix.toLowerCase();
    return all
        .where((e) => e.name.toLowerCase().startsWith(lower))
        .take(limit)
        .toList();
  }

  EmoteCatalog merge(EmoteCatalog other) {
    return EmoteCatalog(byName: {...byName, ...other.byName});
  }
}
