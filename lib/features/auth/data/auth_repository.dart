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

  AuthSession get session => _session;

  String buildAuthorizeUrl() {
    final scopes = AppEnv.oauthScopes.join(' ');
    final uri = Uri.https('id.twitch.tv', '/oauth2/authorize', {
      'client_id': AppEnv.clientId,
      'redirect_uri': AppEnv.redirectUri,
      'response_type': 'token',
      'scope': scopes,
      'force_verify': 'true',
    });
    return uri.toString();
  }

  /// Parses `#access_token=...` from the OAuth redirect URL.
  String? extractTokenFromRedirect(String url) {
    final uri = Uri.parse(url.replaceFirst('#', '?'));
    return uri.queryParameters['access_token'];
  }

  bool isOAuthRedirect(String url) {
    return url.startsWith(AppEnv.redirectUri) && url.contains('access_token=');
  }

  Future<AuthSession> restore() async {
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
    } on Object {
      await tokenStorage.clearUserSession();
      _session = AuthSession.anonymous;
    }
    return _session;
  }

  Future<AuthSession> completeLogin(String accessToken) async {
    final user = await _validateToken(accessToken);
    await tokenStorage.writeUserSession(
      token: accessToken,
      login: user.$1,
      userId: user.$2,
    );
    _session = AuthSession(
      isLoggedIn: true,
      accessToken: accessToken,
      login: user.$1,
      userId: user.$2,
    );
    return _session;
  }

  Future<void> logout() async {
    await tokenStorage.clearUserSession();
    _session = AuthSession.anonymous;
  }

  /// Prefer user token; fall back to app (client-credentials) token.
  Future<String> resolveAccessToken() async {
    final user = await tokenStorage.readUserToken();
    if (user != null && user.isNotEmpty) return user;
    return fetchAppToken();
  }

  Future<String> fetchAppToken() async {
    final now = DateTime.now();
    if (_appToken != null &&
        _appTokenExpiry != null &&
        now.isBefore(_appTokenExpiry!)) {
      return _appToken!;
    }
    final response = await dio.post<Map<String, dynamic>>(
      'https://id.twitch.tv/oauth2/token',
      queryParameters: {
        'client_id': AppEnv.clientId,
        'client_secret': AppEnv.clientSecret,
        'grant_type': 'client_credentials',
      },
    );
    final data = response.data!;
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
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AuthSession>(AuthController.new);
