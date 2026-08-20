import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/home/presentation/offline_channels_section.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final feed = ref.watch(followingFeedControllerProvider);
    final categories = ref.watch(followedCategoriesProvider);
    final theme = Theme.of(context);

    if (auth?.isLoggedIn != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Following')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Sign in to see live channels you follow.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in with Twitch'),
                ),
              ],
            ),
          ),
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
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  if (feed.isLoading && feed.streams.isEmpty)
                    const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (feed.error != null && feed.streams.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(feed.error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => ref
                                .read(followingFeedControllerProvider.notifier)
                                .refresh(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    )
                  else if (feed.streams.isEmpty)
                    SizedBox(
                      height: 200,
                      child: Center(
                        child: Text(
                          'No followed live channels right now.',
                          style: theme.textTheme.bodyLarge,
                        ),
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
              return FilterChip(
                label: Text(category.name),
                selected: false,
                avatar: category.boxArtUrl.isEmpty
                    ? null
                    : CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(
                          category.sizedBoxArt(width: 52, height: 72),
                        ),
                      ),
                onSelected: (_) => context.push(
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
