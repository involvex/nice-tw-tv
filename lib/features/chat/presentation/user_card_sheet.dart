import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:nice_tv/features/chat/data/chat_client.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';

Future<void> showUserCard(
  BuildContext context, {
  required String login,
  required String displayName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => UserCardSheet(login: login, displayName: displayName),
  );
}

class UserCardSheet extends ConsumerStatefulWidget {
  const UserCardSheet({
    super.key,
    required this.login,
    required this.displayName,
  });

  final String login;
  final String displayName;

  @override
  ConsumerState<UserCardSheet> createState() => _UserCardSheetState();
}

class _UserCardSheetState extends ConsumerState<UserCardSheet> {
  late final Future<TwitchUserProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = ref
        .read(helixRepositoryProvider)
        .getUserProfile(login: widget.login);
  }

  Future<void> _moderate(String command) async {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sign in to moderate chat')));
      return;
    }
    ref.read(chatControllerProvider.notifier).sendModeration(command);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _confirmModeration(
    String title,
    String message,
    String command,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _moderate(command);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider).value;
    final blocked = ref.watch(blockedUsersControllerProvider);
    final isBlocked = blocked.contains(widget.login.toLowerCase());
    final isModerator =
        auth?.isLoggedIn == true && (auth?.login == widget.login.toLowerCase());

    return SafeArea(
      child: FutureBuilder<TwitchUserProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage:
                          user == null || user.profileImageUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(user.profileImageUrl),
                      child: user == null || user.profileImageUrl.isEmpty
                          ? Text(
                              widget.displayName.isNotEmpty
                                  ? widget.displayName[0]
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@${widget.login}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user != null && user.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(user.description, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/profile/${widget.login}?userId=${user?.id}',
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('View profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final notifier = ref.read(
                          blockedUsersControllerProvider.notifier,
                        );
                        if (isBlocked) {
                          notifier.unblock(widget.login);
                        } else {
                          notifier.block(widget.login);
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        isBlocked ? Icons.block : Icons.remove_circle_outline,
                      ),
                      label: Text(isBlocked ? 'Unblock' : 'Block'),
                    ),
                    if (isModerator) ...[
                      OutlinedButton.icon(
                        onPressed: () => _confirmModeration(
                          'Timeout ${widget.displayName}',
                          'Remove messages and restrict chatting for 10 minutes.',
                          '/timeout ${widget.login} 600',
                        ),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Timeout'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmModeration(
                          'Ban ${widget.displayName}',
                          'Permanently ban this user from the channel.',
                          '/ban ${widget.login}',
                        ),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Ban'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
