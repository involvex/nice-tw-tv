import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/offline_followed.dart';

class OfflineChannelsSection extends ConsumerWidget {
  const OfflineChannelsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final asyncAll = ref.watch(offlineFollowedChannelsProvider);
    final feed = ref.watch(followingFeedControllerProvider);
    final liveIds = feed.streams.map((s) => s.userId).toSet();
    final all = asyncAll.value ?? const <FollowedChannel>[];
    final offline = offlineFollowed(all, liveIds);
    if (offline.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Text('More channels you follow', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        for (final channel in offline)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                channel.displayName.isNotEmpty
                    ? channel.displayName[0].toUpperCase()
                    : '?',
              ),
            ),
            title: Text(
              channel.displayName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text('@${channel.login}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/profile/${channel.login}'),
          ),
      ],
    );
  }
}
