import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';

/// Full-bleed overlay shown when live/VOD playback ends with next options.
class PlaybackHandoffOverlay extends StatelessWidget {
  const PlaybackHandoffOverlay({
    super.key,
    required this.title,
    this.similarStreams = const [],
    this.nextVod,
    this.loading = false,
    this.onDismiss,
    this.onOpenStream,
    this.onOpenVod,
  });

  final String title;
  final List<TwitchStream> similarStreams;
  final TwitchVod? nextVod;
  final bool loading;
  final VoidCallback? onDismiss;
  final ValueChanged<TwitchStream>? onOpenStream;
  final ValueChanged<TwitchVod>? onOpenVod;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (loading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (nextVod != null) ...[
                Text(
                  'Next archive',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                _HandoffCard(
                  imageUrl: nextVod!.thumbnailUrl
                      .replaceAll('%{width}', '320')
                      .replaceAll('%{height}', '180'),
                  title: nextVod!.title,
                  subtitle: nextVod!.userName,
                  onTap: () => onOpenVod?.call(nextVod!),
                ),
              ] else if (similarStreams.isNotEmpty) ...[
                Text(
                  'Similar live streams',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.separated(
                    itemCount: similarStreams.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final stream = similarStreams[index];
                      return _HandoffCard(
                        imageUrl: stream.sizedThumbnail(
                          width: 320,
                          height: 180,
                        ),
                        title: stream.userName,
                        subtitle: stream.title,
                        onTap: () => onOpenStream?.call(stream),
                      );
                    },
                  ),
                ),
              ] else
                Expanded(
                  child: Center(
                    child: Text(
                      'Nothing queued to watch next',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HandoffCard extends StatelessWidget {
  const _HandoffCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 140,
              height: 78,
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const ColoredBox(
                  color: Colors.white12,
                  child: Icon(Icons.live_tv, color: Colors.white54),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.play_arrow, color: Colors.white70),
        ],
      ),
    );
  }
}
