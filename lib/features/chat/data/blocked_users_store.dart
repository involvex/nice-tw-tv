import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedUsersStore {
  BlockedUsersStore(this._prefs);

  static const _key = 'blocked_users';

  final SharedPreferences _prefs;

  Set<String> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.map((e) => e.toLowerCase()).toSet();
  }

  Future<void> add(String login) async {
    final next = {...read(), login.toLowerCase()};
    await _prefs.setStringList(_key, next.toList());
  }

  Future<void> remove(String login) async {
    final next = {...read()}..remove(login.toLowerCase());
    await _prefs.setStringList(_key, next.toList());
  }
}

class BlockedUsersController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    return store.read();
  }

  Future<void> block(String login) async {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    await store.add(login);
    state = store.read();
  }

  Future<void> unblock(String login) async {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    await store.remove(login);
    state = store.read();
  }
}

final blockedUsersControllerProvider =
    NotifierProvider<BlockedUsersController, Set<String>>(
      BlockedUsersController.new,
    );
