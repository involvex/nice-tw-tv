import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_clip.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/home/presentation/autoplay_feed.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

enum HomeFeedMode { cards, autoplay }

enum HomeBrowseTab { live, clips }

final homeFeedModeProvider =
    NotifierProvider<HomeFeedModeController, HomeFeedMode>(
      HomeFeedModeController.new,
    );

final homeBrowseTabProvider =
    NotifierProvider<HomeBrowseTabController, HomeBrowseTab>(
      HomeBrowseTabController.new,
    );

class HomeFeedModeController extends Notifier<HomeFeedMode> {
  static const _key = 'home_feed_mode';

  @override
  HomeFeedMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final raw = prefs.getString(_key);
    return raw == HomeFeedMode.autoplay.name
        ? HomeFeedMode.autoplay
        : HomeFeedMode.cards;
  }

  Future<void> setMode(HomeFeedMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(_key, mode.name);
    state = mode;
  }

  Future<void> toggle() async {
    await setMode(
      state == HomeFeedMode.cards ? HomeFeedMode.autoplay : HomeFeedMode.cards,
    );
  }
}

class HomeBrowseTabController extends Notifier<HomeBrowseTab> {
  @override
  HomeBrowseTab build() => HomeBrowseTab.live;

  void setTab(HomeBrowseTab tab) => state = tab;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(popularFeedControllerProvider);
    final clips = ref.watch(clipsFeedControllerProvider);
    final mode = ref.watch(homeFeedModeProvider);
    final tab = ref.watch(homeBrowseTabProvider);
    final category = ref.watch(homeCategoryFilterProvider);
    final auth = ref.watch(authControllerProvider).value;
    final unread = ref.watch(
      notificationsInboxProvider.select((s) => s.unreadCount),
    );
    final theme = Theme.of(context);

