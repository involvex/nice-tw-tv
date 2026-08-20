import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';

class BlockedUsersSection extends ConsumerWidget {
  const BlockedUsersSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final blocked = ref.watch(blockedUsersControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Blocked users', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        if (blocked.isEmpty)
          Text(
            'No blocked users',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        else
          for (final login in blocked)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.block),
              title: Text(login),
              trailing: TextButton(
                onPressed: () => ref
                    .read(blockedUsersControllerProvider.notifier)
                    .unblock(login),
                child: const Text('Unblock'),
              ),
            ),
      ],
    );
  }
}
