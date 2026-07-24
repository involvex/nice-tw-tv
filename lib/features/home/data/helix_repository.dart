import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
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

  Future<StreamsPage> getTopStreams({String? cursor, int first = 20}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
      },
    );
    return _parseStreamsPage(response.data!);
  }

  Future<StreamsPage> getFollowedStreams({
    required String userId,
    String? cursor,
    int first = 20,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams/followed',
      queryParameters: {
        'user_id': userId,
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
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
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/streams',
      queryParameters: {
        'game_id': gameId,
        'first': first,
        if (cursor != null && cursor.isNotEmpty) 'after': cursor,
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

  Future<TwitchUserProfile?> getUserProfile({
    String? login,
    String? id,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/helix/users',
      queryParameters: {
        'login': ?login,
        'id': ?id,
      },
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
}

final helixRepositoryProvider = Provider<HelixRepository>((ref) {
  return HelixRepository(ref.watch(helixDioProvider));
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
      final page = await ref.read(helixRepositoryProvider).getTopStreams();
      state = state.copyWith(
        streams: page.streams,
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
      final page = await ref
          .read(helixRepositoryProvider)
          .getTopStreams(cursor: state.cursor);
      state = state.copyWith(
        streams: [...state.streams, ...page.streams],
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
      final page = await ref
          .read(helixRepositoryProvider)
          .getFollowedStreams(userId: auth.userId!);
      state = state.copyWith(
        streams: page.streams,
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
      final page = await ref
          .read(helixRepositoryProvider)
          .getFollowedStreams(userId: auth!.userId!, cursor: state.cursor);
      state = state.copyWith(
        streams: [...state.streams, ...page.streams],
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
