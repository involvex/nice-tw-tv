import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';

final similarStreamsProvider =
    FutureProvider.family<
      List<TwitchStream>,
      ({String gameId, String excludeUserId})
    >((ref, args) async {
      if (args.gameId.isEmpty) return const [];
      final helix = ref.watch(helixRepositoryProvider);
      final page = await helix.getSimilarStreams(
        gameId: args.gameId,
        excludeUserId: args.excludeUserId,
        first: 10,
      );
      return page.streams;
    });

class SimilarStreamsShelf extends ConsumerWidget {
  const SimilarStreamsShelf({
    super.key,
    required this.gameId,
    required this.excludeUserId,
  });

  final String gameId;
  final String excludeUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (gameId.isEmpty) return const SizedBox.shrink();
    final asyncStreams = ref.watch(
      similarStreamsProvider((gameId: gameId, excludeUserId: excludeUserId)),
    );
    final theme = Theme.of(context);

    return asyncStreams.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (streams) {
        if (streams.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Similar live streams', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: streams.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final stream = streams[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      final uri = Uri(
                        path: '/watch/${stream.userLogin}',
                        queryParameters: {
                          'title': stream.title,
                          'userId': stream.userId,
                        },
                      );
                      context.push(uri.toString());
                    },
                    child: SizedBox(
                      width: 220,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: CachedNetworkImage(
                                imageUrl: stream.sizedThumbnail(
                                  width: 220,
                                  height: 124,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            stream.userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            stream.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
