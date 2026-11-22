import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';

/// Picks the next older archive after [currentVodId] from a time-sorted list.
TwitchVod? nextArchiveAfter({
  required List<TwitchVod> vods,
  required String currentVodId,
}) {
  if (vods.isEmpty || currentVodId.isEmpty) return null;
  final index = vods.indexWhere((v) => v.id == currentVodId);
  if (index == -1) {
    return vods.where((v) => v.id != currentVodId).firstOrNull;
  }
  if (index + 1 >= vods.length) return null;
  return vods[index + 1];
}

/// Resolves similar live streams for handoff after a channel goes offline.
Future<List<TwitchStream>> resolveSimilarLiveHandoff(
  HelixRepository helix, {
  required String? broadcasterId,
  required String channelLogin,
  String? gameId,
  int first = 8,
}) async {
  var resolvedGameId = gameId ?? '';
  var excludeUserId = broadcasterId ?? '';

  if (resolvedGameId.isEmpty || excludeUserId.isEmpty) {
    final profile = await helix.getUserProfile(
      login: channelLogin.isEmpty ? null : channelLogin,
      id: excludeUserId.isEmpty ? null : excludeUserId,
    );
    if (profile != null) {
      excludeUserId = excludeUserId.isEmpty ? profile.id : excludeUserId;
      if (resolvedGameId.isEmpty) {
        final info = await helix.getChannelInfo(profile.id);
        resolvedGameId = info?.gameId ?? '';
      }
    }
  }

  if (resolvedGameId.isEmpty) return const [];
  final page = await helix.getSimilarStreams(
    gameId: resolvedGameId,
    excludeUserId: excludeUserId,
    first: first,
  );
  return page.streams;
}

/// Resolves the next VOD archive for the same channel after [currentVodId].
Future<TwitchVod?> resolveNextArchiveHandoff(
  HelixRepository helix, {
  required String currentVodId,
  required String? broadcasterId,
  required String channelLogin,
}) async {
  var userId = broadcasterId ?? '';
  if (userId.isEmpty) {
    final profile = await helix.getUserProfile(
      login: channelLogin.isEmpty ? null : channelLogin,
    );
    userId = profile?.id ?? '';
  }
  if (userId.isEmpty) return null;
  final page = await helix.getVideos(userId: userId, first: 20);
  return nextArchiveAfter(vods: page.vods, currentVodId: currentVodId);
}
