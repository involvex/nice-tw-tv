import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('home feed mode persists cards vs autoplay', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(homeFeedModeProvider), HomeFeedMode.cards);
    await container.read(homeFeedModeProvider.notifier).toggle();
    expect(container.read(homeFeedModeProvider), HomeFeedMode.autoplay);
    expect(prefs.getString('home_feed_mode'), HomeFeedMode.autoplay.name);

    final container2 = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container2.dispose);
    expect(container2.read(homeFeedModeProvider), HomeFeedMode.autoplay);
  });
}
