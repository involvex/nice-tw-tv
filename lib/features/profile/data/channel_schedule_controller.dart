import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';

final channelScheduleProvider =
    FutureProvider.family<List<ChannelScheduleSegment>, String>((
      ref,
      id,
    ) async {
      if (id.isEmpty) return const [];
      final schedule = await ref
          .read(helixRepositoryProvider)
          .getChannelSchedule(id, first: 12);
      final now = DateTime.now();
      final upcoming =
          schedule.segments.where((s) => s.startTime.isAfter(now)).toList()
            ..sort((a, b) => a.startTime.compareTo(b.startTime));
      return upcoming.take(6).toList();
    });
