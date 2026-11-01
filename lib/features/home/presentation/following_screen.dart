import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/core/widgets/nice_empty_state.dart';
import 'package:nice_tv/core/widgets/nice_error_pane.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/home/presentation/offline_channels_section.dart';
import 'package:nice_tv/features/watch/data/player_overlay_controller.dart';
import 'package:nice_tv/features/watch/presentation/mini_player.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final feed = ref.watch(followingFeedControllerProvider);
    final categories = ref.watch(followedCategoriesProvider);
    final listBottom = MiniPlayer.contentBottomPadding(
      ref.watch(miniPlayerControllerProvider) != null,
    );

    if (auth?.isLoggedIn != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: NiceEmptyState(
          icon: Icons.favorite_outline,
          title: 'Sign in to see who you follow',
          body: 'Live channels from your Twitch follows show up here.',
          actionLabel: 'Sign in with Twitch',
          onAction: () => context.push('/login'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Following')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FollowedCategoriesStrip(categories: categories),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(followingFeedControllerProvider.notifier)
                    .refresh();
                ref.invalidate(followedCategoriesProvider);
              },
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 8, 16, listBottom),
                children: [
                  if (feed.isLoading && feed.streams.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (feed.error != null && feed.streams.isEmpty)
                    SizedBox(
                      height: 280,
                      child: NiceErrorPane.fromError(
                        error: feed.error!,
                        onRetry: () => ref
                            .read(followingFeedControllerProvider.notifier)
                            .refresh(),
                      ),
                    )
                  else if (feed.streams.isEmpty)
                    const SizedBox(
                      height: 240,
                      child: NiceEmptyState(
                        icon: Icons.live_tv_outlined,
                        title: 'Nobody you follow is live',
                        body:
                            'Offline follows are listed below when available.',
                      ),
                    )
                  else
                    for (final stream in feed.streams)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: StreamCard(stream: stream),
                      ),
                  if (feed.cursor != null) const _LoadMoreProbe(),
                  OfflineChannelsSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreProbe extends ConsumerStatefulWidget {
  const _LoadMoreProbe();

  @override
  ConsumerState<_LoadMoreProbe> createState() => _LoadMoreProbeState();
}

class _LoadMoreProbeState extends ConsumerState<_LoadMoreProbe> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    ref.read(followingFeedControllerProvider.notifier).loadMore();
  }

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _FollowedCategoriesStrip extends StatelessWidget {
  const _FollowedCategoriesStrip({required this.categories});

  final AsyncValue<List<TwitchCategory>> categories;

  @override
  Widget build(BuildContext context) {
    return categories.when(
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, _) => const SizedBox(height: 8),
      data: (list) {
        if (list.isEmpty) return const SizedBox(height: 8);
        return SizedBox(
          height: 52,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            scrollDirection: Axis.horizontal,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = list[index];
              return ActionChip(
                label: Text(category.name),
                avatar: category.boxArtUrl.isEmpty
                    ? null
                    : CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          category.sizedBoxArt(width: 52, height: 72),
                        ),
                      ),
                onPressed: () => context.push(
                  '/category/${category.id}?name=${Uri.encodeComponent(category.name)}',
                ),
              );
            },
          ),
        );
      },
    );
  }
}
