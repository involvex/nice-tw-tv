import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/follow_controller.dart';
import 'package:nice_tv/features/profile/data/twitch_gql_client.dart';

class FakeHttpClientAdapter implements HttpClientAdapter {
  FakeHttpClientAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class FakeTwitchGqlClient implements TwitchGqlClient {
  @override
  final Dio dio = Dio();

  final List<String> calls = [];
  bool shouldThrow = false;

  @override
  Future<void> followUser({
    required String accessToken,
    required String targetId,
  }) async {
    if (shouldThrow) throw Exception('follow failed');
    calls.add('follow');
  }

  @override
  Future<void> unfollowUser({
    required String accessToken,
    required String targetId,
  }) async {
    if (shouldThrow) throw Exception('unfollow failed');
    calls.add('unfollow');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const broadcasterId = 'broadcaster-123';
  late AuthSession session;
  late FakeTwitchGqlClient gql;
  late bool isFollowed;

  setUp(() {
    session = AuthSession(
      isLoggedIn: true,
      accessToken: 'token-1',
      login: 'user1',
      userId: 'user-1',
    );
    gql = FakeTwitchGqlClient();
    isFollowed = false;
  });

  ProviderContainer buildContainer() {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.twitch.tv'));
    dio.httpClientAdapter = FakeHttpClientAdapter((options) async {
      if (options.path == '/helix/channels/followed') {
        final data = isFollowed
            ? [
                {
                  'broadcaster_id': broadcasterId,
                  'broadcaster_login': 'broadcaster',
                  'broadcaster_name': 'Broadcaster',
                },
              ]
            : <Map<String, dynamic>>[];
        return ResponseBody.fromString(
          jsonEncode({'data': data, 'pagination': {}}),
          200,
          headers: {
            Headers.contentTypeHeader: ['application/json'],
          },
        );
      }
      return ResponseBody.fromString(
        jsonEncode({'data': <Map<String, dynamic>>[], 'pagination': {}}),
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });

    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) async => session,
        ),
        helixRepositoryProvider.overrideWithValue(HelixRepository(dio)),
        twitchGqlClientProvider.overrideWithValue(gql),
        followingFeedControllerProvider.overrideWithBuild(
          (ref, notifier) => const StreamFeedState(),
        ),
      ],
    );
  }

  test('build reflects follow state from Helix', () async {
    isFollowed = true;
    final container = buildContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      followControllerProvider(broadcasterId),
      (_, _) {},
    );
    addTearDown(sub.close);

    final state = await container.read(
      followControllerProvider(broadcasterId).future,
    );
    expect(state.isFollowing, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('toggle follows a channel when not following', () async {
    isFollowed = false;
    final container = buildContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      followControllerProvider(broadcasterId),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(followControllerProvider(broadcasterId).future);
    expect(
      container
          .read(followControllerProvider(broadcasterId))
          .value
          ?.isFollowing,
      isFalse,
    );

    await container
        .read(followControllerProvider(broadcasterId).notifier)
        .toggle();

    expect(gql.calls, ['follow']);
    expect(
      container
          .read(followControllerProvider(broadcasterId))
          .value
          ?.isFollowing,
      isTrue,
    );
    expect(
      container.read(followControllerProvider(broadcasterId)).value?.isLoading,
      isFalse,
    );
  });

  test('toggle unfollows a channel when following', () async {
    isFollowed = true;
    final container = buildContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      followControllerProvider(broadcasterId),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(followControllerProvider(broadcasterId).future);
    expect(
      container
          .read(followControllerProvider(broadcasterId))
          .value
          ?.isFollowing,
      isTrue,
    );

    await container
        .read(followControllerProvider(broadcasterId).notifier)
        .toggle();

    expect(gql.calls, ['unfollow']);
    expect(
      container
          .read(followControllerProvider(broadcasterId))
          .value
          ?.isFollowing,
      isFalse,
    );
  });

  test('toggle rethrows errors and reverts state', () async {
    isFollowed = false;
    gql.shouldThrow = true;
    final container = buildContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      followControllerProvider(broadcasterId),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(followControllerProvider(broadcasterId).future);

    await expectLater(
      container.read(followControllerProvider(broadcasterId).notifier).toggle(),
      throwsException,
    );

    final state = container.read(followControllerProvider(broadcasterId)).value;
    expect(state?.isFollowing, isFalse);
    expect(state?.isLoading, isFalse);
  });

  test('toggle requires sign in', () async {
    session = AuthSession.anonymous;
    final container = buildContainer();
    addTearDown(container.dispose);

    await expectLater(
      container.read(followControllerProvider(broadcasterId).notifier).toggle(),
      throwsA(isA<SignInRequiredException>()),
    );
  });
}
