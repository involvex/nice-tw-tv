import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/core/storage/app_storage.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/profile/data/follow_controller.dart';
import 'package:nice_tv/features/profile/data/twitch_gql_client.dart';

class MockAuthRepository extends AuthRepository {
  MockAuthRepository() : super(dio: Dio(), tokenStorage: TokenStorage());

  AuthSession mockSession = AuthSession.anonymous;
  String? mockUserToken;
  bool tokenAlive = false;

  @override
  AuthSession get session => mockSession;

  @override
  Future<void> logout() async {
    // No-op — AuthController.logout() sets the provider state directly.
  }

  @override
  Future<String> resolveAccessToken() async => 'mock-token';

  @override
  Future<String?> resolveUserToken() async => mockUserToken;

  @override
  Future<bool> isTokenValid(String token) async => tokenAlive;
}

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
  DioException? throwOnFollow;

  @override
  Future<void> followUser({required String targetId}) async {
    if (shouldThrow) throw Exception('follow failed');
    if (throwOnFollow != null) throw throwOnFollow!;
    calls.add('follow');
  }

  @override
  Future<void> unfollowUser({required String targetId}) async {
    if (shouldThrow) throw Exception('unfollow failed');
    if (throwOnFollow != null) throw throwOnFollow!;
    calls.add('unfollow');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const broadcasterId = 'broadcaster-123';
  late AuthSession session;
  late FakeTwitchGqlClient gql;
  late bool isFollowed;
  late MockAuthRepository mockAuth;

  setUp(() {
    session = AuthSession(
      isLoggedIn: true,
      accessToken: 'token-1',
      login: 'user1',
      userId: 'user-1',
    );
    gql = FakeTwitchGqlClient();
    isFollowed = false;
    mockAuth = MockAuthRepository();
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

    mockAuth
      ..mockSession = session
      ..mockUserToken = session.accessToken
      ..tokenAlive = false;
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWithBuild(
          (ref, notifier) async => session,
        ),
        authRepositoryProvider.overrideWithValue(mockAuth),
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

  test(
    'toggle needs sign-in without GQL call when stored token missing',
    () async {
      isFollowed = false;
      final container = buildContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        followControllerProvider(broadcasterId),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(followControllerProvider(broadcasterId).future);

      // Controller still reports logged in, but storage lost the token —
      // must NOT hit GQL (which would 401 on an app-token fallback) and
      // must NOT log out.
      mockAuth.mockUserToken = null;
      await expectLater(
        container
            .read(followControllerProvider(broadcasterId).notifier)
            .toggle(),
        throwsA(isA<SignInRequiredException>()),
      );
      expect(gql.calls, isEmpty);
      final auth = container.read(authControllerProvider);
      expect(auth.value?.isLoggedIn, isTrue);
    },
  );

  test(
    'toggle keeps session on 401 when stored token still validates',
    () async {
      isFollowed = false;
      gql.throwOnFollow = DioException(
        requestOptions: RequestOptions(),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(),
          statusCode: 401,
          data: {
            'errors': [
              {'message': 'Unauthorized'},
            ],
          },
        ),
        type: DioExceptionType.badResponse,
      );
      final container = buildContainer();
      addTearDown(container.dispose);
      final sub = container.listen(
        followControllerProvider(broadcasterId),
        (_, _) {},
      );
      addTearDown(sub.close);

      await container.read(followControllerProvider(broadcasterId).future);

      // Token re-validates fine — the 401 is about something else, so the
      // failure must surface as a follow error, never a forced logout.
      mockAuth.tokenAlive = true;
      await expectLater(
        container
            .read(followControllerProvider(broadcasterId).notifier)
            .toggle(),
        throwsA(isA<DioException>()),
      );
      final auth = container.read(authControllerProvider);
      expect(auth.value?.isLoggedIn, isTrue);
    },
  );

  test('toggle logs out on 401 from GQL API', () async {
    isFollowed = false;
    gql.throwOnFollow = DioException(
      requestOptions: RequestOptions(),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(),
        statusCode: 401,
        data: {
          'errors': [
            {'message': 'Unauthorized'},
          ],
        },
      ),
      type: DioExceptionType.badResponse,
    );
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
      throwsA(isA<SignInRequiredException>()),
    );

    // The auth state should be anonymous (logged out) after the 401.
    final auth = container.read(authControllerProvider);
    expect(auth.value?.isLoggedIn, isFalse);
  });

  test('toggle does NOT log out on GraphQL error (HTTP 200)', () async {
    isFollowed = false;
    gql.throwOnFollow = DioException(
      requestOptions: RequestOptions(),
      response: Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(),
        statusCode: 200,
        data: {
          'errors': [
            {'message': 'Unauthorized: invalid OAuth token'},
          ],
        },
      ),
      type: DioExceptionType.badResponse,
      message: 'Twitch GraphQL error: Unauthorized: invalid OAuth token',
    );
    final container = buildContainer();
    addTearDown(container.dispose);
    final sub = container.listen(
      followControllerProvider(broadcasterId),
      (_, _) {},
    );
    addTearDown(sub.close);

    await container.read(followControllerProvider(broadcasterId).future);

    // GraphQL-body failures must surface as follow errors — never as a
    // forced logout (that caused the login -> follow -> login loop).
    await expectLater(
      container.read(followControllerProvider(broadcasterId).notifier).toggle(),
      throwsA(isA<DioException>()),
    );

    final auth = container.read(authControllerProvider);
    expect(auth.value?.isLoggedIn, isTrue);
  });

  test("toggle throws on empty broadcasterId", () async {
    final container = buildContainer();
    addTearDown(container.dispose);
    // The fake provider is keyed by broadcasterId; pass an empty one.
    final sub = container.listen(followControllerProvider(''), (_, _) {});
    addTearDown(sub.close);

    await expectLater(
      container.read(followControllerProvider('').notifier).toggle(),
      throwsA(isA<StateError>()),
    );
  });
}
