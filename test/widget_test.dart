import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:nice_tv/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _IdleHomeFeed extends HomeFeedController {
  @override
  HomeFeedState build() => const HomeFeedState();

  @override
  Future<void> refresh() async {}

  @override
  Future<void> loadMore() async {}
}

class _IdleAuth extends AuthController {
  @override
  Future<AuthSession> build() async => AuthSession.anonymous;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dotenv.loadFromString(
      envString: 'CLIENT_ID=test_client\nSECRET=test_secret\n',
    );
  });

  testWidgets('Nice TV boots to live shell', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          homeFeedControllerProvider.overrideWith(_IdleHomeFeed.new),
          authControllerProvider.overrideWith(_IdleAuth.new),
        ],
        child: const NiceTvApp(),
      ),
    );
    await tester.pump();
    expect(find.text('Nice TV'), findsWidgets);
    expect(find.text('Live'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
