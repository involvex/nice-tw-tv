import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
import 'package:nice_tv/features/notifications/data/notifications_inbox.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider).value;
    final inbox = ref.watch(notificationsInboxProvider);
    final muted = ref.watch(mutedChannelsControllerProvider);

    if (auth?.isLoggedIn != true) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_none,
                  size: 56,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Sign in to get live alerts',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nice TV watches channels you follow and lists when they go live.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push('/login'),
                  child: const Text('Sign in with Twitch'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (inbox.unreadCount > 0)
            TextButton(
              onPressed: () =>
                  ref.read(notificationsInboxProvider.notifier).markAllRead(),
              child: const Text('Mark all read'),
            ),
          if (inbox.items.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              onPressed: () =>
                  ref.read(notificationsInboxProvider.notifier).clearAll(),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(notificationsInboxProvider.notifier).refresh(force: true),
        child: inbox.isLoading && inbox.items.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : inbox.error != null && inbox.items.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(inbox.error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => ref
                              .read(notificationsInboxProvider.notifier)
                              .refresh(force: true),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : inbox.items.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 240,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 56,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No live alerts yet',
                              style: theme.textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When a followed channel goes live, it will show up here.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                itemCount: inbox.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final item = inbox.items[index];
                  return ListTile(
                    leading: Icon(
                      item.read
                          ? Icons.notifications_none
                          : Icons.notifications_active,
                      color: item.read
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.primary,
                    ),
                    title: Text(
                      '${item.userName} went live',
                      style: TextStyle(
                        fontWeight: item.read
                            ? FontWeight.w500
                            : FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      [
                        if (item.gameName.isNotEmpty) item.gameName,
                        if (item.title.isNotEmpty) item.title,
                      ].join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _relative(item.wentLiveAt),
                          style: theme.textTheme.labelSmall,
                        ),
                        IconButton(
                          tooltip: muted.contains(item.userLogin.toLowerCase())
                              ? 'Unmute notifications'
                              : 'Mute notifications',
                          onPressed: () {
                            final notifier = ref.read(
                              mutedChannelsControllerProvider.notifier,
                            );
                            if (muted.contains(item.userLogin.toLowerCase())) {
                              notifier.unmute(item.userLogin);
                            } else {
                              notifier.mute(item.userLogin);
                            }
                          },
                          icon: Icon(
                            muted.contains(item.userLogin.toLowerCase())
                                ? Icons.notifications_off_outlined
                                : Icons.notifications_outlined,
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await ref
                          .read(notificationsInboxProvider.notifier)
                          .markRead(item.id);
                      if (!context.mounted) return;
                      context.push(
                        '/watch/${item.userLogin}'
                        '?title=${Uri.encodeComponent(item.title)}'
                        '&userId=${Uri.encodeComponent(item.userId)}',
                      );
                    },
                  );
                },
              ),
      ),
    );
  }

  String _relative(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }
}
