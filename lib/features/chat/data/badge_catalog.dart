import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';

class TwitchBadge {
  const TwitchBadge({
    required this.setId,
    required this.version,
    required this.imageUrl,
    this.title,
  });

  final String setId;
  final String version;
  final String imageUrl;
  final String? title;

  String get key => '$setId/$version';
}

class BadgeCatalog {
  BadgeCatalog({Map<String, TwitchBadge>? byKey})
    : byKey = byKey ?? <String, TwitchBadge>{};

  final Map<String, TwitchBadge> byKey;

  TwitchBadge? resolve(ChatBadgeRef ref) {
    return byKey['${ref.setId}/${ref.version}'] ??
        byKey['${ref.setId}/1'] ??
        byKey['${ref.setId}/0'];
  }

  List<TwitchBadge> resolveAll(List<ChatBadgeRef> refs) {
    return [for (final ref in refs) ?resolve(ref)];
  }

  BadgeCatalog merge(BadgeCatalog other) {
    return BadgeCatalog(byKey: {...byKey, ...other.byKey});
  }
}

class ChannelBadgesController extends AsyncNotifier<BadgeCatalog> {
  ChannelBadgesController(this.broadcasterId);

  final String broadcasterId;

  @override
  Future<BadgeCatalog> build() async {
    final repo = ref.watch(helixRepositoryProvider);
    final global = await repo.getGlobalChatBadges();
    if (broadcasterId.isEmpty) return global;
    final channel = await repo.getChannelChatBadges(broadcasterId);
    return global.merge(channel);
  }
}

final channelBadgesControllerProvider = AsyncNotifierProvider.autoDispose
    .family<ChannelBadgesController, BadgeCatalog, String>(
      ChannelBadgesController.new,
    );
