import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/core/storage/app_storage.dart';

class AuthSession {
  const AuthSession({
    required this.isLoggedIn,
    this.accessToken,
    this.login,
    this.userId,
  });

  final bool isLoggedIn;
  final String? accessToken;
  final String? login;
  final String? userId;

  static const anonymous = AuthSession(isLoggedIn: false);
}

class AuthRepository {
  AuthRepository({required this.dio, required this.tokenStorage});

  final Dio dio;
  final TokenStorage tokenStorage;

  String? _appToken;
  DateTime? _appTokenExpiry;
  AuthSession _session = AuthSession.anonymous;
  List<StoredTwitchAccount> _inactiveAccounts = const [];

  AuthSession get session => _session;

  /// Parked accounts (not the active session).
  List<StoredTwitchAccount> get inactiveAccounts =>
      List.unmodifiable(_inactiveAccounts);

  /// Active session plus parked accounts (active first when logged in).
  List<StoredTwitchAccount> get allAccounts {
    final active = _session.isLoggedIn &&
            (_session.accessToken?.isNotEmpty ?? false) &&
            (_session.login?.isNotEmpty ?? false) &&
            (_session.userId?.isNotEmpty ?? false)
        ? StoredTwitchAccount(
            token: _session.accessToken!,
            login: _session.login!,
            userId: _session.userId!,
          )
        : null;
    if (active == null) return List.unmodifiable(_inactiveAccounts);
    return List.unmodifiable([
      active,
      ..._inactiveAccounts.where((a) => a.userId != active.userId),
    ]);
  }

  /// True when another account can be added (active + inactive under cap).
  bool get canAddAccount {
    final count =
        (_session.isLoggedIn ? 1 : 0) + _inactiveAccounts.length;
    return count < TokenStorage.maxInactiveAccounts + 1;
  }

