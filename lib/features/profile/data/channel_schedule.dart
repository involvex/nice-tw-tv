class ChannelScheduleSegment {
  const ChannelScheduleSegment({
    required this.id,
    required this.startTime,
    required this.endTime,
    required this.title,
    required this.categoryId,
    required this.categoryName,
    required this.isRecurring,
  });

  final String id;
  final DateTime startTime;
  final DateTime endTime;
  final String title;
  final String categoryId;
  final String categoryName;
  final bool isRecurring;
}

class ChannelSchedule {
  const ChannelSchedule({required this.segments});

  final List<ChannelScheduleSegment> segments;

  factory ChannelSchedule.fromJson(Map<String, dynamic> json) {
    final entries = json['data'] as List<dynamic>? ?? const [];
    final segments = <ChannelScheduleSegment>[];
    for (final raw in entries) {
      final entry = raw as Map<String, dynamic>;
      final rawSegments = entry['segments'] as List<dynamic>? ?? const [];
      for (final segRaw in rawSegments) {
        final seg = segRaw as Map<String, dynamic>;
        final category = seg['category'] as Map<String, dynamic>?;
        segments.add(
          ChannelScheduleSegment(
            id: seg['id'] as String? ?? '',
            startTime:
                DateTime.tryParse(seg['start_time'] as String? ?? '') ??
                DateTime.now(),
            endTime:
                DateTime.tryParse(seg['end_time'] as String? ?? '') ??
                DateTime.now(),
            title: seg['title'] as String? ?? '',
            categoryId: category?['id'] as String? ?? '',
            categoryName: category?['name'] as String? ?? '',
            isRecurring: seg['is_recurring'] as bool? ?? false,
          ),
        );
      }
    }
    return ChannelSchedule(segments: segments);
  }
}

/// e.g. `Sun Aug 30 · 6:14 PM` in the device's local time zone.
String formatScheduleTime(DateTime t) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final local = t.toLocal();
  final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final ampm = local.hour < 12 ? 'AM' : 'PM';
  final minute = local.minute.toString().padLeft(2, '0');
  return '${days[local.weekday - 1]} ${months[local.month - 1]} '
      '${local.day} · $hour12:$minute $ampm';
}
