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
  List<StoredTwitchAccount> inactive = [];
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

  @override
  Future<StoredTwitchAccount?> readActiveAccount() async {
    if (token == null ||
        token!.isEmpty ||
        login == null ||
        login!.isEmpty ||
        userId == null ||
        userId!.isEmpty) {
      return null;
    }
    return StoredTwitchAccount(token: token!, login: login!, userId: userId!);
  }

  @override
  Future<List<StoredTwitchAccount>> readInactiveAccounts() async =>
      List.of(inactive);

  @override
  Future<void> writeInactiveAccounts(List<StoredTwitchAccount> accounts) async {
    final deduped = <String, StoredTwitchAccount>{};
    for (final account in accounts) {
      if (!account.isValid) continue;
      deduped[account.userId] = account;
    }
    inactive = deduped.values.take(TokenStorage.maxInactiveAccounts).toList();
  }

  @override
  Future<void> parkAccount(StoredTwitchAccount account) async {
    if (!account.isValid) return;
    inactive = [
      account,
      ...inactive.where((a) => a.userId != account.userId),
    ].take(TokenStorage.maxInactiveAccounts).toList();
  }

  @override
  Future<void> removeInactiveAccount(String userId) async {
    inactive = inactive.where((a) => a.userId != userId).toList();
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
  Future<String?> readLogin() async => null;

  @override
  Future<String?> readUserId() async => null;

  @override
  Future<StoredTwitchAccount?> readActiveAccount() async => null;

  @override
  Future<List<StoredTwitchAccount>> readInactiveAccounts() async => const [];

  @override
  Future<void> writeInactiveAccounts(List<StoredTwitchAccount> accounts) async {}

  @override
  Future<void> parkAccount(StoredTwitchAccount account) async {}

  @override
  Future<void> removeInactiveAccount(String userId) async {}

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

  test('completeLogin parks the previous active account', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok-a'
      ..login = 'alice'
      ..userId = '1';
    final repo = AuthRepository(
      dio: _dioWith((options) async {
        final auth = options.headers['Authorization'] as String? ?? '';
        if (auth.contains('tok-b')) {
          return _json({'login': 'bob', 'user_id': '2'}, 200);
        }
        return _json({'login': 'alice', 'user_id': '1'}, 200);
      }),
      tokenStorage: storage,
    );

    final session = await repo.completeLogin('tok-b');
    expect(session.login, 'bob');
    expect(session.userId, '2');
    expect(storage.token, 'tok-b');
    expect(storage.inactive, hasLength(1));
    expect(storage.inactive.single.login, 'alice');
    expect(storage.inactive.single.userId, '1');
  });

  test('switchAccount swaps active and parked sessions', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok-a'
      ..login = 'alice'
      ..userId = '1'
      ..inactive = [
        const StoredTwitchAccount(token: 'tok-b', login: 'bob', userId: '2'),
      ];
    final repo = AuthRepository(
      dio: _dioWith(
        (_) async => _json({'login': 'alice', 'user_id': '1'}, 200),
      ),
      tokenStorage: storage,
    );
    await repo.restore();

    final session = await repo.switchAccount('2');
    expect(session.login, 'bob');
    expect(session.userId, '2');
    expect(storage.token, 'tok-b');
    expect(storage.login, 'bob');
    expect(storage.inactive, hasLength(1));
    expect(storage.inactive.single.login, 'alice');
    expect(storage.inactive.single.userId, '1');
  });

  test('logout clears only the active session', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok-a'
      ..login = 'alice'
      ..userId = '1'
      ..inactive = [
        const StoredTwitchAccount(token: 'tok-b', login: 'bob', userId: '2'),
      ];
    final repo = AuthRepository(
      dio: _dioWith(
        (_) async => _json({'login': 'alice', 'user_id': '1'}, 200),
      ),
      tokenStorage: storage,
    );
    await repo.restore();
    await repo.logout();

    expect(repo.session.isLoggedIn, isFalse);
    expect(storage.token, isNull);
    expect(storage.inactive, hasLength(1));
    expect(storage.inactive.single.login, 'bob');
  });

  test('removeAccount drops a parked login', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok-a'
      ..login = 'alice'
      ..userId = '1'
      ..inactive = [
        const StoredTwitchAccount(token: 'tok-b', login: 'bob', userId: '2'),
      ];
    final repo = AuthRepository(
      dio: _dioWith(
        (_) async => _json({'login': 'alice', 'user_id': '1'}, 200),
      ),
      tokenStorage: storage,
    );
    await repo.restore();
    await repo.removeAccount('2');

    expect(repo.session.isLoggedIn, isTrue);
    expect(repo.session.login, 'alice');
    expect(storage.inactive, isEmpty);
  });

  test('restore keeps parked accounts when active is valid', () async {
    final storage = _MemoryTokenStorage()
      ..token = 'tok-a'
      ..login = 'alice'
      ..userId = '1'
      ..inactive = [
        const StoredTwitchAccount(token: 'tok-b', login: 'bob', userId: '2'),
      ];
    final repo = AuthRepository(
      dio: _dioWith((options) async {
        final auth = options.headers['Authorization'] as String? ?? '';
        if (auth.contains('tok-b')) {
          return _json({'login': 'bob', 'user_id': '2'}, 200);
        }
        return _json({'login': 'alice', 'user_id': '1'}, 200);
      }),
      tokenStorage: storage,
    );

    final session = await repo.restore();
    expect(session.login, 'alice');
    expect(repo.inactiveAccounts, hasLength(1));
    expect(repo.inactiveAccounts.single.login, 'bob');
    expect(repo.allAccounts.map((a) => a.login), ['alice', 'bob']);
  });
}
