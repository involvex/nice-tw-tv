import 'dart:convert';

import 'package:nice_tv/features/settings/data/settings_controller.dart';

String buildExportPayload(AppSettings settings) {
  return jsonEncode({
    'version': 1,
    'themeMode': AppSettings.themeModeToString(settings.themeMode),
    'accentArgb': settings.accentArgb,
    'chatDensity': settings.chatDensity,
    'videoQuality': settings.videoQuality,
    'discoveryLanguage': settings.discoveryLanguage,
    'discoveryHideMature': settings.discoveryHideMature,
    'discoverySortOrder': settings.discoverySortOrder,
    'videoVolume': settings.videoVolume,
    'videoMuted': settings.videoMuted,
    'playbackSpeed': settings.playbackSpeed,
    'highContrast': settings.highContrast,
    'quietHoursEnabled': settings.quietHoursEnabled,
    'quietHoursStart': settings.quietHoursStart,
    'quietHoursEnd': settings.quietHoursEnd,
    'chatTimestamps': settings.chatTimestamps,
    'maskLinks': settings.maskLinks,
    'chatFontSizeScale': settings.chatFontSizeScale,
    'chatFontFamily': settings.chatFontFamily,
  });
}

AppSettings? parseExportPayload(String raw) {
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) return null;
    return AppSettings(
      themeMode: AppSettings.parseThemeMode(
        json['themeMode'] as String? ?? 'system',
      ),
      accentArgb: json['accentArgb'] as int? ?? 0xFF1FA2A6,
      chatDensity: json['chatDensity'] as int? ?? 1,
      videoQuality: json['videoQuality'] as String? ?? 'auto',
      discoveryLanguage: json['discoveryLanguage'] as String?,
      discoveryHideMature: json['discoveryHideMature'] as bool? ?? false,
      discoverySortOrder:
          json['discoverySortOrder'] as String? ?? 'viewerCount',
      videoVolume: (json['videoVolume'] as num?)?.toDouble() ?? 0.7,
      videoMuted: json['videoMuted'] as bool? ?? false,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      highContrast: json['highContrast'] as bool? ?? false,
      chatTimestamps: json['chatTimestamps'] as bool? ?? false,
      maskLinks: json['maskLinks'] as bool? ?? false,
      chatFontSizeScale: json['chatFontSizeScale'] as double? ?? 1.0,
      chatFontFamily: json['chatFontFamily'] as String? ?? 'Segoe UI',
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int? ?? 22 * 60,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? 7 * 60,
    );
  } on Object {
    return null;
  }
}
