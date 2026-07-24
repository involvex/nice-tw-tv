import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/home/presentation/autoplay_feed.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

enum HomeFeedMode { cards, autoplay }

final homeFeedModeProvider =
    NotifierProvider<HomeFeedModeController, HomeFeedMode>(
      HomeFeedModeController.new,
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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(popularFeedControllerProvider);
    final mode = ref.watch(homeFeedModeProvider);
    final auth = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);

    if (mode == HomeFeedMode.autoplay) {
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

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(popularFeedControllerProvider.notifier).refresh(),
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
                  icon: const Icon(Icons.notifications_outlined),
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
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Text(
                  'Live feed & popular streams',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
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
                    'No live streams found.',
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
          ],
        ),
      ),
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
