import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/vod/data/vod_progress_store.dart';

class ContinueWatchingEntry {
  const ContinueWatchingEntry({
    required this.vodId,
    required this.position,
    required this.duration,
    required this.title,
    required this.userName,
    required this.userLogin,
    required this.thumbnailUrl,
  });

  final String vodId;
  final Duration position;
  final Duration duration;
  final String title;
  final String userName;
  final String userLogin;
  final String thumbnailUrl;
}

final continueWatchingProvider = Provider<List<ContinueWatchingEntry>>((ref) {
  final store = ref.watch(vodProgressStoreProvider);
  final entries = <ContinueWatchingEntry>[];
  for (final e in store.readAll()) {
    if (e.position <= Duration.zero) continue;
    if (e.duration > Duration.zero &&
        e.position >= e.duration - const Duration(seconds: 10)) {
      continue;
    }
    entries.add(
      ContinueWatchingEntry(
        vodId: e.vodId,
        position: e.position,
        duration: e.duration,
        title: e.title,
        userName: e.userName,
        userLogin: e.userLogin,
        thumbnailUrl: e.thumbnailUrl,
      ),
    );
  }
  entries.sort((a, b) => b.position.compareTo(a.position));
  return entries;
});
