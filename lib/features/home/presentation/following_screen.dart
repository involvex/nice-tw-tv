import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider).value;
    final feed = ref.watch(followingFeedControllerProvider);
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
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(followingFeedControllerProvider.notifier).refresh(),
        child: feed.isLoading && feed.streams.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : feed.error != null && feed.streams.isEmpty
            ? ListView(
                children: [
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
                  ),
                ],
              )
            : feed.streams.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No followed live channels right now.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: feed.streams.length + (feed.cursor != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index >= feed.streams.length) {
                    ref
                        .read(followingFeedControllerProvider.notifier)
                        .loadMore();
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return StreamCard(stream: feed.streams[index]);
                },
              ),
      ),
    );
  }
}
