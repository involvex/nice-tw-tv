import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';

class VodFeedState {
  const VodFeedState({
    this.vods = const [],
    this.isLoading = false,
    this.error,
  });

  final List<TwitchVod> vods;
  final bool isLoading;
  final String? error;

  VodFeedState copyWith({
    List<TwitchVod>? vods,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return VodFeedState(
      vods: vods ?? this.vods,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class VodFeedController extends Notifier<VodFeedState> {
  @override
  VodFeedState build() {
    Future.microtask(refresh);
    return const VodFeedState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ref
          .read(helixRepositoryProvider)
          .getTopArchiveVideos();
      state = state.copyWith(
        vods: page.vods,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

final vodFeedControllerProvider =
    NotifierProvider<VodFeedController, VodFeedState>(VodFeedController.new);

class VodScreen extends ConsumerWidget {
  const VodScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(vodFeedControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.read(vodFeedControllerProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Text(
                'VODs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'Recent archives from popular live channels',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            if (feed.isLoading && feed.vods.isEmpty)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (feed.error != null && feed.vods.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(feed.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(vodFeedControllerProvider.notifier)
                              .refresh(),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList.separated(
                  itemCount: feed.vods.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 14),
                  itemBuilder: (context, index) {
                    final vod = feed.vods[index];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        final uri = Uri(
                          path: '/vod/${vod.id}',
                          queryParameters: {
                            'title': vod.title,
                            'login': vod.userLogin,
                            'userId': vod.userId,
                            'thumbnailUrl': vod.thumbnailUrl,
                          },
                        );
                        context.push(uri.toString());
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CachedNetworkImage(
                                    imageUrl: vod.sizedThumbnail(),
                                    fit: BoxFit.cover,
                                    errorWidget: (_, _, _) => Container(
                                      color: theme
                                          .colorScheme
                                          .surfaceContainerHigh,
                                      child: const Icon(Icons.ondemand_video),
                                    ),
                                  ),
                                  Positioned(
                                    right: 10,
                                    bottom: 10,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          vod.duration,
                                          style: theme.textTheme.labelSmall
                                              ?.copyWith(color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            vod.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '${vod.userName} · ${vod.viewCount} views',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
