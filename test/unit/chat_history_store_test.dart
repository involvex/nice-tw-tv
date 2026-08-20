import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:nice_tv/features/chat/data/chat_history_store.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
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

  group('ChatHistoryStore', () {
    ChatMessage msg(String id, {String login = 'viewer'}) {
      return ChatMessage(
        id: id,
        channel: 'chan',
        login: login,
        displayName: login,
        message: 'hello $id',
        color: null,
        isAction: false,
        timestamp: DateTime.utc(2026, 8, 20),
      );
    }

    test('round-trips messages per channel', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(prefs);

      await store.write('chan', [msg('1'), msg('2')]);
      final restored = store.read('chan');
      expect(restored.map((m) => m.id), ['1', '2']);

      expect(store.read('other'), isEmpty);
    });

    test('caps stored history at 200 messages', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(prefs);
      final many = [for (var i = 0; i < 250; i++) msg('m$i')];

      await store.write('chan', many);
      final restored = store.read('chan');
      expect(restored.length, 200);
      expect(restored.first.id, 'm50');
    });
  });
}
