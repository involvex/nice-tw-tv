import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/channel_panels.dart';

final channelPanelsProvider = FutureProvider.family<ChannelPanels, String>((
  ref,
  broadcasterId,
) async {
  return ref.watch(helixRepositoryProvider).getChannelPanels(broadcasterId);
});

class ChannelPanelsSection extends ConsumerWidget {
  const ChannelPanelsSection({super.key, required this.broadcasterId});

  final String broadcasterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panelsAsync = ref.watch(channelPanelsProvider(broadcasterId));
    final theme = Theme.of(context);

    return panelsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, e) => const SizedBox.shrink(),
      data: (panelsData) {
        if (panelsData.panels.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text('About & Panels', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: panelsData.panels.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final panel = panelsData.panels[index];
                  return Container(
                    width: 180,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (panel.imageUrl.isNotEmpty)
                          Expanded(
                            child: CachedNetworkImage(
                              imageUrl: panel.imageUrl,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) =>
                                  const Center(
                                    child: Icon(Icons.broken_image, size: 24),
                                  ),
                            ),
                          )
                        else
                          const Expanded(
                            child: Center(
                              child: Icon(Icons.info_outline, size: 24),
                            ),
                          ),
                        if (panel.title.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              panel.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
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
