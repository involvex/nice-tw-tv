import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:nice_tv/features/settings/data/settings_export.dart';
import 'package:nice_tv/features/settings/presentation/blocked_users_section.dart';

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
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('High contrast'),
            subtitle: const Text('Stronger color contrast for accessibility'),
            value: settings.highContrast,
            onChanged: (value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setHighContrast(value);
            },
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
          if (AppSettings.canModerateChat(auth)) ...[
            const SizedBox(height: 16),
            const BlockedUsersSection(),
          ],
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
          const SizedBox(height: 8),
          Text('Discovery', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Language'),
            subtitle: Text(
              settings.discoveryLanguage?.toUpperCase() ?? 'All languages',
            ),
            trailing: DropdownButton<String>(
              value: settings.discoveryLanguage,
              items: const [
                DropdownMenuItem(value: null, child: Text('All')),
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'de', child: Text('German')),
                DropdownMenuItem(value: 'fr', child: Text('French')),
                DropdownMenuItem(value: 'es', child: Text('Spanish')),
                DropdownMenuItem(value: 'pt', child: Text('Portuguese')),
                DropdownMenuItem(value: 'ko', child: Text('Korean')),
                DropdownMenuItem(value: 'ja', child: Text('Japanese')),
                DropdownMenuItem(value: 'zh', child: Text('Chinese')),
                DropdownMenuItem(value: 'ru', child: Text('Russian')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (value) {
                if (value == settings.discoveryLanguage) return;
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDiscoveryLanguage(value);
              },
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Hide mature content'),
            subtitle: const Text('Filter out streams marked as mature'),
            value: settings.discoveryHideMature,
            onChanged: (value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setDiscoveryHideMature(value);
            },
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Sort by'),
            subtitle: Text(switch (settings.discoverySortOrder) {
              'viewerCount' => 'Viewer count',
              'recentlyStarted' => 'Recently started',
              'alphabetical' => 'Alphabetical (A-Z)',
              _ => settings.discoverySortOrder,
            }),
            trailing: DropdownButton<String>(
              value: settings.discoverySortOrder,
              items: const [
                DropdownMenuItem(value: 'viewerCount', child: Text('Viewers')),
                DropdownMenuItem(
                  value: 'recentlyStarted',
                  child: Text('Recent'),
                ),
                DropdownMenuItem(value: 'alphabetical', child: Text('A-Z')),
              ],
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(settingsControllerProvider.notifier)
                    .setDiscoverySortOrder(value);
              },
            ),
          ),
          const SizedBox(height: 24),
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Do Not Disturb'),
            subtitle: const Text(
              'Silence live-alert notifications during quiet hours',
            ),
            value: settings.quietHoursEnabled,
            onChanged: (value) {
              ref
                  .read(settingsControllerProvider.notifier)
                  .setQuietHoursEnabled(value);
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Quiet hours start'),
                  subtitle: Text(_formatTime(settings.quietHoursStart)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        DateTime(
                          2026,
                          1,
                          1,
                          settings.quietHoursStart ~/ 60,
                          settings.quietHoursStart % 60,
                        ),
                      ),
                    );
                    if (picked == null) return;
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setQuietHours(
                          start: picked.hour * 60 + picked.minute,
                          end: settings.quietHoursEnd,
                        );
                  },
                ),
              ),
              Expanded(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Quiet hours end'),
                  subtitle: Text(_formatTime(settings.quietHoursEnd)),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                        DateTime(
                          2026,
                          1,
                          1,
                          settings.quietHoursEnd ~/ 60,
                          settings.quietHoursEnd % 60,
                        ),
                      ),
                    );
                    if (picked == null) return;
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .setQuietHours(
                          start: settings.quietHoursStart,
                          end: picked.hour * 60 + picked.minute,
                        );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final muted = ref.watch(mutedChannelsControllerProvider);
              if (muted.isEmpty) {
                return Text(
                  'No muted channels. Mute a channel from its live-alert row.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: muted.map((login) {
                  return InputChip(
                    label: Text(login),
                    onDeleted: () => ref
                        .read(mutedChannelsControllerProvider.notifier)
                        .unmute(login),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          Text('Player backend', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final backend = ref.watch(playerBackendControllerProvider);
              return SegmentedButton<PlayerBackend>(
                segments: const [
                  ButtonSegment(
                    value: PlayerBackend.embed,
                    label: Text('Embed'),
                    icon: Icon(Icons.web_asset),
                  ),
                  ButtonSegment(
                    value: PlayerBackend.nativeHls,
                    label: Text('Native HLS'),
                    icon: Icon(Icons.play_circle_outline),
                  ),
                ],
                selected: {backend},
                onSelectionChanged: (set) {
                  ref
                      .read(playerBackendControllerProvider.notifier)
                      .setBackend(set.first);
                },
              );
            },
          ),
          const SizedBox(height: 16),
          Text(
            'Native HLS is experimental (GQL/Usher). '
            'Per-streamer layout profiles are edited from the watch screen customize button.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          Text('Backup', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final payload = buildExportPayload(
                      ref.read(settingsControllerProvider),
                    );
                    await Clipboard.setData(ClipboardData(text: payload));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Settings copied to clipboard'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Export'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final data = await Clipboard.getData('text/plain');
                    final text = data?.text;
                    final restored = text == null
                        ? null
                        : parseExportPayload(text);
                    if (restored == null) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Clipboard does not contain a valid Nice TV export',
                          ),
                        ),
                      );
                      return;
                    }
                    await ref
                        .read(settingsControllerProvider.notifier)
                        .applySettings(restored);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Settings imported')),
                    );
                  },
                  icon: const Icon(Icons.paste_outlined),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Export copies your settings as JSON to the clipboard. '
            'Import reads a JSON payload from the clipboard and applies it.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatTime(int minutesSinceMidnight) {
  final h = minutesSinceMidnight ~/ 60;
  final m = minutesSinceMidnight % 60;
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  final ampm = h < 12 ? 'AM' : 'PM';
  return '$hour12:${m.toString().padLeft(2, '0')} $ampm';
}
