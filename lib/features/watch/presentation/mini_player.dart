import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';
import 'package:nice_tv/features/watch/data/mini_player_player_provider.dart';
import 'package:nice_tv/features/watch/data/player_overlay_controller.dart';
import 'package:nice_tv/features/watch/presentation/native_hls_player.dart';
import 'package:nice_tv/features/watch/presentation/twitch_embed_player.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  static const _height = 120.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stream = ref.watch(miniPlayerControllerProvider);
    if (stream == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isClip = stream.clipId != null;
    final useNative =
        !isClip &&
        stream.backend == PlayerBackend.nativeHls &&
        !stream.forceEmbedFallback;
    final externalPlayer = useNative
        ? ref.read(miniPlayerMediaKitPlayerProvider)
        : null;

    final title = stream.title ?? stream.channelLogin;

    return GestureDetector(
      onTap: () {
        final params = <String, String>{
          if (stream.title != null && stream.title!.isNotEmpty)
            'title': stream.title!,
          if (stream.broadcasterId != null && stream.broadcasterId!.isNotEmpty)
            'userId': stream.broadcasterId!,
        };
        final query = params.entries
            .map((e) => '${e.key}=${Uri.encodeComponent(e.value)}')
            .join('&');
        if (stream.vodId != null) {
          context.push('/vod/${stream.vodId}?$query');
        } else if (stream.clipId != null) {
          context.push('/clip/${stream.clipId}?$query');
        } else {
          context.push('/watch/${stream.channelLogin}?$query');
        }
      },
      child: Container(
        height: _height,
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1a1a1a) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: useNative
                      ? NativeHlsPlayer(
                          externalPlayer: externalPlayer,
                          channelLogin: stream.vodId == null
                              ? stream.channelLogin
                              : null,
                          vodId: stream.vodId,
                          initialQuality: stream.initialQuality,
                          initialMuted: true,
                          initialVolume: stream.initialVolume,
                          resumePosition: stream.resumePosition,
                          initialPlaybackSpeed: stream.initialPlaybackSpeed,
                        )
                      : TwitchEmbedPlayer(
                          channelLogin: isClip || stream.vodId != null
                              ? null
                              : stream.channelLogin,
                          vodId: stream.vodId,
                          clipId: stream.clipId,
                          initialQuality: stream.initialQuality,
                          initialMuted: true,
                          initialVolume: stream.initialVolume,
                          resumePosition: stream.resumePosition,
                          initialPlaybackSpeed: stream.initialPlaybackSpeed,
                        ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      ref.read(miniPlayerControllerProvider.notifier).close();
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: 'Close',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
