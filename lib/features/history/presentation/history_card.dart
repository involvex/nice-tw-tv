import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';

class HistoryCard extends StatelessWidget {
  const HistoryCard({super.key, required this.entry});

  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        final uri = Uri(
          path: '/watch/${entry.userLogin}',
          queryParameters: {
            if (entry.title != null) 'title': entry.title,
            if (entry.streamId != null) 'userId': entry.streamId,
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
              child: CachedNetworkImage(
                imageUrl: entry.thumbnailUrl,
                fit: BoxFit.cover,
                errorWidget: (context, _, _) => Container(
                  color: theme.colorScheme.surfaceContainerHigh,
                  child: const Icon(Icons.live_tv_outlined),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            entry.title ?? 'Stream',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                entry.userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.gameName != null && entry.gameName!.isNotEmpty) ...[
                Text(
                  ' · ${entry.gameName}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          Text(
            _relative(entry.watchedAt),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
