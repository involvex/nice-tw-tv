---
title: Architecture
nav_order: 3
---

# Architecture

Nice TV follows a feature-based layered architecture using Flutter and Riverpod for state management.

## Project Structure

```
lib/
├── main.dart                    # App entry point
├── core/
│   ├── env/                     # Environment configuration
│   │   └── app_env.dart         # Twitch API credentials
│   ├── network/                 # HTTP clients & providers
│   │   └── dio_providers.dart   # Dio instance providers
│   ├── routing/                 # Navigation setup
│   │   └── app_router.dart      # GoRouter configuration
│   ├── storage/                 # Local storage
│   │   └── app_storage.dart     # Secure & shared storage
│   └── theme/                   # App theming
│       └── nice_tv_theme.dart   # Light/dark theme definitions
├── features/
│   ├── auth/                    # Authentication (OAuth)
│   ├── chat/                    # IRC chat
│   ├── emotes/                  # Emote handling (BTTV, FFZ, 7TV)
│   ├── home/                    # Home feed & categories
│   ├── notifications/           # Notifications
│   ├── profile/                 # Channel profiles
│   ├── search/                  # Search functionality
│   ├── settings/                # App settings
│   ├── vod/                     # VOD playback
│   └── watch/                   # Live stream watching
test/
├── unit/                        # Unit tests
└── widget_test.dart             # Widget tests
```

## Layers

Each feature is organized into two layers:

### Data Layer (`data/`)

- **Models** — Dart data classes representing API responses
- **Repositories** — Business logic for fetching and caching data
- **Services** — HTTP clients (Dio), WebSockets, storage adapters

### Presentation Layer (`presentation/`)

- **Screens** — Top-level page widgets
- **Widgets** — Reusable UI components

## State Management: Riverpod

**Provider Types:**

```dart
// Simple state
final myProvider = StateProvider<Type>((ref) => initialValue);

// Complex state with Notifier
final myNotifierProvider = NotifierProvider<MyNotifier, MyState>(
  MyNotifier.new,
);

// Auto-dispose (cleaned up when no longer listened)
final myAutoDisposeProvider = NotifierProvider.autoDispose<MyNotifier, MyState>(
  MyNotifier.new,
);

// Future-based
final myFutureProvider = FutureProvider<Type>((ref) async {
  return fetchData();
});
```

**Best Practices:**
- Prefer `Notifier` over `ChangeNotifier` for new code
- Use `ref.watch()` for reactive dependencies
- Use `ref.read()` for one-time reads
- Use `ref.onDispose()` for cleanup
- Keep providers small and focused

## Navigation: GoRouter

Routes are defined in `lib/core/routing/app_router.dart`:

- `StatefulShellRoute.indexedStack` for bottom navigation
- Named routes with path parameters
- Query parameters for optional data

## Networking

- **Dio** — HTTP client for Twitch Helix API (`https://api.twitch.tv`)
- **web_socket_channel** — WebSocket for IRC chat (`wss://irc-ws.chat.twitch.tv:443`)

## Media

- **media_kit** — Native video playback (experimental HLS)
- **webview_flutter** — Twitch embed player (default)

## Storage

- **flutter_secure_storage** — Secure token storage (OAuth tokens)
- **shared_preferences** — User preferences (theme, settings)

## Data Flow

```
UI (Screen/Widget)
    ↓ watches
State (Notifier/Provider)
    ↓ calls
Repository
    ↓ uses
Service (Dio/WebSocket)
    ↓ calls
External API (Twitch Helix/IRC)
```
