import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
    : _secure = secureStorage ?? const FlutterSecureStorage();

  static const _userTokenKey = 'twitch_user_access_token';
  static const _userLoginKey = 'twitch_user_login';
  static const _userIdKey = 'twitch_user_id';

  final FlutterSecureStorage _secure;

  Future<String?> readUserToken() => _secure.read(key: _userTokenKey);

  Future<void> writeUserSession({
    required String token,
    required String login,
    required String userId,
  }) async {
    await _secure.write(key: _userTokenKey, value: token);
    await _secure.write(key: _userLoginKey, value: login);
    await _secure.write(key: _userIdKey, value: userId);
  }

  Future<String?> readLogin() => _secure.read(key: _userLoginKey);

  Future<String?> readUserId() => _secure.read(key: _userIdKey);

  Future<void> clearUserSession() async {
    await _secure.delete(key: _userTokenKey);
    await _secure.delete(key: _userLoginKey);
    await _secure.delete(key: _userIdKey);
  }
}

class SettingsStorage {
  SettingsStorage(this._prefs);

  final SharedPreferences _prefs;

  static const themeModeKey = 'theme_mode';
  static const accentKey = 'accent_color';
  static const chatDensityKey = 'chat_density';
  static const videoQualityKey = 'video_quality';
  static const discoveryLanguageKey = 'discovery_language';
  static const discoveryHideMatureKey = 'discovery_hide_mature';
  static const discoverySortOrderKey = 'discovery_sort_order';
  static const videoVolumeKey = 'video_volume';
  static const videoMutedKey = 'video_muted';
  static const playbackSpeedKey = 'playback_speed';
  static const highContrastKey = 'high_contrast';
  static const quietHoursEnabledKey = 'quiet_hours_enabled';
  static const quietHoursStartKey = 'quiet_hours_start';
  static const quietHoursEndKey = 'quiet_hours_end';
  static const chatFontSizeScaleKey = 'chat_font_size_scale';
  static const chatFontFamilyKey = 'chat_font_family';
  static const chatTimestampsKey = 'chat_timestamps';
  static const maskLinksKey = 'mask_links';

  String get themeMode => _prefs.getString(themeModeKey) ?? 'system';

  Future<void> setThemeMode(String value) =>
      _prefs.setString(themeModeKey, value);

  int get accentArgb => _prefs.getInt(accentKey) ?? 0xFF1FA2A6;

  Future<void> setAccentArgb(int value) => _prefs.setInt(accentKey, value);

  /// 0 compact, 1 comfortable, 2 spacious
  int get chatDensity => _prefs.getInt(chatDensityKey) ?? 1;

  Future<void> setChatDensity(int value) =>
      _prefs.setInt(chatDensityKey, value);

  String get videoQuality => _prefs.getString(videoQualityKey) ?? 'auto';

  Future<void> setVideoQuality(String value) =>
      _prefs.setString(videoQualityKey, value);

  String? get discoveryLanguage => _prefs.getString(discoveryLanguageKey);

  Future<void> setDiscoveryLanguage(String? value) async {
    if (value == null) {
      await _prefs.remove(discoveryLanguageKey);
    } else {
      await _prefs.setString(discoveryLanguageKey, value);
    }
  }

  bool get discoveryHideMature =>
      _prefs.getBool(discoveryHideMatureKey) ?? false;

  Future<void> setDiscoveryHideMature(bool value) =>
      _prefs.setBool(discoveryHideMatureKey, value);

  String get discoverySortOrder =>
      _prefs.getString(discoverySortOrderKey) ?? 'viewerCount';

  Future<void> setDiscoverySortOrder(String value) =>
      _prefs.setString(discoverySortOrderKey, value);

  double get videoVolume => _prefs.getDouble(videoVolumeKey) ?? 0.7;

  Future<void> setVideoVolume(double value) =>
      _prefs.setDouble(videoVolumeKey, value);

  bool get videoMuted => _prefs.getBool(videoMutedKey) ?? false;

  Future<void> setVideoMuted(bool value) =>
      _prefs.setBool(videoMutedKey, value);

  double get playbackSpeed => _prefs.getDouble(playbackSpeedKey) ?? 1.0;

  Future<void> setPlaybackSpeed(double value) =>
      _prefs.setDouble(playbackSpeedKey, value);

  bool get highContrast => _prefs.getBool(highContrastKey) ?? false;

  Future<void> setHighContrast(bool value) =>
      _prefs.setBool(highContrastKey, value);

  bool get quietHoursEnabled => _prefs.getBool(quietHoursEnabledKey) ?? false;

  Future<void> setQuietHoursEnabled(bool value) =>
      _prefs.setBool(quietHoursEnabledKey, value);

  int get quietHoursStart => _prefs.getInt(quietHoursStartKey) ?? 22 * 60;

  int get quietHoursEnd => _prefs.getInt(quietHoursEndKey) ?? 7 * 60;

  Future<void> setQuietHours({required int start, required int end}) async {
    await _prefs.setInt(quietHoursStartKey, start);
    await _prefs.setInt(quietHoursEndKey, end);
  }

  double get chatFontSizeScale => _prefs.getDouble(chatFontSizeScaleKey) ?? 1.0;

  Future<void> setChatFontSizeScale(double value) =>
      _prefs.setDouble(chatFontSizeScaleKey, value);

  String get chatFontFamily =>
      _prefs.getString(chatFontFamilyKey) ?? 'Segoe UI';

  Future<void> setChatFontFamily(String value) =>
      _prefs.setString(chatFontFamilyKey, value);

  bool get chatTimestamps => _prefs.getBool(chatTimestampsKey) ?? false;

  Future<void> setChatTimestamps(bool value) =>
      _prefs.setBool(chatTimestampsKey, value);

  bool get maskLinks => _prefs.getBool(maskLinksKey) ?? false;

  Future<void> setMaskLinks(bool value) => _prefs.setBool(maskLinksKey, value);
}