  String buildAuthorizeUrl() {
    final scopes = AppEnv.oauthScopes.join(' ');
    final uri = Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'client_id': AppEnv.clientId,
      'redirect_uri': AppEnv.redirectUri,
      'response_type': 'token',
      'scope': scopes,
    });
    return uri.toString();
  }

  /// Parses `#access_token=...` from the OAuth redirect URL.
  /// Uses a regex first: WebView URLs may carry the token in the fragment
  /// (which `Uri.queryParameters` drops) or alongside an existing query.
  String? extractTokenFromRedirect(String url) {
    final match = RegExp('[#?&]access_token=([^&#]+)').firstMatch(url);
    final token = match?.group(1);
    if (token != null && token.isNotEmpty) return token;
    try {
      final uri = Uri.parse(url.replaceFirst('#', '?'));
      return uri.queryParameters['access_token'];
    } on FormatException {
      return null;
    }
  }

  bool isOAuthRedirect(String url) {
    return url.startsWith(AppEnv.redirectUri) && url.contains('access_token=');
  }

  Future<AuthSession> restore() async {
    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
    await _pruneDeadInactiveAccounts();

    final token = await tokenStorage.readUserToken();
    if (token == null || token.isEmpty) {
      _session = AuthSession.anonymous;
      return _session;
    }
    try {
      final user = await _validateToken(token);
      _session = AuthSession(
        isLoggedIn: true,
        accessToken: token,
        login: user.$1,
        userId: user.$2,
      );
      await tokenStorage.writeUserSession(
        token: token,
        login: user.$1,
        userId: user.$2,
      );
      // Drop this user from inactive if it somehow appears there.
      await tokenStorage.removeInactiveAccount(user.$2);
      _inactiveAccounts = await tokenStorage.readInactiveAccounts();
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        // Token is truly dead — clear only the active session.
        await tokenStorage.clearUserSession();
        _session = AuthSession.anonymous;
      } else {
        // Transient network/server error at startup — keep the stored
        // session instead of logging the user out on every refresh.
        final login = await tokenStorage.readLogin();
        final userId = await tokenStorage.readUserId();
        _session = AuthSession(
          isLoggedIn: true,
          accessToken: token,
          login: (login?.isNotEmpty ?? false) ? login : null,
          userId: (userId?.isNotEmpty ?? false) ? userId : null,
        );
      }
    } on Object {
      await tokenStorage.clearUserSession();
      _session = AuthSession.anonymous;
    }
    return _session;
  }

  /// Completes OAuth. If an account is already active, parks it first.
  Future<AuthSession> completeLogin(String accessToken) async {
    final user = await _validateToken(accessToken);
    final incoming = StoredTwitchAccount(
      token: accessToken,
      login: user.$1,
      userId: user.$2,
    );

    final current = await tokenStorage.readActiveAccount();
    if (current != null && current.userId != incoming.userId) {
      await tokenStorage.parkAccount(current);
    }

    // If re-logging the same or a parked account, pull it out of inactive.
    await tokenStorage.removeInactiveAccount(incoming.userId);

    await tokenStorage.writeUserSession(
      token: incoming.token,
      login: incoming.login,
      userId: incoming.userId,
    );
    // Verify persistence — on some devices secure storage writes can
    // silently fail, which used to leave the UI "logged in" while nothing
    // was stored (logged out again on next launch).
    final persisted = await tokenStorage.readUserToken();
    if (persisted == null || persisted.isEmpty) {
      throw StateError('Could not persist session on this device');
    }
    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
    _session = AuthSession(
      isLoggedIn: true,
      accessToken: accessToken,
      login: user.$1,
      userId: user.$2,
    );
    return _session;
  }

  /// Signs out only the active account. Parked accounts stay.
  Future<void> logout() async {
    await tokenStorage.clearUserSession();
    _session = AuthSession.anonymous;
    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
  }

  /// Makes [userId] the active session (must be in the inactive list).
  Future<AuthSession> switchAccount(String userId) async {
    final inactive = await tokenStorage.readInactiveAccounts();
    final target = inactive.where((a) => a.userId == userId).firstOrNull;
    if (target == null) {
      throw StateError('Account $userId is not saved');
    }

    final current = await tokenStorage.readActiveAccount();
    final nextInactive = <StoredTwitchAccount>[
      if (current != null && current.userId != target.userId) current,
      ...inactive.where((a) => a.userId != target.userId),
    ];
    await tokenStorage.writeInactiveAccounts(nextInactive);
    await tokenStorage.writeUserSession(
      token: target.token,
      login: target.login,
      userId: target.userId,
    );

    final persisted = await tokenStorage.readUserToken();
    if (persisted == null || persisted.isEmpty) {
      throw StateError('Could not persist session on this device');
    }

    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
    _session = AuthSession(
      isLoggedIn: true,
      accessToken: target.token,
      login: target.login,
      userId: target.userId,
    );
    return _session;
  }

  /// Removes a parked account, or signs out when [userId] is active.
  Future<void> removeAccount(String userId) async {
    if (_session.userId == userId) {
      await logout();
      return;
    }
    await tokenStorage.removeInactiveAccount(userId);
    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
  }

  Future<List<StoredTwitchAccount>> listAccounts() async {
    _inactiveAccounts = await tokenStorage.readInactiveAccounts();
    return allAccounts;
  }

  /// Prefer user token; fall back to app (client-credentials) token.
  Future<String> resolveAccessToken() async {
    final user = await resolveUserToken();
    if (user != null) return user;
    return fetchAppToken();
  }

  /// User token only — no app-token fallback. Returns null when signed out.
  /// User-scoped operations (follow/unfollow, GQL) must use this so a
  /// missing user token is never silently replaced by an app token (which
  /// the endpoint rejects, previously triggering bogus logouts).
  Future<String?> resolveUserToken() async {
    final user = await tokenStorage.readUserToken();
    if (user != null && user.isNotEmpty) return user;
    return null;
  }

  /// True when [token] validates against Twitch. Network/server errors
  /// count as true (unknown) so callers never destroy a session they
  /// cannot prove dead.
  Future<bool> isTokenValid(String token) async {
    try {
      await _validateToken(token);
      return true;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401 || status == 403) return false;
      return true;
    } on Object {
      return false;
    }
  }

  Future<String> fetchAppToken() async {
    final now = DateTime.now();
    if (_appToken != null &&
        _appTokenExpiry != null &&
        now.isBefore(_appTokenExpiry!)) {
      return _appToken!;
    }

    final Map<String, dynamic> data;
    if (AppEnv.hasTokenProxy) {
      final response = await dio.get<Map<String, dynamic>>(
        AppEnv.tokenProxyUrl,
      );
      data = response.data!;
    } else {
      final response = await dio.post<Map<String, dynamic>>(
        'https://id.twitch.tv/oauth2/token',
        queryParameters: {
          'client_id': AppEnv.clientId,
          'client_secret': AppEnv.clientSecret,
          'grant_type': 'client_credentials',
        },
      );
      data = response.data!;
    }

    _appToken = data['access_token'] as String;
    final expiresIn = data['expires_in'] as int? ?? 3600;
    _appTokenExpiry = now.add(Duration(seconds: expiresIn - 60));
    return _appToken!;
  }

  Future<(String, String)> _validateToken(String token) async {
    final response = await dio.get<Map<String, dynamic>>(
      'https://id.twitch.tv/oauth2/validate',
      options: Options(headers: {'Authorization': 'OAuth $token'}),
    );
    final data = response.data!;
    final login = data['login'] as String? ?? '';
    final userId = data['user_id'] as String? ?? '';
    if (login.isEmpty || userId.isEmpty) {
      throw StateError('Invalid Twitch token');
    }
    return (login, userId);
  }

  Future<void> _pruneDeadInactiveAccounts() async {
    if (_inactiveAccounts.isEmpty) return;
    final kept = <StoredTwitchAccount>[];
    for (final account in _inactiveAccounts) {
      final valid = await isTokenValid(account.token);
      if (valid) kept.add(account);
    }
    if (kept.length != _inactiveAccounts.length) {
      await tokenStorage.writeInactiveAccounts(kept);
      _inactiveAccounts = kept;
    }
  }
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    dio: ref.watch(dioProvider),
    tokenStorage: ref.watch(tokenStorageProvider),
  );
});

class AuthController extends AsyncNotifier<AuthSession> {
  @override
  Future<AuthSession> build() async {
    return ref.read(authRepositoryProvider).restore();
  }

  Future<void> completeLogin(String token) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).completeLogin(token),
    );
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncData(AuthSession.anonymous);
  }

  Future<void> switchAccount(String userId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).switchAccount(userId),
    );
  }

  Future<void> removeAccount(String userId) async {
    final repo = ref.read(authRepositoryProvider);
    final wasActive = state.value?.userId == userId;
    await repo.removeAccount(userId);
    if (wasActive) {
      state = const AsyncData(AuthSession.anonymous);
    } else {
      // Trigger rebuild so savedAccountsProvider refreshes.
      state = AsyncData(repo.session);
    }
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession>(AuthController.new);

/// Saved accounts for the Settings UI (active + inactive).
final savedAccountsProvider = Provider<List<StoredTwitchAccount>>((ref) {
  // Depend on auth so the list rebuilds after login/switch/logout.
  ref.watch(authControllerProvider);
  return ref.watch(authRepositoryProvider).allAccounts;
});
