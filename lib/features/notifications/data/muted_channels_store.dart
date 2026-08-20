import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MutedChannelsStore {
  MutedChannelsStore(this._prefs);

  static const _key = 'muted_channels';

  final SharedPreferences _prefs;

  Set<String> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.map((e) => e.toLowerCase()).toSet();
  }

  Future<void> mute(String login) async {
    final next = {...read(), login.toLowerCase()};
    await _prefs.setStringList(_key, next.toList());
  }

  Future<void> unmute(String login) async {
    final next = {...read()}..remove(login.toLowerCase());
    await _prefs.setStringList(_key, next.toList());
  }
}

class MutedChannelsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return MutedChannelsStore(ref.watch(sharedPreferencesProvider)).read();
  }

  Future<void> mute(String login) async {
    final store = MutedChannelsStore(ref.watch(sharedPreferencesProvider));
    await store.mute(login);
    state = store.read();
  }

  Future<void> unmute(String login) async {
    final store = MutedChannelsStore(ref.watch(sharedPreferencesProvider));
    await store.unmute(login);
    state = store.read();
  }
}

final mutedChannelsControllerProvider =
    NotifierProvider<MutedChannelsController, Set<String>>(
      MutedChannelsController.new,
    );
