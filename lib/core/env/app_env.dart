import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Twitch API credentials loaded from `.env`.
class AppEnv {
  AppEnv._();

  static String get clientId => dotenv.env['CLIENT_ID'] ?? '';

  /// Client secret — used only for local app-token (client credentials).
  /// Prefer [tokenProxyUrl] for production so SECRET never ships in the APK.
  static String get clientSecret => dotenv.env['SECRET'] ?? '';

  /// Optional HTTPS endpoint that returns a Twitch app access token JSON
  /// (`access_token`, `expires_in`) using server-side client credentials.
  static String get tokenProxyUrl => dotenv.env['TOKEN_PROXY_URL'] ?? '';

  static bool get hasTokenProxy => tokenProxyUrl.trim().isNotEmpty;

  static const redirectUri = 'https://twitch.tv/login';

  static const oauthScopes = [
    'chat:read',
    'chat:edit',
    'user:read:follows',
    'user:read:emotes',
  ];

  static bool get isConfigured =>
      clientId.isNotEmpty && (hasTokenProxy || clientSecret.isNotEmpty);
}
