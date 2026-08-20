import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ChatPlacement { bottom, side, hidden }

enum PlayerBackend { embed, nativeHls }

class StreamerLayoutProfile {
  const StreamerLayoutProfile({
    this.chatPlacement = ChatPlacement.bottom,
    this.chatDensity,
    this.videoChatRatio = 0.6,
    this.playerBackend,
    this.preferredQuality,
    this.theaterMode = false,
    this.accentArgb,
    this.qualityOverride,
  });

  final ChatPlacement chatPlacement;

  /// Null = use global settings density.
  final int? chatDensity;

  /// Fraction of width/height given to video in split layouts (0.4–0.8).
  final double videoChatRatio;

  /// Null = use global player backend preference.
  final PlayerBackend? playerBackend;

  final String? preferredQuality;

  /// When true, the player takes the full screen and chat is hidden.
  final bool theaterMode;

  /// Optional per-channel accent color (ARGB value).
  final int? accentArgb;

  /// Optional per-channel quality override (e.g. '1080p', 'auto').
  final String? qualityOverride;

  StreamerLayoutProfile copyWith({
    ChatPlacement? chatPlacement,
    int? chatDensity,
    bool clearChatDensity = false,
    double? videoChatRatio,
    PlayerBackend? playerBackend,
    bool clearPlayerBackend = false,
    String? preferredQuality,
    bool clearPreferredQuality = false,
    bool? theaterMode,
    int? accentArgb,
    String? qualityOverride,
  }) {
    return StreamerLayoutProfile(
      chatPlacement: chatPlacement ?? this.chatPlacement,
      chatDensity: clearChatDensity ? null : (chatDensity ?? this.chatDensity),
      videoChatRatio: videoChatRatio ?? this.videoChatRatio,
      playerBackend: clearPlayerBackend
          ? null
          : (playerBackend ?? this.playerBackend),
      preferredQuality: clearPreferredQuality
          ? null
          : (preferredQuality ?? this.preferredQuality),
      theaterMode: theaterMode ?? this.theaterMode,
      accentArgb: accentArgb ?? this.accentArgb,
      qualityOverride: qualityOverride ?? this.qualityOverride,
    );
  }

  Map<String, dynamic> toJson() => {
    'chatPlacement': chatPlacement.name,
    'chatDensity': chatDensity,
    'videoChatRatio': videoChatRatio,
    'playerBackend': playerBackend?.name,
    'preferredQuality': preferredQuality,
    'theaterMode': theaterMode,
    'accentArgb': accentArgb,
    'qualityOverride': qualityOverride,
  };

  factory StreamerLayoutProfile.fromJson(Map<String, dynamic> json) {
    PlayerBackend? backend;
    final backendName = json['playerBackend'] as String?;
    if (backendName != null) {
      for (final value in PlayerBackend.values) {
        if (value.name == backendName) {
          backend = value;
          break;
        }
      }
    }
    return StreamerLayoutProfile(
      chatPlacement: ChatPlacement.values.firstWhere(
        (e) => e.name == json['chatPlacement'],
        orElse: () => ChatPlacement.bottom,
      ),
      chatDensity: json['chatDensity'] as int?,
      videoChatRatio: (json['videoChatRatio'] as num?)?.toDouble() ?? 0.6,
      playerBackend: backend,
      preferredQuality: json['preferredQuality'] as String?,
      theaterMode: json['theaterMode'] as bool? ?? false,
      accentArgb: json['accentArgb'] as int?,
      qualityOverride: json['qualityOverride'] as String?,
    );
  }
}

class LayoutProfileStore {
  LayoutProfileStore(this._prefs);

  static const _key = 'streamer_layout_profiles';
  static const playerBackendKey = 'player_backend';
  static const accentArgbKey = 'accent_argb';
  static const qualityOverrideKey = 'quality_override';

  final SharedPreferences _prefs;

  Map<String, StreamerLayoutProfile> readAll() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(
        key,
        StreamerLayoutProfile.fromJson(value as Map<String, dynamic>),
      ),
    );
  }

  Future<void> writeAll(Map<String, StreamerLayoutProfile> profiles) async {
    final encoded = jsonEncode(
      profiles.map((key, value) => MapEntry(key, value.toJson())),
    );
    await _prefs.setString(_key, encoded);
  }

  StreamerLayoutProfile forChannel(String login) {
    return readAll()[login.toLowerCase()] ?? const StreamerLayoutProfile();
  }

  Future<void> save(String login, StreamerLayoutProfile profile) async {
    final all = readAll();
    all[login.toLowerCase()] = profile;
    await writeAll(all);
  }

  PlayerBackend get globalPlayerBackend {
    final raw = _prefs.getString(playerBackendKey);
    return PlayerBackend.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => PlayerBackend.embed,
    );
  }

  Future<void> setGlobalPlayerBackend(PlayerBackend backend) async {
    await _prefs.setString(playerBackendKey, backend.name);
  }
}

final layoutProfileStoreProvider = Provider<LayoutProfileStore>((ref) {
  return LayoutProfileStore(ref.watch(sharedPreferencesProvider));
});

class LayoutProfilesController
    extends Notifier<Map<String, StreamerLayoutProfile>> {
  @override
  Map<String, StreamerLayoutProfile> build() {
    return ref.watch(layoutProfileStoreProvider).readAll();
  }

  StreamerLayoutProfile forChannel(String login) {
    return state[login.toLowerCase()] ?? const StreamerLayoutProfile();
  }

  Future<void> save(String login, StreamerLayoutProfile profile) async {
    await ref.read(layoutProfileStoreProvider).save(login, profile);
    state = {...state, login.toLowerCase(): profile};
  }
}

final layoutProfilesControllerProvider =
    NotifierProvider<
      LayoutProfilesController,
      Map<String, StreamerLayoutProfile>
    >(LayoutProfilesController.new);

class PlayerBackendController extends Notifier<PlayerBackend> {
  @override
  PlayerBackend build() {
    return ref.watch(layoutProfileStoreProvider).globalPlayerBackend;
  }

  Future<void> setBackend(PlayerBackend backend) async {
    await ref.read(layoutProfileStoreProvider).setGlobalPlayerBackend(backend);
    state = backend;
  }
}

final playerBackendControllerProvider =
    NotifierProvider<PlayerBackendController, PlayerBackend>(
      PlayerBackendController.new,
    );
