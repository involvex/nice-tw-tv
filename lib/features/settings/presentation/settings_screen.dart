import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsControllerProvider);
    final auth = ref.watch(authControllerProvider).value;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (auth?.isLoggedIn == true) ...[
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.account_circle_outlined),
              title: Text(auth!.login ?? 'Signed in'),
              subtitle: const Text('Twitch account connected'),
              trailing: TextButton(
                onPressed: () =>
                    ref.read(authControllerProvider.notifier).logout(),
                child: const Text('Sign out'),
              ),
            ),
          ] else
            FilledButton.tonal(
              onPressed: () => context.push('/login'),
              child: const Text('Sign in with Twitch'),
            ),
          const SizedBox(height: 24),
          Text('Appearance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('System'),
                icon: Icon(Icons.brightness_auto),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Light'),
                icon: Icon(Icons.light_mode_outlined),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode_outlined),
              ),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (set) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setThemeMode(set.first);
            },
          ),
          const SizedBox(height: 16),
          Text('Accent', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in accentChoices)
                GestureDetector(
                  onTap: () => ref
                      .read(settingsControllerProvider.notifier)
                      .setAccent(color),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: settings.accentArgb == color.toARGB32()
                            ? theme.colorScheme.onSurface
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Chat', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text('Density', style: theme.textTheme.titleSmall),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Compact')),
              ButtonSegment(value: 1, label: Text('Default')),
              ButtonSegment(value: 2, label: Text('Spacious')),
            ],
            selected: {settings.chatDensity},
            onSelectionChanged: (set) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setChatDensity(set.first);
            },
          ),
          const SizedBox(height: 24),
          Text('Stream', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Default quality'),
            subtitle: Text(settings.videoQuality),
            trailing: DropdownButton<String>(
              value: settings.videoQuality,
              items: const [
                DropdownMenuItem(value: 'auto', child: Text('Auto')),
                DropdownMenuItem(value: '160p', child: Text('160p')),
                DropdownMenuItem(value: '360p', child: Text('360p')),
                DropdownMenuItem(value: '480p', child: Text('480p')),
                DropdownMenuItem(value: '720p', child: Text('720p')),
                DropdownMenuItem(value: '1080p', child: Text('1080p')),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(settingsControllerProvider.notifier)
                    .setVideoQuality(value);
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Layout profiles per streamer land in v1.1. '
            'Chat/video split already adapts in landscape on the watch screen.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
