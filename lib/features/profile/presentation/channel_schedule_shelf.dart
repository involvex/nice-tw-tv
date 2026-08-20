import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';
import 'package:nice_tv/features/profile/data/channel_schedule_controller.dart';

class ChannelScheduleShelf extends ConsumerWidget {
  const ChannelScheduleShelf({super.key, required this.broadcasterId});

  final String broadcasterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSegments = ref.watch(channelScheduleProvider(broadcasterId));
    final theme = Theme.of(context);

    return asyncSegments.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (segments) {
        if (segments.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Upcoming schedule', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: segments.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final segment = segments[index];
                  return _ScheduleCard(segment: segment);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.segment});

  final ChannelScheduleSegment segment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 200,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatScheduleTime(segment.startTime),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              segment.title.isEmpty
                  ? (segment.categoryName.isEmpty
                        ? 'Untitled segment'
                        : segment.categoryName)
                  : segment.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
