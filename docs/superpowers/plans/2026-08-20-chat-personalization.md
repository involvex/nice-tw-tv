# Chat Personalization & Overrides Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add chat timestamps toggle, chat font size & family settings, link protection / spoiler toggle, and per-channel player & theme overrides.

**Architecture:** Extend `settings` and `chat` features. Pure helpers and preference mappings live in `data/`, UI controls in `presentation/`.

**Tech Stack:** Flutter/Dart, Riverpod (`Notifier`), `shared_preferences`, `google_fonts`.

## Global Constraints

- Flutter SDK `^3.13.0-282.1.beta`, Dart latest stable.
- Use `bun` only for non-Flutter tasks; this is a Flutter repo so use `flutter pub get`, `flutter test`, `flutter analyze`, `dart format .`.
- No new third-party dependencies.
- Follow existing naming: files `snake_case.dart`, classes `PascalCase`, private members `_`-prefixed.
- Follow the feature-based architecture: logic in `data/`, UI in `presentation/`.
- Use Riverpod `Notifier`/`FutureProvider`, never `ChangeNotifier`.
- Commit after every task with conventional-commit messages (`feat:`).

---

## File Structure

- Modify: `lib/features/settings/data/settings_controller.dart` — chat timestamps, font size, link protection flags.
- Modify: `lib/core/storage/app_storage.dart` — storage keys & getters/setters.
- Modify: `lib/features/chat/presentation/chat_panel.dart` — render timestamps, apply font size, mask links.
- Modify: `lib/features/settings/presentation/settings_screen.dart` — settings UI toggles.
- Modify: `lib/features/settings/data/layout_profile.dart` — per-channel theme/player overrides.
- Test: `test/unit/chat_personalization_test.dart`

---

### Task 1: Chat Timestamps & Link Protection

**Files:**
- Modify: `lib/features/settings/data/settings_controller.dart`
- Modify: `lib/core/storage/app_storage.dart`
- Modify: `lib/features/chat/presentation/chat_panel.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Produces: `AppSettings.chatTimestamps` (`bool`), `AppSettings.maskLinks` (`bool`).

- [ ] **Step 1: Add settings fields, storage keys, chat panel rendering & settings toggles. Test & commit.**

---

### Task 2: Chat Font Size & Family

**Files:**
- Modify: `lib/features/settings/data/settings_controller.dart`
- Modify: `lib/features/chat/presentation/chat_panel.dart`
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Produces: `AppSettings.chatFontSizeScale` (`double`), `AppSettings.chatFontFamily` (`String`).

- [ ] **Step 1: Add font settings, apply to chat message tiles, add settings controls, test & commit.**

---

### Task 3: Per-Channel Player & Theme Overrides

**Files:**
- Modify: `lib/features/settings/data/layout_profile.dart`
- Modify: `lib/features/watch/presentation/watch_screen.dart`

**Interfaces:**
- Produces: Extended `StreamerLayoutProfile` with optional channel accent color or quality override.

- [ ] **Step 1: Extend layout profile model, wire channel-specific overrides into watch screen, test & commit.**

---

### Task 4: Full Verification

- [ ] **Step 1: Run `flutter test`, `flutter analyze`, and `dart format .`. Commit.**
