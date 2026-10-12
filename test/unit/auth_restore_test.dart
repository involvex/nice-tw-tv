import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/core/storage/app_storage.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';

class _MemoryTokenStorage extends TokenStorage {
  String? token;
  String? login;
  String? userId;
  var cleared = false;

  @override
  Future<String?> readUserToken() async => token;

  @override
  Future<String?> readLogin() async => login;

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<void> writeUserSession({
    required String token,
    required String login,
    required String userId,
  }) async {
    this.token = token;
    this.login = login;
    this.userId = userId;
  }

  @override
  Future<void> clearUserSession() async {
    cleared = true;
    token = null;
    login = null;
    userId = null;
  }
}

Dio _dioWith(Future<ResponseBody> Function(RequestOptions) handler) {
  final dio = Dio();
  dio.httpClientAdapter = _FakeAdapter(handler);
  return dio;
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

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

ResponseBody _json(Object? data, int status) {
  return ResponseBody.fromString(
    jsonEncode(data),
    status,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

class _DroppingTokenStorage extends TokenStorage {
  @override
  Future<String?> readUserToken() async => null;

  @override
  Future<void> writeUserSession({
    required String token,
    required String login,
    required String userId,
  }) async {
    // Simulates a device where secure-storage writes silently fail.
  }
}

void main() {
  test('completeLogin throws when session cannot be persisted', () async {
    final repo = AuthRepository(
      dio: _dioWith(
        (_) async => _json({'login': 'someuser', 'user_id': '123'}, 200),
      ),
      tokenStorage: _DroppingTokenStorage(),
    );

    await expectLater(repo.completeLogin('tok'), throwsA(isA<StateError>()));
  });

  test('restore is anonymous when no token stored', () async {
    final storage = _MemoryTokenStorage();
    final repo = AuthRepository(
      dio: _dioWith((_) async {
        throw StateError('should not hit network');
      }),
      tokenStorage: storage,
    );

    final session = await repo.restore();
    expect(session.isLoggedIn, isFalse);
  });

  test('restore validates and returns logged-in session', () async {
    final storage = _MemoryTokenStorage()..token = 'tok';
    final repo = AuthRepository(
      dio: _dioWith(
        (_) async => _json({'login': 'someuser', 'user_id': '123'}, 200),
      ),
      tokenStorage: storage,
    );

    final session = await repo.restore();
    expect(session.isLoggedIn, isTrue);
    expect(session.login, 'someuser');
    expect(session.userId, '123');
  });

  test('restore clears session on 401 (dead token)', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'dead'
      ..login = 'someuser'
      ..userId = '123';
    final repo = AuthRepository(
      dio: _dioWith((_) async => _json({'message': 'invalid token'}, 401)),
      tokenStorage: storage,
    );

    final session = await repo.restore();
    expect(session.isLoggedIn, isFalse);
    expect(storage.cleared, isTrue);
  });

  test('restore keeps session on transient network error', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok'
      ..login = 'someuser'
      ..userId = '123';
    final repo = AuthRepository(
      dio: _dioWith((options) async {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionTimeout,
        );
      }),
      tokenStorage: storage,
    );

    final session = await repo.restore();
    expect(session.isLoggedIn, isTrue);
    expect(session.accessToken, 'tok');
    expect(session.login, 'someuser');
    expect(session.userId, '123');
    expect(storage.cleared, isFalse);
  });
}
