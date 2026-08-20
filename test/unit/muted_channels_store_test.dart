import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MutedChannelsStore', () {
    test('round-trips muted channels through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MutedChannelsStore(prefs);
      expect(store.read(), isEmpty);

      await store.mute('bigstreamer');
      await store.mute('smallstreamer');
      expect(store.read(), {'bigstreamer', 'smallstreamer'});

      await store.unmute('bigstreamer');
      expect(store.read(), {'smallstreamer'});
    });

    test('stores logins lowercased', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MutedChannelsStore(prefs);
      await store.mute('BigStreamer');
      expect(store.read(), {'bigstreamer'});
    });
  });
}
