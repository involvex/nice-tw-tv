import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/presentation/login_screen.dart';
import 'package:nice_tv/features/history/presentation/history_screen.dart';
import 'package:nice_tv/features/home/presentation/category_autoplay_feed.dart';
import 'package:nice_tv/features/home/presentation/category_browse_screen.dart';
import 'package:nice_tv/features/home/presentation/following_screen.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/notifications/presentation/notifications_screen.dart';
import 'package:nice_tv/features/profile/presentation/channel_profile_screen.dart';
import 'package:nice_tv/features/search/presentation/search_screen.dart';
import 'package:nice_tv/features/settings/presentation/settings_screen.dart';
import 'package:nice_tv/features/vod/presentation/vod_screen.dart';
import 'package:nice_tv/features/watch/presentation/mini_player.dart';
import 'package:nice_tv/features/watch/presentation/watch_screen.dart';

final routeObserver = RouteObserver<ModalRoute<void>>();

final goRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    observers: [routeObserver],
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
        path: '/history',
        builder: (context, state) => const HistoryScreen(),
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
          return CategoryBrowseScreen(gameId: id, name: name);
        },
      ),
      GoRoute(
        path: '/category/:id/autoplay',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final name = state.uri.queryParameters['name'] ?? 'Category';
          return CategoryAutoplayFeedScreen(gameId: id, name: name);
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
            thumbnailUrl: state.uri.queryParameters['thumbnailUrl'],
          );
        },
      ),
      GoRoute(
        path: '/clip/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final title = state.uri.queryParameters['title'];
          final login = state.uri.queryParameters['login'] ?? 'clip';
          return WatchScreen(channelLogin: login, title: title, clipId: id);
        },
      ),
    ],
  );
});

class _MainShell extends ConsumerWidget {
  const _MainShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final navBarHeight =
        NavigationBarTheme.of(context).height ?? kBottomNavigationBarHeight;
    return Scaffold(
      body: Stack(
        children: [
          navigationShell,
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: navBarHeight + 8),
              child: const MiniPlayer(),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == navigationShell.currentIndex) {
            final location = GoRouterState.of(context).uri.path;
            if (index == 0 && location == '/') {
              final controller = ref.read(homeScrollControllerProvider);
              if (controller.hasClients) {
                controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
              return;
            }
          }
          navigationShell.goBranch(index);
        },
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
