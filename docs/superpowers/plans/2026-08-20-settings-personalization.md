# Settings & Personalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a high-contrast theme, Do-Not-Disturb quiet hours, per-channel notification mutes, and clipboard-based settings export/import to Nice TV.

**Architecture:** Extend the existing `settings` feature (`lib/features/settings/`) and the `notifications` feature (`lib/features/notifications/`). New pure logic (quiet-hours check, export payload round-trip) lives in `data/` and is unit-tested; UI toggles live in `presentation/`. New persistent state follows the existing `SettingsStorage` (SharedPreferences) and `BlockedUsersStore` patterns.

**Tech Stack:** Flutter/Dart, Riverpod (`Notifier`/`NotifierProvider`), `shared_preferences`, Flutter built-in `ColorScheme.highContrastLight/highContrastDark`, `Clipboard` (no new deps), `showTimePicker`.

## Global Constraints

- Flutter SDK `^3.13.0-282.1.beta`, Dart latest stable.
- Use `bun` only for non-Flutter tasks; this is a Flutter repo so use `flutter pub get`, `flutter test`, `flutter analyze`, `dart format .`.
- No new third-party dependencies; export/import uses `Clipboard` (no file picker exists in the repo).
- Follow existing naming: files `snake_case.dart`, classes `PascalCase`, private members `_`-prefixed.
- Follow the feature-based architecture: logic in `data/`, UI in `presentation/`.
- Use Riverpod `Notifier`/`NotifierProvider`, never `ChangeNotifier`.
- Quiet hours store start/end as minutes since midnight (0–1439) for stable ordering and easy comparison.
- Do not add comments to code unless a doc comment is genuinely needed (matching existing style).
- Commit after every task with conventional-commit messages (`feat:`).

---

## File Structure

- Modify: `lib/features/settings/data/settings_controller.dart` — new `AppSettings` fields + setters + `applySettings`.
- Modify: `lib/core/storage/app_storage.dart` — new `SettingsStorage` keys/getters/setters.
- Modify: `lib/core/theme/nice_tv_theme.dart` — `highContrastLight`/`highContrastDark`.
- Modify: `lib/main.dart` — theme selection honors `highContrast`.
- Create: `lib/features/settings/data/quiet_hours.dart` — `isInQuietHours` pure helper.
- Create: `lib/features/settings/data/settings_export.dart` — `buildExportPayload`/`parseExportPayload`.
- Create: `lib/features/notifications/data/muted_channels_store.dart` — per-channel mute store + controller.
- Modify: `lib/features/notifications/data/notifications_inbox.dart` — gate push on quiet hours + mutes.
- Modify: `lib/features/notifications/presentation/notifications_screen.dart` — per-channel mute toggle.
- Modify: `lib/features/settings/presentation/settings_screen.dart` — high-contrast toggle, DND section, muted channels section, backup section.
- Test: `test/unit/quiet_hours_test.dart`
- Test: `test/unit/muted_channels_store_test.dart`
- Test: `test/unit/settings_export_test.dart`

---

### Task 1: High-contrast theme

**Files:**
- Modify: `lib/features/settings/data/settings_controller.dart`
- Modify: `lib/core/storage/app_storage.dart`
- Modify: `lib/core/theme/nice_tv_theme.dart`
- Modify: `lib/main.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: existing `NiceTvTheme.light/dark/_base`, `AppSettings`, `SettingsStorage`, `settingsControllerProvider`.
- Produces: `AppSettings.highContrast` (`bool`, default `false`); `SettingsStorage.highContrast` (key `high_contrast`); `SettingsController.setHighContrast(bool)`; `NiceTvTheme.highContrastLight(Color)` / `NiceTvTheme.highContrastDark(Color)`; a settings `SwitchListTile`.

- [ ] **Step 1: Add the field + setter to `AppSettings` / `SettingsController`**

In `lib/features/settings/data/settings_controller.dart`:
- Add to the constructor + `final` list (after `playbackSpeed`):
```dart
    this.highContrast = false,
```
```dart
  final bool highContrast;
```
- Add to `copyWith`:
```dart
    bool? highContrast,
```
```dart
      highContrast: highContrast ?? this.highContrast,
