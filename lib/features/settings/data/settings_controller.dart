import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/storage/app_storage.dart';
import 'package:nice_tv/core/theme/nice_tv_theme.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accentArgb,
    required this.chatDensity,
    required this.videoQuality,
    this.discoveryLanguage,
    this.discoveryHideMature = false,
    this.discoverySortOrder = 'viewerCount',
    this.videoVolume = 0.7,
    this.videoMuted = false,
    this.playbackSpeed = 1.0,
    this.highContrast = false,
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22 * 60,
    this.quietHoursEnd = 7 * 60,
  });

  final ThemeMode themeMode;
  final int accentArgb;
  final int chatDensity;
  final String videoQuality;
  final String? discoveryLanguage;
  final bool discoveryHideMature;
  final String discoverySortOrder;
  final double videoVolume;
  final bool videoMuted;
  final double playbackSpeed;
  final bool highContrast;
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;

  Color get accent => Color(accentArgb);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentArgb,
    int? chatDensity,
    String? videoQuality,
    String? discoveryLanguage,
    bool? discoveryHideMature,
    String? discoverySortOrder,
    double? videoVolume,
    bool? videoMuted,
    double? playbackSpeed,
    bool? highContrast,
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentArgb: accentArgb ?? this.accentArgb,
      chatDensity: chatDensity ?? this.chatDensity,
      videoQuality: videoQuality ?? this.videoQuality,
      discoveryLanguage: discoveryLanguage ?? this.discoveryLanguage,
      discoveryHideMature: discoveryHideMature ?? this.discoveryHideMature,
      discoverySortOrder: discoverySortOrder ?? this.discoverySortOrder,
      videoVolume: videoVolume ?? this.videoVolume,
      videoMuted: videoMuted ?? this.videoMuted,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      highContrast: highContrast ?? this.highContrast,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
    );
  }

  static ThemeMode parseThemeMode(String raw) {
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  static String themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }

  static bool canModerateChat(AuthSession? session) =>
      session?.isLoggedIn == true;
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main');
});

final settingsStorageProvider = Provider<SettingsStorage>((ref) {
  return SettingsStorage(ref.watch(sharedPreferencesProvider));
});

class SettingsController extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final storage = ref.watch(settingsStorageProvider);
    return AppSettings(
      themeMode: AppSettings.parseThemeMode(storage.themeMode),
      accentArgb: storage.accentArgb,
      chatDensity: storage.chatDensity,
      videoQuality: storage.videoQuality,
      discoveryLanguage: storage.discoveryLanguage,
      discoveryHideMature: storage.discoveryHideMature,
      discoverySortOrder: storage.discoverySortOrder,
      videoVolume: storage.videoVolume,
      videoMuted: storage.videoMuted,
      playbackSpeed: storage.playbackSpeed,
      highContrast: storage.highContrast,
      quietHoursEnabled: storage.quietHoursEnabled,
      quietHoursStart: storage.quietHoursStart,
      quietHoursEnd: storage.quietHoursEnd,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref
        .read(settingsStorageProvider)
        .setThemeMode(AppSettings.themeModeToString(mode));
    state = state.copyWith(themeMode: mode);
  }

  Future<void> setAccent(Color color) async {
    final argb = color.toARGB32();
    await ref.read(settingsStorageProvider).setAccentArgb(argb);
    state = state.copyWith(accentArgb: argb);
  }

  Future<void> setChatDensity(int density) async {
    await ref.read(settingsStorageProvider).setChatDensity(density);
    state = state.copyWith(chatDensity: density);
  }

  Future<void> setVideoQuality(String quality) async {
    await ref.read(settingsStorageProvider).setVideoQuality(quality);
    state = state.copyWith(videoQuality: quality);
  }

  Future<void> setDiscoveryLanguage(String? language) async {
    await ref.read(settingsStorageProvider).setDiscoveryLanguage(language);
    state = state.copyWith(discoveryLanguage: language);
  }

  Future<void> setDiscoveryHideMature(bool hide) async {
    await ref.read(settingsStorageProvider).setDiscoveryHideMature(hide);
    state = state.copyWith(discoveryHideMature: hide);
  }

  Future<void> setDiscoverySortOrder(String sortOrder) async {
    await ref.read(settingsStorageProvider).setDiscoverySortOrder(sortOrder);
    state = state.copyWith(discoverySortOrder: sortOrder);
  }

  Future<void> setVideoVolume(double volume) async {
    await ref.read(settingsStorageProvider).setVideoVolume(volume);
    state = state.copyWith(videoVolume: volume);
  }

  Future<void> setVideoMuted(bool muted) async {
    await ref.read(settingsStorageProvider).setVideoMuted(muted);
    state = state.copyWith(videoMuted: muted);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    await ref.read(settingsStorageProvider).setPlaybackSpeed(speed);
    state = state.copyWith(playbackSpeed: speed);
  }

  Future<void> setHighContrast(bool value) async {
    await ref.read(settingsStorageProvider).setHighContrast(value);
    state = state.copyWith(highContrast: value);
  }

  Future<void> setQuietHoursEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setQuietHoursEnabled(value);
    state = state.copyWith(quietHoursEnabled: value);
  }

  Future<void> setQuietHours({required int start, required int end}) async {
    await ref
        .read(settingsStorageProvider)
        .setQuietHours(start: start, end: end);
    state = state.copyWith(quietHoursStart: start, quietHoursEnd: end);
  }

  Future<void> applySettings(AppSettings next) async {
    final storage = ref.read(settingsStorageProvider);
    await storage.setThemeMode(AppSettings.themeModeToString(next.themeMode));
    await storage.setAccentArgb(next.accentArgb);
    await storage.setChatDensity(next.chatDensity);
    await storage.setVideoQuality(next.videoQuality);
    await storage.setDiscoveryLanguage(next.discoveryLanguage);
    await storage.setDiscoveryHideMature(next.discoveryHideMature);
    await storage.setDiscoverySortOrder(next.discoverySortOrder);
    await storage.setVideoVolume(next.videoVolume);
    await storage.setVideoMuted(next.videoMuted);
    await storage.setPlaybackSpeed(next.playbackSpeed);
    await storage.setHighContrast(next.highContrast);
    await storage.setQuietHoursEnabled(next.quietHoursEnabled);
    await storage.setQuietHours(
      start: next.quietHoursStart,
      end: next.quietHoursEnd,
    );
    state = next;
  }
}

final settingsControllerProvider =
    NotifierProvider<SettingsController, AppSettings>(SettingsController.new);

const accentChoices = <Color>[
  kNiceTvSeed,
  kTwitchPurple,
  Color(0xFFE85D04),
  Color(0xFF2A9D8F),
  Color(0xFF4CC9F0),
  Color(0xFFF72585),
];
