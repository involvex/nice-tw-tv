import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/storage/app_storage.dart';
import 'package:nice_tv/core/theme/nice_tv_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.accentArgb,
    required this.chatDensity,
    required this.videoQuality,
  });

  final ThemeMode themeMode;
  final int accentArgb;
  final int chatDensity;
  final String videoQuality;

  Color get accent => Color(accentArgb);

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? accentArgb,
    int? chatDensity,
    String? videoQuality,
  }) {
    return AppSettings(
      themeMode: themeMode ?? this.themeMode,
      accentArgb: accentArgb ?? this.accentArgb,
      chatDensity: chatDensity ?? this.chatDensity,
      videoQuality: videoQuality ?? this.videoQuality,
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