    if (mode == HomeFeedMode.autoplay && tab == HomeBrowseTab.live) {
      return Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.black45,
          title: const Text('Nice TV'),
          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: const IconThemeData(color: Colors.white),
          actions: [
            IconButton(
              tooltip: 'Card feed',
              onPressed: () => ref.read(homeFeedModeProvider.notifier).toggle(),
              icon: const Icon(Icons.view_agenda_outlined),
            ),
            IconButton(
              tooltip: 'Search',
              onPressed: () => context.push('/search'),
              icon: const Icon(Icons.search),
            ),
          ],
        ),
        body: feed.isLoading && feed.streams.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : AutoplayFeed(
                streams: feed.streams,
                onNearEnd: () =>
                    ref.read(popularFeedControllerProvider.notifier).loadMore(),
              ),
      );
    }

    Future<void> onRefresh() async {
      if (tab == HomeBrowseTab.live) {
        await ref.read(popularFeedControllerProvider.notifier).refresh();
      } else {
        await ref.read(clipsFeedControllerProvider.notifier).refresh();
      }
      ref.invalidate(browseCategoriesProvider);
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              title: Text(
                'Nice TV',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              actions: [
                if (tab == HomeBrowseTab.live)
                  IconButton(
                    tooltip: 'Autoplay feed',
                    onPressed: () =>
                        ref.read(homeFeedModeProvider.notifier).toggle(),
                    icon: const Icon(Icons.swipe_vertical),
                  ),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search),
                ),
                IconButton(
                  tooltip: 'Notifications',
                  onPressed: () => context.push('/notifications'),
                  icon: Badge(
                    isLabelVisible: unread > 0,
                    label: Text(unread > 99 ? '99+' : '$unread'),
                    child: const Icon(Icons.notifications_outlined),
                  ),
                ),
                if (auth?.isLoggedIn == true)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Center(
                      child: Text(
                        auth!.login ?? '',
                        style: theme.textTheme.labelLarge,
                      ),
                    ),
                  )
                else
                  TextButton(
                    onPressed: () => context.push('/login'),
                    child: const Text('Sign in'),
                  ),
              ],
            ),
            const SliverToBoxAdapter(child: _HomeTabBar()),
            const SliverToBoxAdapter(child: _CategoryChips()),
            if (tab == HomeBrowseTab.live) ...[
              if (feed.isLoading && feed.streams.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (feed.error != null && feed.streams.isEmpty)
                SliverFillRemaining(
                  child: _ErrorPane(
                    message: feed.error!,
                    onRetry: () => ref
                        .read(popularFeedControllerProvider.notifier)
                        .refresh(),
                  ),
                )
              else if (feed.streams.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      category == null
                          ? 'No live streams found.'
                          : 'No live streams in ${category.name}.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount:
                        feed.streams.length + (feed.cursor != null ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index >= feed.streams.length) {
                        ref
                            .read(popularFeedControllerProvider.notifier)
                            .loadMore();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return StreamCard(stream: feed.streams[index]);
                    },
                  ),
                ),
            ] else ...[
              if (clips.isLoading && clips.clips.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (clips.error != null && clips.clips.isEmpty)
                SliverFillRemaining(
                  child: _ErrorPane(
                    message: clips.error!,
                    onRetry: () =>
                        ref.read(clipsFeedControllerProvider.notifier).refresh(),
                  ),
                )
              else if (clips.clips.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      category == null
                          ? 'No clips found.'
                          : 'No clips in ${category.name}.',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  sliver: SliverList.separated(
                    itemCount:
                        clips.clips.length +
                        (clips.cursor != null && category != null ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      if (index >= clips.clips.length) {
                        ref
                            .read(clipsFeedControllerProvider.notifier)
                            .loadMore();
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      return ClipCard(clip: clips.clips[index]);
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HomeTabBar extends ConsumerWidget {
  const _HomeTabBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(homeBrowseTabProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: SegmentedButton<HomeBrowseTab>(
        segments: const [
          ButtonSegment(
            value: HomeBrowseTab.live,
            label: Text('Live'),
            icon: Icon(Icons.live_tv_outlined),
          ),
          ButtonSegment(
            value: HomeBrowseTab.clips,
            label: Text('Clips'),
            icon: Icon(Icons.content_cut),
          ),
        ],
        selected: {tab},
        onSelectionChanged: (set) {
          ref.read(homeBrowseTabProvider.notifier).setTab(set.first);
        },
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(browseCategoriesProvider);
    final selected = ref.watch(homeCategoryFilterProvider);

    return categories.when(
      loading: () => const SizedBox(
        height: 52,
        child: Center(child: LinearProgressIndicator()),
      ),
      error: (_, _) => const SizedBox(height: 8),
      data: (list) {
        return SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: selected == null,
                  onSelected: (_) =>
                      ref.read(homeCategoryFilterProvider.notifier).select(null),
                ),
              ),
              for (final category in list)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(category.name),
                    selected: selected?.id == category.id,
                    avatar: category.boxArtUrl.isEmpty
                        ? null
                        : CircleAvatar(
                            backgroundImage: CachedNetworkImageProvider(
                              category.sizedBoxArt(width: 52, height: 72),
                            ),
                          ),
                    onSelected: (_) {
                      final notifier = ref.read(
                        homeCategoryFilterProvider.notifier,
                      );
                      if (selected?.id == category.id) {
                        notifier.select(null);
                      } else {
                        notifier.select(category);
                      }
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

String formatViewers(int count) {
  if (count >= 1000000) {
    return '${(count / 1000000).toStringAsFixed(1)}M';
  }
  if (count >= 1000) {
    return '${(count / 1000).toStringAsFixed(1)}K';
  }
  return '$count';
}

class StreamCard extends StatelessWidget {
  const StreamCard({super.key, required this.stream});

  final TwitchStream stream;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewers = formatViewers(stream.viewerCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final uri = Uri(
              path: '/watch/${stream.userLogin}',
              queryParameters: {'title': stream.title, 'userId': stream.userId},
            );
            context.push(uri.toString());
          },
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: stream.sizedThumbnail(),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _Chip(
                      color: const Color(0xFFE91916),
                      child: Text(
                        'LIVE · $viewers',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          stream.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Flexible(
              child: InkWell(
                onTap: () => context.push(
                  '/profile/${stream.userLogin}?userId=${stream.userId}',
                ),
                child: Text(
                  stream.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            Text(
              ' · ${stream.gameName}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ClipCard extends StatelessWidget {
  const ClipCard({super.key, required this.clip});

  final TwitchClip clip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final views = formatViewers(clip.viewCount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            final uri = Uri(
              path: '/clip/${clip.id}',
              queryParameters: {
                'title': clip.title,
                'login': clip.broadcasterName,
              },
            );
            context.push(uri.toString());
          },
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: clip.sizedThumbnail(),
                    fit: BoxFit.cover,
                    placeholder: (_, _) => Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: theme.colorScheme.surfaceContainerHigh,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: _Chip(
                      color: Colors.black87,
                      child: Text(
                        'CLIP · $views',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    right: 10,
                    bottom: 10,
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white,
                      size: 36,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          clip.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          clip.broadcasterName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.color, required this.child});

  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: child,
      ),
    );
  }
}

class _ErrorPane extends StatelessWidget {
  const _ErrorPane({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
