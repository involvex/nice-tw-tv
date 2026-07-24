import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';

class ChannelProfileArgs {
  const ChannelProfileArgs({this.login, this.userId})
    : assert(login != null || userId != null);

  final String? login;
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is ChannelProfileArgs &&
      other.login == login &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(login, userId);
}

class ChannelProfileData {
  const ChannelProfileData({
    required this.user,
    required this.channel,
    required this.live,
    required this.vods,
  });

  final TwitchUserProfile user;
  final TwitchChannelInfo? channel;
  final TwitchStream? live;
  final List<TwitchVod> vods;
}

final channelProfileProvider =
    FutureProvider.family<ChannelProfileData, ChannelProfileArgs>((
      ref,
      args,
    ) async {
      final helix = ref.watch(helixRepositoryProvider);
      final user = await helix.getUserProfile(
        login: args.login,
        id: args.userId,
      );
      if (user == null) {
        throw StateError('Channel not found');
      }
      final channel = await helix.getChannelInfo(user.id);
      final livePage = await helix.getStreamsByUser(userId: user.id);
      final vods = await helix.getVideos(userId: user.id, first: 12);
      return ChannelProfileData(
        user: user,
        channel: channel,
        live: livePage.streams.isEmpty ? null : livePage.streams.first,
        vods: vods.vods,
      );
    });

class ChannelProfileScreen extends ConsumerWidget {
  const ChannelProfileScreen({super.key, this.login, this.userId});

  final String? login;
  final String? userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = ChannelProfileArgs(login: login, userId: userId);
    final async = ref.watch(channelProfileProvider(args));
    final theme = Theme.of(context);

    return Scaffold(
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => ref.invalidate(channelProfileProvider(args)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (data) {
          final user = data.user;
          return CustomScrollView(
            slivers: [
              SoftAppBar(title: user.displayName),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundImage: user.profileImageUrl.isEmpty
                                ? null
                                : CachedNetworkImageProvider(
                                    user.profileImageUrl,
                                  ),
                            child: user.profileImageUrl.isEmpty
                                ? Text(
                                    user.displayName.isEmpty
                                        ? '?'
                                        : user.displayName[0],
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  user.displayName,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                Text(
                                  '@${user.login}',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    IconButton.filledTonal(
                                      tooltip: 'Notifications',
                                      onPressed: () =>
                                          context.push('/notifications'),
                                      icon: const Icon(
                                        Icons.notifications_outlined,
                                      ),
                                    ),
                                    if (data.live != null) ...[
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: () {
                                          final uri = Uri(
                                            path: '/watch/${user.login}',
                                            queryParameters: {
                                              'title': data.live!.title,
                                              'userId': user.id,
                                            },
                                          );
                                          context.push(uri.toString());
                                        },
                                        child: const Text('Watch live'),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (data.channel != null) ...[
                        Text(
                          data.channel!.title,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          data.channel!.gameName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (user.description.isNotEmpty)
                        Text(
                          user.description,
                          style: theme.textTheme.bodyMedium,
                        ),
                      const SizedBox(height: 24),
                      Text('Recent VODs', style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
              ),
              if (data.vods.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No recent videos.'),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: data.vods.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final vod = data.vods[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: vod.sizedThumbnail(
                              width: 120,
                              height: 68,
                            ),
                            width: 96,
                            height: 54,
                            fit: BoxFit.cover,
                          ),
                        ),
                        title: Text(
                          vod.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(vod.duration),
                        onTap: () {
                          final uri = Uri(
                            path: '/vod/${vod.id}',
                            queryParameters: {
                              'title': vod.title,
                              'login': user.login,
                              'userId': user.id,
                            },
                          );
                          context.push(uri.toString());
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class SoftAppBar extends StatelessWidget {
  const SoftAppBar({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(pinned: true, title: Text(title));
  }
}
