import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';

typedef FollowedChannel = ({String id, String login, String displayName});

final offlineFollowedChannelsProvider =
    FutureProvider.autoDispose<List<FollowedChannel>>((ref) async {
      final auth = ref.watch(authControllerProvider).value;
      if (auth?.isLoggedIn != true || auth?.userId == null) return const [];
      return ref
          .read(helixRepositoryProvider)
          .getFollowedChannels(userId: auth!.userId!, first: 200);
    });

/// Channels the user follows that are not currently live.
List<FollowedChannel> offlineFollowed(
  List<FollowedChannel> all,
  Set<String> liveUserIds,
) {
  return all.where((c) => !liveUserIds.contains(c.id)).toList();
}
