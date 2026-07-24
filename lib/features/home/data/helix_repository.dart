import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';

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

enum HomeFeedTab { live, following }

class HomeFeedState {
  const HomeFeedState({
    this.streams = const [],
    this.cursor,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.tab = HomeFeedTab.live,
  });

  final List<TwitchStream> streams;
  final String? cursor;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final HomeFeedTab tab;

  HomeFeedState copyWith({
    List<TwitchStream>? streams,
    String? cursor,
    bool clearCursor = false,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    HomeFeedTab? tab,
  }) {
    return HomeFeedState(
      streams: streams ?? this.streams,
      cursor: clearCursor ? null : (cursor ?? this.cursor),
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      tab: tab ?? this.tab,
    );
  }
}

class HomeFeedController extends Notifier<HomeFeedState> {
  @override
  HomeFeedState build() {
    Future.microtask(refresh);
    return const HomeFeedState(isLoading: true);
  }

  Future<void> setTab(HomeFeedTab tab) async {
    if (state.tab == tab) return;
    state = state.copyWith(tab: tab, isLoading: true, clearError: true);
    await refresh();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearCursor: true,
    );
    try {
      final page = await _fetchPage();
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
      final page = await _fetchPage(cursor: state.cursor);
      state = state.copyWith(
        streams: [...state.streams, ...page.streams],
        cursor: page.cursor,
        isLoadingMore: false,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoadingMore: false, error: e.toString());
    }
  }

  Future<StreamsPage> _fetchPage({String? cursor}) async {
    final helix = ref.read(helixRepositoryProvider);
    if (state.tab == HomeFeedTab.following) {
      final auth = ref.read(authControllerProvider).value;
      if (auth == null || !auth.isLoggedIn || auth.userId == null) {
        return const StreamsPage(streams: []);
      }
      return helix.getFollowedStreams(userId: auth.userId!, cursor: cursor);
    }
    return helix.getTopStreams(cursor: cursor);
  }
}

final homeFeedControllerProvider =
    NotifierProvider<HomeFeedController, HomeFeedState>(HomeFeedController.new);
