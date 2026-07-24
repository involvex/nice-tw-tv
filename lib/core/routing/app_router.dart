import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/presentation/login_screen.dart';
import 'package:nice_tv/features/home/presentation/autoplay_feed.dart';
import 'package:nice_tv/features/home/presentation/following_screen.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';
import 'package:nice_tv/features/notifications/presentation/notifications_screen.dart';
import 'package:nice_tv/features/profile/presentation/channel_profile_screen.dart';
import 'package:nice_tv/features/search/presentation/search_screen.dart';
import 'package:nice_tv/features/settings/presentation/settings_screen.dart';
import 'package:nice_tv/features/vod/presentation/vod_screen.dart';
import 'package:nice_tv/features/watch/presentation/watch_screen.dart';

final goRouterProvider = Provider<GoRouter>((ref) {
  // Keep live-alert polling warm while the shell is alive.
  ref.watch(notificationsInboxProvider);
  return GoRouter(
    initialLocation: '/',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return _MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomeScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/following',
                builder: (context, state) => const FollowingScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/vods',
                builder: (context, state) => const VodScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(
        path: '/search',
        builder: (context, state) => const SearchScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/:login',
        builder: (context, state) {
          return ChannelProfileScreen(
            login: state.pathParameters['login'],
            userId: state.uri.queryParameters['userId'],
          );
        },
      ),
      GoRoute(
        path: '/category/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Category';
          return CategoryStreamsScreen(gameId: id, name: name);
        },
      ),
      GoRoute(
        path: '/watch/:login',
        builder: (context, state) {
          final login = state.pathParameters['login']!;
          final title = state.uri.queryParameters['title'];
          final userId = state.uri.queryParameters['userId'];
          return WatchScreen(
            channelLogin: login,
            title: title,
            broadcasterId: userId,
          );
        },
      ),
      GoRoute(
        path: '/vod/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'];
          final login = state.uri.queryParameters['login'] ?? 'vod';
          final userId = state.uri.queryParameters['userId'];
          return WatchScreen(
            channelLogin: login,
            title: title,
            broadcasterId: userId,
            vodId: id,
          );
        },
      ),
      GoRoute(
        path: '/clip/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'];
          final login = state.uri.queryParameters['login'] ?? 'clip';
          return WatchScreen(
            channelLogin: login,
            title: title,
            clipId: id,
          );
        },
      ),
    ],
  );
});

class _MainShell extends StatelessWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.live_tv_outlined),
            selectedIcon: Icon(Icons.live_tv),
            label: 'Live',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Following',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_library_outlined),
            selectedIcon: Icon(Icons.video_library),
            label: 'VODs',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