```
- Add to `SettingsController.build`:
```dart
      highContrast: storage.highContrast,
```
- Add the setter (after `setPlaybackSpeed`):
```dart
  Future<void> setHighContrast(bool value) async {
    await ref.read(settingsStorageProvider).setHighContrast(value);
    state = state.copyWith(highContrast: value);
  }
```

- [ ] **Step 2: Add the storage key + accessors**

In `lib/core/storage/app_storage.dart`, add the key:
```dart
  static const highContrastKey = 'high_contrast';
```
And accessors:
```dart
  bool get highContrast => _prefs.getBool(highContrastKey) ?? false;

  Future<void> setHighContrast(bool value) =>
      _prefs.setBool(highContrastKey, value);
```

- [ ] **Step 3: Add high-contrast themes**

In `lib/core/theme/nice_tv_theme.dart`, add after `dark`:
```dart
  static ThemeData highContrastLight(Color seed) {
    final scheme = ColorScheme.highContrastLight(seedColor: seed);
    return _base(scheme);
  }

  static ThemeData highContrastDark(Color seed) {
    final scheme = ColorScheme.highContrastDark(
      seedColor: seed,
      surface: const Color(0xFF0E1116),
    );
    return _base(scheme);
  }
```

- [ ] **Step 4: Honor the flag in `main.dart`**

Replace the `theme:` / `darkTheme:` lines (lines 70–71):
```dart
      theme: settings.highContrast
          ? NiceTvTheme.highContrastLight(settings.accent)
          : NiceTvTheme.light(settings.accent),
      darkTheme: settings.highContrast
          ? NiceTvTheme.highContrastDark(settings.accent)
          : NiceTvTheme.dark(settings.accent),
```

- [ ] **Step 5: Add the settings toggle**

In `lib/features/settings/presentation/settings_screen.dart`, inside the `ListView` children immediately after the accent `Wrap` (after line 97), insert:
```dart
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
```

- [ ] **Step 6: Run analyze and commit**

Run: `flutter analyze lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/core/theme/nice_tv_theme.dart lib/main.dart lib/features/settings/presentation/settings_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/core/theme/nice_tv_theme.dart lib/main.dart lib/features/settings/presentation/settings_screen.dart`
Run: `git add lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/core/theme/nice_tv_theme.dart lib/main.dart lib/features/settings/presentation/settings_screen.dart`
Run: `git commit -m "feat: add high-contrast theme option"`

---

### Task 2: Do-Not-Disturb quiet hours

**Files:**
- Create: `lib/features/settings/data/quiet_hours.dart`
- Modify: `lib/features/settings/data/settings_controller.dart`
- Modify: `lib/core/storage/app_storage.dart`
- Modify: `lib/features/notifications/data/notifications_inbox.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Test: `test/unit/quiet_hours_test.dart`

**Interfaces:**
- Consumes: `settingsControllerProvider` in `_ingestFresh`.
- Produces: `bool isInQuietHours(DateTime now, int startMinutes, int endMinutes)`; `AppSettings.quietHoursEnabled` (`bool`), `quietHoursStart` (`int` minutes, default 22*60), `quietHoursEnd` (`int` minutes, default 7*60); `SettingsController.setQuietHoursEnabled(bool)` / `setQuietHours({required int start, required int end})`; `SettingsStorage` keys `quiet_hours_enabled` / `quiet_hours_start` / `quiet_hours_end`. Push is suppressed (inbox still records the item) during quiet hours.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/quiet_hours_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/settings/data/quiet_hours.dart';

