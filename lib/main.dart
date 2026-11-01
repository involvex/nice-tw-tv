import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:nice_tv/core/env/app_env.dart';
import 'package:nice_tv/core/routing/app_router.dart';
import 'package:nice_tv/core/theme/nice_tv_theme.dart';
import 'package:nice_tv/features/notifications/data/local_push_service.dart';
import 'package:nice_tv/features/notifications/data/notification_deep_link.dart';
import 'package:nice_tv/features/notifications/data/notification_payload.dart';
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
    Future.microtask(() async {
      ref.read(notificationsInboxProvider);
      final payload = await ref
          .read(localPushServiceProvider)
          .consumeLaunchPayload();
      if (payload != null) {
        ref.read(notificationDeepLinkProvider.notifier).offerPayload(payload);
      }
    });
  }

  void _openWatchFromNotification(WatchNotificationTarget target) {
    final router = ref.read(goRouterProvider);
    final uri = Uri(
      path: '/watch/${target.login}',
      queryParameters: {'broadcasterId': target.userId},
    );
    router.go(uri.toString());
    ref.read(notificationDeepLinkProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsControllerProvider);
    final router = ref.watch(goRouterProvider);

    ref.listen(notificationDeepLinkProvider, (prev, next) {
      if (next == null) return;
      _openWatchFromNotification(next);
    });

    // Cold-start payload may arrive before the first listen callback.
    final pending = ref.read(notificationDeepLinkProvider);
    if (pending != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final still = ref.read(notificationDeepLinkProvider);
        if (still != null) _openWatchFromNotification(still);
      });
    }

    if (!AppEnv.isConfigured) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: NiceTvTheme.light(kNiceTvSeed),
        darkTheme: NiceTvTheme.dark(kNiceTvSeed),
        themeMode: ThemeMode.system,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Missing Twitch credentials.\n'
                'Add CLIENT_ID and either SECRET (local) or '
                'TOKEN_PROXY_URL (production) to .env',
                textAlign: TextAlign.center,
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
      theme: settings.highContrast
          ? NiceTvTheme.highContrastLight(settings.accent)
          : NiceTvTheme.light(settings.accent),
      darkTheme: settings.highContrast
          ? NiceTvTheme.highContrastDark(settings.accent)
          : NiceTvTheme.dark(settings.accent),
      routerConfig: router,
    );
  }
}
