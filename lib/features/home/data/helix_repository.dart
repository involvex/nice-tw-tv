import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/badge_catalog.dart';
import 'package:nice_tv/features/home/data/twitch_clip.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/profile/data/channel_panels.dart';
import 'package:nice_tv/features/profile/data/channel_schedule.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:nice_tv/features/vod/data/twitch_vod.dart';

final helixDioProvider = Provider<Dio>((ref) {
  final base = ref.watch(dioProvider);
  final auth = ref.watch(authRepositoryProvider);
  final dio = Dio(base.options.copyWith(baseUrl: 'https://api.twitch.tv'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await auth.resolveAccessToken();
        options.headers['Client-ID'] = AppEnv.clientId;
        options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
    ),
  );
  return dio;
});

class HelixRepository {
  HelixRepository(this._dio);

  final Dio _dio;

  Future<StreamsPage> getTopStreams({
    String? cursor,
    int first = 20,
    String? language,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
        if (language != null && language.isNotEmpty) 'language': language,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return _parseStreamsPage(response.data!);
  }

  Future<StreamsPage> getFollowedStreams({
    required String userId,
    String? cursor,
    int first = 20,
    String? language,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams/followed',
      queryParameters: {
        'user_id': userId,
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
        if (language != null && language.isNotEmpty) 'language': language,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return _parseStreamsPage(response.data!);
  }

  Future<StreamsPage> searchLiveChannels(String query) async {
    if (query.trim().isEmpty) return const StreamsPage(streams: []);
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/search/channels',
      queryParameters: {'query': query.trim(), 'first': 20, 'live_only': true},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    final streams = data.map((raw) {
      final json = raw as Map<String, dynamic>;
      return TwitchStream(
        id: json['id'] as String? ?? '',
        userId: json['id'] as String? ?? '',
        userLogin: json['broadcaster_login'] as String? ?? '',
        userName: json['display_name'] as String? ?? '',
        gameName: json['game_name'] as String? ?? '',
        gameId: json['game_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        viewerCount: 0,
        thumbnailUrl: json['thumbnail_url'] as String? ?? '',
        startedAt: DateTime.now(),
        isMature: json['is_mature'] as bool? ?? false,
        language: json['broadcaster_language'] as String? ?? 'en',
      );
    }).toList();
    return StreamsPage(streams: streams);
  }

  Future<List<TwitchCategory>> searchCategories(String query) async {
    if (query.trim().isEmpty) return const [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/search/categories',
      queryParameters: {'query': query.trim(), 'first': 20},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TwitchCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TwitchCategory>> getTopGames({int first = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/games/top',
      queryParameters: {'first': first},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TwitchCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<StreamsPage> getStreamsByGame({
    required String gameId,
    String? cursor,
    int first = 20,
    String? language,
    String? type,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {
        'game_id': gameId,
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
        if (language != null && language.isNotEmpty) 'language': language,
        if (type != null && type.isNotEmpty) 'type': type,
      },
    );
    return _parseStreamsPage(response.data!);
  }

  Future<StreamsPage> getStreamsByUser({
    required String userId,
    int first = 1,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {'user_id': userId, 'first': first},
    );
    return _parseStreamsPage(response.data!);
  }

  Future<TwitchUserProfile?> getUserProfile({String? login, String? id}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/users',
      queryParameters: {'login': ?login, 'id': ?id},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    if (data.isEmpty) return null;
    return TwitchUserProfile.fromJson(data.first as Map<String, dynamic>);
  }

  Future<TwitchChannelInfo?> getChannelInfo(String broadcasterId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/channels',
      queryParameters: {'broadcaster_id': broadcasterId},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    if (data.isEmpty) return null;
    return TwitchChannelInfo.fromJson(data.first as Map<String, dynamic>);
  }

  Future<List<TwitchChannelInfo>> getChannelsByIds(
    List<String> broadcasterIds,
  ) async {
    if (broadcasterIds.isEmpty) return const [];
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/channels',
      queryParameters: {for (final id in broadcasterIds) 'broadcaster_id': id},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data
        .map((e) => TwitchChannelInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TwitchCategory>> getGamesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final valid = ids.where((id) => id.isNotEmpty).toList();
    if (valid.isEmpty) return const [];
    final batches = <List<String>>[];
    for (var i = 0; i < valid.length; i += 50) {
      batches.add(valid.sublist(i, (i + 50).clamp(0, valid.length)));
    }
    final results = <TwitchCategory>[];
    for (final batch in batches) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/helix/games',
        queryParameters: {'id': batch},
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      results.addAll(
        data.map((e) => TwitchCategory.fromJson(e as Map<String, dynamic>)),
      );
    }
    return results;
  }

  Future<List<TwitchCategory>> getFollowedCategories(String userId) async {
    final followed = await getFollowedChannels(userId: userId, first: 100);
    if (followed.isEmpty) return const [];
    final broadcasterIds = followed.map((c) => c.id).toList();
    final channels = await getChannelsByIds(broadcasterIds);
    final gameIds = <String>{};
    for (final ch in channels) {
      if (ch.gameId.isNotEmpty) gameIds.add(ch.gameId);
    }
    if (gameIds.isEmpty) return const [];
    return getGamesByIds(gameIds.toList());
  }

  Future<List<({String id, String login, String displayName})>>
  getFollowedChannels({required String userId, int first = 100}) async {
    final users = <({String id, String login, String displayName})>[];
    String? cursor;
    while (users.length < first) {
      final response = await _dio.get<Map<String, dynamic>>(
        '/helix/channels/followed',
        queryParameters: {
          'user_id': userId,
          'first': (first - users.length).clamp(1, 100),
          'after': ?cursor,
        },
      );
      final data = response.data?['data'] as List<dynamic>? ?? [];
      for (final raw in data) {
        final json = raw as Map<String, dynamic>;
        users.add((
          id: json['broadcaster_id'] as String? ?? '',
          login: json['broadcaster_login'] as String? ?? '',
          displayName: json['broadcaster_name'] as String? ?? '',
        ));
      }
      final pagination = response.data?['pagination'] as Map<String, dynamic>?;
      cursor = pagination?['cursor'] as String?;
      if (cursor == null || data.isEmpty) break;
    }
    return users.where((u) => u.id.isNotEmpty).toList();
  }

  Future<bool> isFollowingChannel({
    required String userId,
    required String broadcasterId,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/channels/followed',
      queryParameters: {'user_id': userId, 'broadcaster_id': broadcasterId},
    );
    final data = response.data?['data'] as List<dynamic>? ?? [];
    return data.isNotEmpty;
  }

  Future<StreamsPage> getSimilarStreams({
    required String gameId,
    required String excludeUserId,
    int first = 10,
  }) async {
    if (gameId.isEmpty) return const StreamsPage(streams: []);
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {'game_id': gameId, 'first': first + 5},
    );
    final page = _parseStreamsPage(response.data!);
    final filtered = page.streams
        .where((s) => s.userId != excludeUserId)
        .take(first)
        .toList();
    return StreamsPage(streams: filtered, cursor: page.cursor);
  }

  Future<void> createEventSubSubscription({
    required String type,
    required String version,
    required Map<String, String> condition,
    required String sessionId,
  }) async {
    await _dio.post<Map<String, dynamic>>(
      '/helix/eventsub/subscriptions',
      data: {
        'type': type,
        'version': version,
        'condition': condition,
        'transport': {'method': 'websocket', 'session_id': sessionId},
      },
    );
  }

  Future<BadgeCatalog> getGlobalChatBadges() async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/chat/badges/global',
    );
    return _parseBadgeCatalog(response.data!);
  }

  Future<BadgeCatalog> getChannelChatBadges(String broadcasterId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/chat/badges',
      queryParameters: {'broadcaster_id': broadcasterId},
    );
    return _parseBadgeCatalog(response.data!);
  }

  BadgeCatalog _parseBadgeCatalog(Map<String, dynamic> body) {
    final data = body['data'] as List<dynamic>? ?? [];
    final byKey = <String, TwitchBadge>{};
    for (final raw in data) {
      final set = raw as Map<String, dynamic>;
      final setId = set['set_id'] as String? ?? '';
      final versions = set['versions'] as List<dynamic>? ?? [];
      for (final versionRaw in versions) {
        final version = versionRaw as Map<String, dynamic>;
        final id = version['id'] as String? ?? '';
        final url =
            version['image_url_2x'] as String? ??
            version['image_url_1x'] as String? ??
            '';
        if (setId.isEmpty || id.isEmpty || url.isEmpty) continue;
        final badge = TwitchBadge(
          setId: setId,
          version: id,
          imageUrl: url,
          title: version['title'] as String?,
        );
        byKey[badge.key] = badge;
      }
    }
    return BadgeCatalog(byKey: byKey);
  }

  Future<VodsPage> getVideos({
    String? userId,
    String? cursor,
    int first = 20,
    String type = 'archive',
    String sort = 'time',
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/videos',
      queryParameters: {
        'user_id': ?userId,
        'first': first,
        'type': type,
        'sort': sort,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
      },
    );
    return _parseVodsPage(response.data!);
  }

  Future<VodsPage> getTopArchiveVideos({String? cursor, int first = 20}) async {
    // Helix requires user_id/game_id/id — use followed live channels' recent
    // VODs is not available anonymously. Fall back to language-filtered search
    // via games top + videos is heavy; instead fetch videos for currently
    // popular live streamers as a pragmatic "recent VODs" shelf.
    final live = await getTopStreams(first: 8);
    if (live.streams.isEmpty) return const VodsPage(vods: []);
    final pages = <VodsPage>[];
    for (final stream in live.streams) {
      try {
        pages.add(await getVideos(userId: stream.userId, first: 3));
      } on Object {
        pages.add(const VodsPage(vods: []));
      }
    }
    final vods = <TwitchVod>[];
    final seen = <String>{};
    for (final page in pages) {
      for (final vod in page.vods) {
        if (seen.add(vod.id)) vods.add(vod);
      }
    }
    vods.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return VodsPage(vods: vods);
  }

  Future<ClipsPage> getClips({
    String? gameId,
    String? broadcasterId,
    String? cursor,
    int first = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/clips',
      queryParameters: {
        'first': first,
        'game_id': ?gameId,
        'broadcaster_id': ?broadcasterId,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
      },
    );
    return _parseClipsPage(response.data!);
  }

  Future<ChannelPanels> getChannelPanels(String broadcasterId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/helix/channels/panels',
        queryParameters: {'broadcaster_id': broadcasterId},
      );
      return ChannelPanels.fromJson(response.data!);
    } on Object {
      return const ChannelPanels(panels: []);
    }
  }

  Future<ChannelSchedule> getChannelSchedule(
    String broadcasterId, {
    int first = 12,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/schedule',
      queryParameters: {'broadcaster_id': broadcasterId, 'first': first},
    );
    return ChannelSchedule.fromJson(response.data!);
  }

  /// Popular clips across top categories when no game filter is selected.
  Future<ClipsPage> getPopularClips({int first = 40}) async {
    final games = await getTopGames(first: 6);
    final pages = <ClipsPage>[];
    for (final game in games) {
      try {
        pages.add(await getClips(gameId: game.id, first: 8));
      } on Object {
        pages.add(const ClipsPage(clips: []));
      }
    }
    final clips = <TwitchClip>[];
    final seen = <String>{};
    for (final page in pages) {
      for (final clip in page.clips) {
        if (seen.add(clip.id)) clips.add(clip);
      }
    }
    clips.sort((a, b) => b.viewCount.compareTo(a.viewCount));
    return ClipsPage(clips: clips.take(first).toList());
  }

  ClipsPage _parseClipsPage(Map<String, dynamic> body) {
    final data = body['data'] as List<dynamic>? ?? [];
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final cursor = pagination?['cursor'] as String?;
    final clips = data
        .map((e) => TwitchClip.fromJson(e as Map<String, dynamic>))
        .toList();
    return ClipsPage(clips: clips, cursor: cursor);
  }

  VodsPage _parseVodsPage(Map<String, dynamic> body) {
    final data = body['data'] as List<dynamic>? ?? [];
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final cursor = pagination?['cursor'] as String?;
    final vods = data
        .map((e) => TwitchVod.fromJson(e as Map<String, dynamic>))
        .toList();
    return VodsPage(vods: vods, cursor: cursor);
  }

  StreamsPage _parseStreamsPage(Map<String, dynamic> body) {
    final data = body['data'] as List<dynamic>? ?? [];
    final pagination = body['pagination'] as Map<String, dynamic>?;
    final cursor = pagination?['cursor'] as String?;
    final streams = data
        .map((e) => TwitchStream.fromJson(e as Map<String, dynamic>))
        .toList();
    return StreamsPage(streams: streams, cursor: cursor);
  }

  static List<TwitchStream> applyDiscoveryFilters({
    required List<TwitchStream> streams,
    String? language,
    bool hideMature = false,
    String sortOrder = 'viewerCount',
  }) {
    var result = streams;
    if (hideMature) {
      result = result.where((s) => !s.isMature).toList();
    }
    final lang = language?.trim().toLowerCase();
    if (lang != null && lang.isNotEmpty && lang != 'other') {
      result = result.where((s) => s.language == lang).toList();
    } else if (lang == 'other') {
      final known = <String>{
        'en',
        'de',
        'fr',
        'es',
        'pt',
        'ko',
        'ja',
        'zh',
        'ru',
      };
      result = result.where((s) => !known.contains(s.language)).toList();
    }
    switch (sortOrder) {
      case 'recentlyStarted':
        result = List.from(result)
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
      case 'alphabetical':
        result = List.from(result)
          ..sort(
            (a, b) =>
                a.userName.toLowerCase().compareTo(b.userName.toLowerCase()),
          );
      case 'viewerCount':
      default:
        result = List.from(result)
          ..sort((a, b) => b.viewerCount.compareTo(a.viewerCount));
    }
    return result;
  }
}

final helixRepositoryProvider = Provider<HelixRepository>((ref) {
  return HelixRepository(ref.watch(helixDioProvider));
});

/// Pinned categories that should always appear in the Live/Clips chip row.
const pinnedBrowseCategories = <TwitchCategory>[
  TwitchCategory(id: '509658', name: 'Just Chatting', boxArtUrl: ''),
  TwitchCategory(id: '509670', name: 'IRL', boxArtUrl: ''),
];

final homeCategoryFilterProvider =
    NotifierProvider<HomeCategoryFilterController, TwitchCategory?>(
      HomeCategoryFilterController.new,
    );

class HomeCategoryFilterController extends Notifier<TwitchCategory?> {
  @override
  TwitchCategory? build() => null;

  void select(TwitchCategory? category) => state = category;
}

final browseCategoriesProvider = FutureProvider<List<TwitchCategory>>((
  ref,
) async {
  final top = await ref.watch(helixRepositoryProvider).getTopGames(first: 16);
  final byId = <String, TwitchCategory>{
    for (final c in pinnedBrowseCategories) c.id: c,
    for (final c in top) c.id: c,
  };
  final pinned = [for (final p in pinnedBrowseCategories) byId[p.id]!];
  final rest = top.where(
    (c) => !pinnedBrowseCategories.any((p) => p.id == c.id),
  );
  return [...pinned, ...rest];
});

final followedCategoriesProvider =
    FutureProvider.autoDispose<List<TwitchCategory>>((ref) async {
      final auth = ref.watch(authControllerProvider).value;
      if (auth?.isLoggedIn != true || auth?.userId == null) return const [];
      final categories = await ref
          .read(helixRepositoryProvider)
          .getFollowedCategories(auth!.userId!);
      final byId = <String, TwitchCategory>{};
      for (final c in pinnedBrowseCategories) {
        byId[c.id] = c;
      }
      for (final c in categories) {
        byId[c.id] = c;
      }
      return byId.values.toList();
    });

class StreamFeedState {
  const StreamFeedState({
    this.streams = const [],
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<TwitchStream> streams;
  final String? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  StreamFeedState copyWith({
    List<TwitchStream>? streams,
    String? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return StreamFeedState(
      streams: streams ?? this.streams,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class PopularFeedController extends Notifier<StreamFeedState> {
  @override
  StreamFeedState build() {
    ref.listen(homeCategoryFilterProvider, (_, _) {
      // ignore: discarded_futures
      refresh();
    });
    ref.listen(settingsControllerProvider, (_, _) {
      // ignore: discarded_futures
      refresh();
    });
    Future.microtask(refresh);
    return const StreamFeedState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final category = ref.read(homeCategoryFilterProvider);
      final settings = ref.read(settingsControllerProvider);
      final page = category == null
          ? await ref
                .read(helixRepositoryProvider)
                .getTopStreams(
                  language: settings.discoveryLanguage,
                  type: 'live',
                )
          : await ref
                .read(helixRepositoryProvider)
                .getStreamsByGame(
                  gameId: category.id,
                  language: settings.discoveryLanguage,
                  type: 'live',
                );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      state = state.copyWith(
        streams: filtered,
        cursor: page.cursor,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || state.cursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final category = ref.read(homeCategoryFilterProvider);
      final settings = ref.read(settingsControllerProvider);
      final page = category == null
          ? await ref
                .read(helixRepositoryProvider)
                .getTopStreams(
                  cursor: state.cursor,
                  language: settings.discoveryLanguage,
                  type: 'live',
                )
          : await ref
                .read(helixRepositoryProvider)
                .getStreamsByGame(
                  gameId: category.id,
                  cursor: state.cursor,
                  language: settings.discoveryLanguage,
                  type: 'live',
                );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      state = state.copyWith(
        streams: [...state.streams, ...filtered],
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final popularFeedControllerProvider =
    NotifierProvider<PopularFeedController, StreamFeedState>(
      PopularFeedController.new,
    );

class FollowingFeedController extends Notifier<StreamFeedState> {
  @override
  StreamFeedState build() {
    ref.listen(settingsControllerProvider, (_, _) {
      // ignore: discarded_futures
      refresh();
    });
    Future.microtask(refresh);
    return const StreamFeedState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final auth = ref.read(authControllerProvider).value;
      if (auth == null || !auth.isLoggedIn || auth.userId == null) {
        state = state.copyWith(streams: const [], isLoading: false);
        return;
      }
      final settings = ref.read(settingsControllerProvider);
      final page = await ref
          .read(helixRepositoryProvider)
          .getFollowedStreams(
            userId: auth.userId!,
            language: settings.discoveryLanguage,
            type: 'live',
          );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      state = state.copyWith(
        streams: filtered,
        cursor: page.cursor,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || state.isLoading || state.cursor == null) return;
    final auth = ref.read(authControllerProvider).value;
    if (auth?.userId == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final settings = ref.read(settingsControllerProvider);
      final page = await ref
          .read(helixRepositoryProvider)
          .getFollowedStreams(
            userId: auth!.userId!,
            cursor: state.cursor,
            language: settings.discoveryLanguage,
            type: 'live',
          );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      state = state.copyWith(
        streams: [...state.streams, ...filtered],
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final followingFeedControllerProvider =
    NotifierProvider<FollowingFeedController, StreamFeedState>(
      FollowingFeedController.new,
    );

class ClipsFeedState {
  const ClipsFeedState({
    this.clips = const [],
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
  });

  final List<TwitchClip> clips;
  final String? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  ClipsFeedState copyWith({
    List<TwitchClip>? clips,
    String? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) {
    return ClipsFeedState(
      clips: clips ?? this.clips,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ClipsFeedController extends Notifier<ClipsFeedState> {
  @override
  ClipsFeedState build() {
    ref.listen(homeCategoryFilterProvider, (_, _) {
      // ignore: discarded_futures
      refresh();
    });
    Future.microtask(refresh);
    return const ClipsFeedState(isLoading: true);
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final category = ref.read(homeCategoryFilterProvider);
      final page = category == null
          ? await ref.read(helixRepositoryProvider).getPopularClips()
          : await ref
                .read(helixRepositoryProvider)
                .getClips(gameId: category.id);
      state = state.copyWith(
        clips: page.clips,
        cursor: page.cursor,
        isLoading: false,
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    final category = ref.read(homeCategoryFilterProvider);
    // Aggregated "All" feed has no Helix cursor.
    if (category == null) return;
    if (state.isLoadingMore || state.isLoading || state.cursor == null) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await ref
          .read(helixRepositoryProvider)
          .getClips(gameId: category.id, cursor: state.cursor);
      state = state.copyWith(
        clips: [...state.clips, ...page.clips],
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }
}

final clipsFeedControllerProvider =
    NotifierProvider<ClipsFeedController, ClipsFeedState>(
      ClipsFeedController.new,
    );
