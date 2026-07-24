import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Twitch API credentials loaded from `.env`.
class AppEnv {
  AppEnv._();

  static String get clientId => dotenv.env['CLIENT_ID'] ?? '';

  /// Client secret — used only for local app-token (client credentials).
  /// Never ship this in production release builds without a backend proxy.
  static String get clientSecret => dotenv.env['SECRET'] ?? '';

  static const redirectUri = 'https://twitch.tv/login';

  static const oauthScopes = [
    'chat:read',
    'chat:edit',
    'user:read:follows',
    'user:read:emotes',
  ];

  static bool get isConfigured =>
      clientId.isNotEmpty && clientSecret.isNotEmpty;
}
