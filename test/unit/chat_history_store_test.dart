import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BlockedUsersStore', () {
    test('round-trips blocked users through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BlockedUsersStore(prefs);
      expect(store.read(), isEmpty);

      await store.add('troll1');
      await store.add('troll2');
      expect(store.read(), {'troll1', 'troll2'});

      await store.remove('troll1');
      expect(store.read(), {'troll2'});
    });

    test('stores logins lowercased', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BlockedUsersStore(prefs);
      await store.add('Troll');
      expect(store.read(), {'troll'});
    });
  });
}
