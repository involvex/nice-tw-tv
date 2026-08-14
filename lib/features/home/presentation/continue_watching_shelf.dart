import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/vod/data/continue_watching_provider.dart';

class ContinueWatchingShelf extends ConsumerWidget {
  const ContinueWatchingShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(continueWatchingProvider);
    if (entries.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Continue Watching',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _ContinueWatchingCard(entry: entry);
            },
          ),
        ),
      ],
    );
  }
}

class _ContinueWatchingCard extends StatelessWidget {
  const _ContinueWatchingCard({required this.entry});

  final ContinueWatchingEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = entry.duration > Duration.zero
        ? (entry.position.inMilliseconds / entry.duration.inMilliseconds).clamp(
            0.0,
            1.0,
          )
        : 0.0;

    return SizedBox(
      width: 260,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          final uri =
              Uri(
                path: '/vod/${entry.vodId}',
                queryParameters: {
                  'title': entry.title,
                  'login': entry.userLogin,
                  'userId': null,
                  'thumbnailUrl': entry.thumbnailUrl,
                },
              ).replace(
                queryParameters: {
                  'title': entry.title,
                  'login': entry.userLogin,
                  'thumbnailUrl': entry.thumbnailUrl,
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
                    if (entry.thumbnailUrl.isNotEmpty)
                      CachedNetworkImage(
                        imageUrl: entry.thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, _) => Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHigh,
                          child: const Icon(Icons.ondemand_video),
                        ),
                      )
                    else
                      Container(
                        color: theme.colorScheme.surfaceContainerHigh,
                        child: const Icon(Icons.ondemand_video),
                      ),
                    Positioned(
                      left: 10,
                      bottom: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: const Color(0xFFE91916),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            _formatDuration(entry.position),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.black45,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              entry.userName,
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
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = d.inHours;
    if (hours > 0) {
      final h = hours.toString();
      return '$h:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}
