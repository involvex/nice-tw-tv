import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_clip.dart';

final channelClipsProvider = FutureProvider.family<List<TwitchClip>, String>((
  ref,
  id,
) async {
  if (id.isEmpty) return const [];
  final page = await ref
      .read(helixRepositoryProvider)
      .getClips(broadcasterId: id, first: 12);
  return page.clips;
});

class ChannelClipsShelf extends ConsumerWidget {
  const ChannelClipsShelf({super.key, required this.broadcasterId});

  final String broadcasterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncClips = ref.watch(channelClipsProvider(broadcasterId));
    final theme = Theme.of(context);

    return asyncClips.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (clips) {
        if (clips.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Top clips', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 176,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: clips.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final clip = clips[index];
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
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
                                imageUrl: clip.sizedThumbnail(
                                  width: 220,
                                  height: 124,
                                ),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            clip.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${_formatViews(clip.viewCount)} views',
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

  static String _formatViews(int count) {
    if (count >= 1000) {
      final value = count / 1000;
      return value.toStringAsFixed(value >= 10 ? 0 : 1);
    }
    return '$count';
  }
}