void main() {
  group('isInQuietHours', () {
    DateTime at(int hour, int minute) => DateTime(2026, 8, 20, hour, minute);

    test('inside same-day window', () {
      expect(isInQuietHours(at(23, 0), 22 * 60, 7 * 60), isTrue);
      expect(isInQuietHours(at(6, 59), 22 * 60, 7 * 60), isTrue);
    });

    test('outside same-day window', () {
      expect(isInQuietHours(at(12, 0), 22 * 60, 7 * 60), isFalse);
    });

    test('wrap-around window crosses midnight', () {
      expect(isInQuietHours(at(1, 0), 22 * 60, 7 * 60), isTrue);
      expect(isInQuietHours(at(23, 30), 22 * 60, 7 * 60), isTrue);
    });

    test('non-wrapping window', () {
      expect(isInQuietHours(at(9, 0), 8 * 60, 10 * 60), isTrue);
      expect(isInQuietHours(at(7, 0), 8 * 60, 10 * 60), isFalse);
    });

    test('equal start/end means no quiet hours', () {
      expect(isInQuietHours(at(9, 0), 9 * 60, 9 * 60), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/quiet_hours_test.dart`
Expected: FAIL — `quiet_hours.dart` not defined.

- [ ] **Step 3: Implement the helper**

Create `lib/features/settings/data/quiet_hours.dart`:

```dart
/// True when [now]'s clock time falls within [startMinutes]–[endMinutes]
/// (minutes since midnight). Handles windows that wrap across midnight.
bool isInQuietHours(DateTime now, int startMinutes, int endMinutes) {
  if (startMinutes == endMinutes) return false;
  final current = now.hour * 60 + now.minute;
  if (startMinutes < endMinutes) {
    return current >= startMinutes && current < endMinutes;
  }
  return current >= startMinutes || current < endMinutes;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/quiet_hours_test.dart`
Expected: PASS.

- [ ] **Step 5: Add fields + setters to `AppSettings` / `SettingsController`**

In `lib/features/settings/data/settings_controller.dart`:
- Add to the constructor + fields (after `highContrast`):
```dart
    this.quietHoursEnabled = false,
    this.quietHoursStart = 22 * 60,
    this.quietHoursEnd = 7 * 60,
```
```dart
  final bool quietHoursEnabled;
  final int quietHoursStart;
  final int quietHoursEnd;
```
- Add to `copyWith`:
```dart
    bool? quietHoursEnabled,
    int? quietHoursStart,
    int? quietHoursEnd,
```
```dart
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
```
- Add to `SettingsController.build`:
```dart
      quietHoursEnabled: storage.quietHoursEnabled,
      quietHoursStart: storage.quietHoursStart,
      quietHoursEnd: storage.quietHoursEnd,
```
- Add setters (after `setHighContrast`):
```dart
  Future<void> setQuietHoursEnabled(bool value) async {
    await ref.read(settingsStorageProvider).setQuietHoursEnabled(value);
    state = state.copyWith(quietHoursEnabled: value);
  }

  Future<void> setQuietHours({
    required int start,
    required int end,
  }) async {
    await ref
        .read(settingsStorageProvider)
        .setQuietHours(start: start, end: end);
    state = state.copyWith(quietHoursStart: start, quietHoursEnd: end);
  }
```

- [ ] **Step 6: Add storage keys + accessors**

In `lib/core/storage/app_storage.dart`, add keys:
```dart
  static const quietHoursEnabledKey = 'quiet_hours_enabled';
  static const quietHoursStartKey = 'quiet_hours_start';
  static const quietHoursEndKey = 'quiet_hours_end';
```
And accessors:
```dart
  bool get quietHoursEnabled =>
      _prefs.getBool(quietHoursEnabledKey) ?? false;

  Future<void> setQuietHoursEnabled(bool value) =>
      _prefs.setBool(quietHoursEnabledKey, value);

  int get quietHoursStart => _prefs.getInt(quietHoursStartKey) ?? 22 * 60;

  int get quietHoursEnd => _prefs.getInt(quietHoursEndKey) ?? 7 * 60;

  Future<void> setQuietHours({required int start, required int end}) async {
    await _prefs.setInt(quietHoursStartKey, start);
    await _prefs.setInt(quietHoursEndKey, end);
  }
```

- [ ] **Step 7: Gate push notifications on quiet hours**

In `lib/features/notifications/data/notifications_inbox.dart`, in `_ingestFresh` (lines 260–265), replace the push loop with a gated version:

```dart
    if (notify) {
      final settings = ref.read(settingsControllerProvider);
      final inQuiet = settings.quietHoursEnabled &&
          isInQuietHours(
            DateTime.now(),
            settings.quietHoursStart,
            settings.quietHoursEnd,
          );
      final push = ref.read(localPushServiceProvider);
      for (final item in novel) {
        if (inQuiet) continue;
        await push.showWentLive(item);
      }
    }
```

Add the import:
```dart
import 'package:nice_tv/features/settings/data/quiet_hours.dart';
```

Note: inbox items are still recorded during quiet hours; only the OS push is suppressed.

- [ ] **Step 8: Add the settings UI**

In `lib/features/settings/presentation/settings_screen.dart`, add a stateful-friendly section. Because `SettingsScreen` is a `ConsumerWidget`, wrap the DND block in a `Consumer` so time-picker state is local. Insert a new `Notifications` section right before the `Player backend` text (after the Discovery sort `ListTile`, around line 211):

```dart
          const SizedBox(height: 24),
          Text('Notifications', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Do Not Disturb'),
            subtitle: const Text('Silence live-alert notifications during quiet hours'),
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
```

Add the `_formatTime` helper as a top-level function in `settings_screen.dart`:

```dart
String _formatTime(int minutesSinceMidnight) {
  final h = minutesSinceMidnight ~/ 60;
  final m = minutesSinceMidnight % 60;
  final hour12 = h % 12 == 0 ? 12 : h % 12;
  final ampm = h < 12 ? 'AM' : 'PM';
  return '$hour12:${m.toString().padLeft(2, '0')} $ampm';
}
```

- [ ] **Step 9: Run analyze and commit**

Run: `flutter analyze lib/features/settings/data/quiet_hours.dart lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/features/notifications/data/notifications_inbox.dart lib/features/settings/presentation/settings_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/settings/data/quiet_hours.dart lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/features/notifications/data/notifications_inbox.dart lib/features/settings/presentation/settings_screen.dart test/unit/quiet_hours_test.dart`
Run: `git add lib/features/settings/data/quiet_hours.dart lib/features/settings/data/settings_controller.dart lib/core/storage/app_storage.dart lib/features/notifications/data/notifications_inbox.dart lib/features/settings/presentation/settings_screen.dart test/unit/quiet_hours_test.dart`
Run: `git commit -m "feat: add Do Not Disturb quiet hours for live alerts"`

---

### Task 3: Per-channel notification mutes

**Files:**
- Create: `lib/features/notifications/data/muted_channels_store.dart`
- Modify: `lib/features/notifications/data/notifications_inbox.dart`
- Modify: `lib/features/notifications/presentation/notifications_screen.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Test: `test/unit/muted_channels_store_test.dart`

**Interfaces:**
- Consumes: `sharedPreferencesProvider`, `settingsControllerProvider` in `_ingestFresh`.
- Produces: `class MutedChannelsStore { Set<String> read(); Future<void> mute(String login); Future<void> unmute(String login); }` (key `muted_channels`, logins lowercased); `class MutedChannelsController extends Notifier<Set<String>>` with `mute`/`unmute`; `mutedChannelsControllerProvider`. Push suppressed for muted channels (inbox still records).

- [ ] **Step 1: Write the failing tests**

Create `test/unit/muted_channels_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('MutedChannelsStore', () {
    test('round-trips muted channels through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MutedChannelsStore(prefs);
      expect(store.read(), isEmpty);

      await store.mute('bigstreamer');
      await store.mute('smallstreamer');
      expect(store.read(), {'bigstreamer', 'smallstreamer'});

      await store.unmute('bigstreamer');
      expect(store.read(), {'smallstreamer'});
    });

    test('stores logins lowercased', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = MutedChannelsStore(prefs);
      await store.mute('BigStreamer');
      expect(store.read(), {'bigstreamer'});
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/muted_channels_store_test.dart`
Expected: FAIL — `MutedChannelsStore` not defined.

- [ ] **Step 3: Implement the store + controller**

Create `lib/features/notifications/data/muted_channels_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MutedChannelsStore {
  MutedChannelsStore(this._prefs);

  static const _key = 'muted_channels';

  final SharedPreferences _prefs;

  Set<String> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.map((e) => e.toLowerCase()).toSet();
  }

  Future<void> mute(String login) async {
    final next = {...read(), login.toLowerCase()};
    await _prefs.setStringList(_key, next.toList());
  }

  Future<void> unmute(String login) async {
    final next = {...read()}..remove(login.toLowerCase());
    await _prefs.setStringList(_key, next.toList());
  }
}

class MutedChannelsController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    return MutedChannelsStore(ref.watch(sharedPreferencesProvider)).read();
  }

  Future<void> mute(String login) async {
    final store = MutedChannelsStore(ref.watch(sharedPreferencesProvider));
    await store.mute(login);
    state = store.read();
  }

  Future<void> unmute(String login) async {
    final store = MutedChannelsStore(ref.watch(sharedPreferencesProvider));
    await store.unmute(login);
    state = store.read();
  }
}

final mutedChannelsControllerProvider =
    NotifierProvider<MutedChannelsController, Set<String>>(
      MutedChannelsController.new,
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/muted_channels_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Gate push notifications on muted channels**

In `lib/features/notifications/data/notifications_inbox.dart`, in `_ingestFresh`, extend the gated push loop from Task 2 to also skip muted channels:

```dart
    if (notify) {
      final settings = ref.read(settingsControllerProvider);
      final muted = ref.read(mutedChannelsControllerProvider);
      final inQuiet = settings.quietHoursEnabled &&
          isInQuietHours(
            DateTime.now(),
            settings.quietHoursStart,
            settings.quietHoursEnd,
          );
      final push = ref.read(localPushServiceProvider);
      for (final item in novel) {
        if (inQuiet || muted.contains(item.userLogin.toLowerCase())) continue;
        await push.showWentLive(item);
      }
    }
```

Add the import:
```dart
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
```

- [ ] **Step 6: Add the mute toggle to the notifications screen**

In `lib/features/notifications/presentation/notifications_screen.dart`:
- Add the import:
```dart
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
```
- Watch the muted set near the top of `build`:
```dart
    final muted = ref.watch(mutedChannelsControllerProvider);
```
- Replace the `trailing: Text(_relative(item.wentLiveAt), ...)` (lines 172–174) with a trailing row containing the time and a mute toggle:

```dart
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
                            final notifier = ref
                                .read(mutedChannelsControllerProvider.notifier);
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
```

- [ ] **Step 7: Add a muted-channels management section to settings**

In `lib/features/settings/presentation/settings_screen.dart`:
- Add the import:
```dart
import 'package:nice_tv/features/notifications/data/muted_channels_store.dart';
```
- Insert a `Muted channels` block right after the DND `Row` from Task 2 (inside the `Notifications` section):

```dart
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
```

- [ ] **Step 8: Run analyze and commit**

Run: `flutter analyze lib/features/notifications/data/muted_channels_store.dart lib/features/notifications/data/notifications_inbox.dart lib/features/notifications/presentation/notifications_screen.dart lib/features/settings/presentation/settings_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/notifications/data/muted_channels_store.dart lib/features/notifications/data/notifications_inbox.dart lib/features/notifications/presentation/notifications_screen.dart lib/features/settings/presentation/settings_screen.dart test/unit/muted_channels_store_test.dart`
Run: `git add lib/features/notifications/data/muted_channels_store.dart lib/features/notifications/data/notifications_inbox.dart lib/features/notifications/presentation/notifications_screen.dart lib/features/settings/presentation/settings_screen.dart test/unit/muted_channels_store_test.dart`
Run: `git commit -m "feat: add per-channel notification mutes"`

---

### Task 4: Export / Import settings

**Files:**
- Create: `lib/features/settings/data/settings_export.dart`
- Modify: `lib/features/settings/data/settings_controller.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`
- Test: `test/unit/settings_export_test.dart`

**Interfaces:**
- Consumes: `AppSettings`, `SettingsStorage`, `settingsControllerProvider`, `Clipboard`.
- Produces: `String buildExportPayload(AppSettings settings)`; `AppSettings? parseExportPayload(String raw)` (returns `null` when malformed or version mismatch); `SettingsController.applySettings(AppSettings next)`; a `Backup` settings section with Export/Import buttons using `Clipboard.setData`/`Clipboard.getData`.

- [ ] **Step 1: Write the failing tests**

Create `test/unit/settings_export_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/settings/data/settings_export.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

void main() {
  group('settings export', () {
    test('round-trips all fields', () {
      final settings = AppSettings(
        themeMode: ThemeMode.dark,
        accentArgb: 0xFF9146FF,
        chatDensity: 0,
        videoQuality: '1080p',
        discoveryLanguage: 'en',
        discoveryHideMature: true,
        discoverySortOrder: 'recentlyStarted',
        videoVolume: 0.5,
        videoMuted: true,
        playbackSpeed: 1.25,
        highContrast: true,
        quietHoursEnabled: true,
        quietHoursStart: 23 * 60,
        quietHoursEnd: 6 * 60,
      );

      final restored = parseExportPayload(buildExportPayload(settings));
      expect(restored, isNotNull);
      expect(restored!.themeMode, ThemeMode.dark);
      expect(restored.accentArgb, 0xFF9146FF);
      expect(restored.chatDensity, 0);
      expect(restored.videoQuality, '1080p');
      expect(restored.discoveryLanguage, 'en');
      expect(restored.discoveryHideMature, isTrue);
      expect(restored.discoverySortOrder, 'recentlyStarted');
      expect(restored.videoVolume, 0.5);
      expect(restored.videoMuted, isTrue);
      expect(restored.playbackSpeed, 1.25);
      expect(restored.highContrast, isTrue);
      expect(restored.quietHoursEnabled, isTrue);
      expect(restored.quietHoursStart, 23 * 60);
      expect(restored.quietHoursEnd, 6 * 60);
    });

    test('defaults for omitted fields', () {
      final restored = parseExportPayload(
        '{"version":1,"themeMode":"system",'
        '"accentArgb":4280844966,"chatDensity":1,"videoQuality":"auto"}',
      );
      expect(restored, isNotNull);
      expect(restored!.discoveryHideMature, isFalse);
      expect(restored.videoVolume, 0.7);
      expect(restored.highContrast, isFalse);
      expect(restored.quietHoursEnabled, isFalse);
    });

    test('returns null for malformed input', () {
      expect(parseExportPayload('not json'), isNull);
      expect(parseExportPayload('{"version":2}'), isNull);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/settings_export_test.dart`
Expected: FAIL — `settings_export.dart` not defined.

- [ ] **Step 3: Implement export/parse**

Create `lib/features/settings/data/settings_export.dart`:

```dart
import 'dart:convert';

import 'package:nice_tv/features/settings/data/settings_controller.dart';

String buildExportPayload(AppSettings settings) {
  return jsonEncode({
    'version': 1,
    'themeMode': AppSettings.themeModeToString(settings.themeMode),
    'accentArgb': settings.accentArgb,
    'chatDensity': settings.chatDensity,
    'videoQuality': settings.videoQuality,
    'discoveryLanguage': settings.discoveryLanguage,
    'discoveryHideMature': settings.discoveryHideMature,
    'discoverySortOrder': settings.discoverySortOrder,
    'videoVolume': settings.videoVolume,
    'videoMuted': settings.videoMuted,
    'playbackSpeed': settings.playbackSpeed,
    'highContrast': settings.highContrast,
    'quietHoursEnabled': settings.quietHoursEnabled,
    'quietHoursStart': settings.quietHoursStart,
    'quietHoursEnd': settings.quietHoursEnd,
  });
}

AppSettings? parseExportPayload(String raw) {
  try {
    final json = jsonDecode(raw) as Map<String, dynamic>;
    if (json['version'] != 1) return null;
    return AppSettings(
      themeMode: AppSettings.parseThemeMode(
        json['themeMode'] as String? ?? 'system',
      ),
      accentArgb: json['accentArgb'] as int? ?? 0xFF1FA2A6,
      chatDensity: json['chatDensity'] as int? ?? 1,
      videoQuality: json['videoQuality'] as String? ?? 'auto',
      discoveryLanguage: json['discoveryLanguage'] as String?,
      discoveryHideMature: json['discoveryHideMature'] as bool? ?? false,
      discoverySortOrder:
          json['discoverySortOrder'] as String? ?? 'viewerCount',
      videoVolume: (json['videoVolume'] as num?)?.toDouble() ?? 0.7,
      videoMuted: json['videoMuted'] as bool? ?? false,
      playbackSpeed: (json['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      highContrast: json['highContrast'] as bool? ?? false,
      quietHoursEnabled: json['quietHoursEnabled'] as bool? ?? false,
      quietHoursStart: json['quietHoursStart'] as int? ?? 22 * 60,
      quietHoursEnd: json['quietHoursEnd'] as int? ?? 7 * 60,
    );
  } on Object {
    return null;
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/settings_export_test.dart`
Expected: PASS.

- [ ] **Step 5: Add `applySettings` to `SettingsController`**

In `lib/features/settings/data/settings_controller.dart`, add after `setHighContrast`:

```dart
  Future<void> applySettings(AppSettings next) async {
    final storage = ref.read(settingsStorageProvider);
    await storage.setThemeMode(AppSettings.themeModeToString(next.themeMode));
    await storage.setAccentArgb(next.accentArgb);
    await storage.setChatDensity(next.chatDensity);
    await storage.setVideoQuality(next.videoQuality);
    await storage.setDiscoveryLanguage(next.discoveryLanguage);
    await storage.setDiscoveryHideMature(next.discoveryHideMature);
    await storage.setDiscoverySortOrder(next.discoverySortOrder);
    await storage.setVideoVolume(next.videoVolume);
    await storage.setVideoMuted(next.videoMuted);
    await storage.setPlaybackSpeed(next.playbackSpeed);
    await storage.setHighContrast(next.highContrast);
    await storage.setQuietHoursEnabled(next.quietHoursEnabled);
    await storage.setQuietHours(
      start: next.quietHoursStart,
      end: next.quietHoursEnd,
    );
    state = next;
  }
```

- [ ] **Step 6: Add the Backup section to the settings screen**

In `lib/features/settings/presentation/settings_screen.dart`:
- Add the import:
```dart
import 'package:flutter/services.dart';
import 'package:nice_tv/features/settings/data/settings_export.dart';
```
- Insert a `Backup` section at the end of the `ListView` children (after the Player-backend note, around line 247):

```dart
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
```

- [ ] **Step 7: Run analyze and commit**

Run: `flutter analyze lib/features/settings/data/settings_export.dart lib/features/settings/data/settings_controller.dart lib/features/settings/presentation/settings_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/settings/data/settings_export.dart lib/features/settings/data/settings_controller.dart lib/features/settings/presentation/settings_screen.dart test/unit/settings_export_test.dart`
Run: `git add lib/features/settings/data/settings_export.dart lib/features/settings/data/settings_controller.dart lib/features/settings/presentation/settings_screen.dart test/unit/settings_export_test.dart`
Run: `git commit -m "feat: export and import settings via clipboard"`

---

### Task 5: Full verification

**Files:**
- All files touched above.

- [x] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass (existing + new).

- [x] **Step 2: Run analyzer on the whole repo**

Run: `flutter analyze`
Expected: No issues found.

- [x] **Step 3: Format**

Run: `dart format .`
Expected: No diffs (already formatted).

---

### Task 5 verification results

- `flutter test`: 52 tests passed.
- `flutter analyze`: No issues found.
- `dart format .`: 82 files, 0 changed.
- Note: the plan's `ColorScheme.highContrastLight(seedColor:)` / `highContrastDark(seedColor:)` APIs do not exist in this Flutter SDK (they use fixed palettes). Implemented instead as `ColorScheme.fromSeed(seedColor: ..., contrastLevel: 1.0)` in `NiceTvTheme.highContrastLight/Dark`.

## Self-Review Checklist

- Spec coverage: 8.1 Export/Import settings (Task 4), 9.2 High-contrast theme (Task 1), 6.3 DND/quiet hours (Task 2), 6.1 Per-channel notification toggles (Task 3). All covered.
- No placeholders: every task has concrete code and exact commands.
- Type consistency: `isInQuietHours`, `buildExportPayload`, `parseExportPayload`, `applySettings`, `MutedChannelsStore.read/mute/unmute`, `MutedChannelsController.mute/unmute`, `NiceTvTheme.highContrastLight/Dark` are each defined once and reused consistently.
- Both push-gates (quiet hours + muted channels) suppress the OS notification but still record inbox items, matching the "keep inbox, silence push" intent.
- Export/import covers all `AppSettings` fields added in Tasks 1–2, so round-tripping an exported payload is lossless.