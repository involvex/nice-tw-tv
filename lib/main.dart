import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/routing/app_router.dart';
import 'package:nice_tv/core/theme/nice_tv_theme.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  await dotenv.load(fileName: '.env');
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const NiceTvApp(),
    ),
  );
}

class NiceTvApp extends ConsumerStatefulWidget {
  const NiceTvApp({super.key});

  @override
  ConsumerState<NiceTvApp> createState() => _NiceTvAppState();
}

class _NiceTvAppState extends ConsumerState<NiceTvApp> {
  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    Future.microtask(() => ref.read(notificationsInboxProvider));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(goRouterProvider);

    if (!AppEnv.isConfigured) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Missing Twitch credentials.\n'
                'Add CLIENT_ID and either SECRET (local) or '
                'TOKEN_PROXY_URL (production) to .env',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: 'Nice TV',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      theme: NiceTvTheme.light(settings.accent),
      darkTheme: NiceTvTheme.dark(settings.accent),
      routerConfig: router,
    );
  }
}
