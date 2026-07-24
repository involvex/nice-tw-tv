# Agent Instructions for Nice TV

## Project Overview

**Nice TV** is a modern Android-first Twitch client built with Flutter. It provides a clean-room implementation inspired by the architecture of third-party clients like Frosty — not a fork.

### Core Features
- Twitch frontpage: popular live streams + following feed with infinite scroll
- VOD shelf from popular channels' recent archives
- Live/VOD watch via Twitch embed JS bridge **or** experimental native HLS
- Android Picture-in-Picture
- Per-streamer layout profiles (chat placement, density, split ratio, player)
- IRC chat with Twitch, BetterTTV, FrankerFaceZ, and 7TV emotes
- Live 7TV emote-set websocket updates
- Emote autocomplete and picker
- Light / dark / system themes with accent customization
- Chat density and default stream quality settings
- Twitch OAuth (redirect `https://twitch.tv/login`)

---

## Technologies & Dependencies

### Core Framework
- **Flutter** (SDK ^3.13.0-282.1.beta)
- **Dart** (latest stable)

### State Management
- **flutter_riverpod** (^3.3.2) — Primary state management solution
  - Use `Notifier` / `AsyncNotifier` for complex state
  - Use `Provider` / `StateProvider` for simple state
  - Use `NotifierProvider.autoDispose` for one-time listeners

### Navigation
- **go_router** (^17.3.0) — Declarative routing
  - Uses `StatefulShellRoute.indexedStack` for bottom navigation
  - Route definitions in `lib/core/routing/app_router.dart`

### Networking
- **dio** (^5.10.0) — HTTP client for Twitch Helix API
  - Base URL: `https://api.twitch.tv`
  - Interceptors for auth token injection
- **web_socket_channel** (^3.0.3) — WebSocket for IRC chat
  - Twitch IRC endpoint: `wss://irc-ws.chat.twitch.tv:443`

### Storage
- **flutter_secure_storage** (^10.3.1) — Secure token storage (OAuth tokens)
- **shared_preferences** (^2.5.5) — User preferences (theme, settings)

### Media
- **media_kit** (^1.2.6) — Native video playback
- **media_kit_video** (^2.0.1) — Video widget
- **media_kit_libs_video** (^1.0.7) — Platform-specific libraries
- **webview_flutter** (^4.14.1) — Twitch embed player

### UI & Theming
- **google_fonts** (^8.2.0) — Custom fonts
- **cached_network_image** (^3.4.1) — Image caching
- **cupertino_icons** (^1.0.8) — iOS-style icons
- **flutter_lints** (^6.0.0) — Lint rules

### Environment
- **flutter_dotenv** (^6.0.1) — Environment variables from `.env`

---

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
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   └── presentation/
│   │       └── login_screen.dart
│   ├── chat/                    # IRC chat
│   │   ├── data/
│   │   │   ├── chat_client.dart
│   │   │   └── irc_message.dart
│   │   └── presentation/
│   │       └── chat_panel.dart
│   ├── emotes/                  # Emote handling (BTTV, FFZ, 7TV)
│   │   ├── data/
│   │   │   ├── emote.dart
│   │   │   ├── emote_repository.dart
│   │   │   └── seventv_events.dart
│   │   └── presentation/
│   ├── home/                    # Home feed & categories
│   │   ├── data/
│   │   │   ├── helix_repository.dart
│   │   │   ├── twitch_models.dart
│   │   │   └── twitch_stream.dart
│   │   └── presentation/
│   │       ├── autoplay_feed.dart
│   │       ├── following_screen.dart
│   │       └── home_screen.dart
│   ├── notifications/           # Notifications
│   ├── profile/                 # Channel profiles
│   ├── search/                  # Search functionality
│   ├── settings/                # App settings
│   │   ├── data/
│   │   │   ├── layout_profile.dart
│   │   │   └── settings_controller.dart
│   │   └── presentation/
│   │       └── settings_screen.dart
│   ├── vod/                     # VOD playback
│   │   ├── data/
│   │   │   └── twitch_vod.dart
│   │   └── presentation/
│   │       └── vod_screen.dart
│   └── watch/                   # Live stream watching
│       ├── data/
│       │   ├── hls_resolver.dart
│       │   └── pip_service.dart
│       └── presentation/
│           ├── native_hls_player.dart
│           ├── twitch_embed_player.dart
│           └── watch_screen.dart
test/
├── unit/                        # Unit tests
│   ├── irc_and_emote_test.dart
│   └── layout_profile_test.dart
└── widget_test.dart             # Widget tests
```

---

## Useful Commands

### Development
```bash
# Install dependencies
flutter pub get

# Run the app (debug mode)
flutter run

# Run on specific device
flutter run -d <device_id>

# Hot reload (while running)
# Press 'r' in terminal
# Press 'R' for hot restart
```

### Code Quality
```bash
# Format code
dart format .

# Analyze for issues
flutter analyze

# Run tests
flutter test

# Run specific test file
flutter test test/unit/irc_and_emote_test.dart

# Run with coverage
flutter test --coverage
```

### Build
```bash
# Build APK (Android)
flutter build apk --release

# Build App Bundle (Android)
flutter build appbundle --release

# Build iOS
flutter build ios --release

# Clean build artifacts
flutter clean
flutter pub get
```

### Dependencies
```bash
# Add a package
flutter pub add <package_name>

# Add dev dependency
flutter pub add --dev <package_name>

# Remove a package
flutter pub remove <package_name>

# Upgrade all dependencies
flutter pub upgrade

# Check for outdated packages
flutter pub outdated
```

---

## Architecture & Design Patterns

### Feature-Based Architecture
Each feature is self-contained with its own:
- `data/` — Models, repositories, API clients
- `presentation/` — Screens, widgets, UI components

### State Management with Riverpod

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

### Routing with GoRouter

Routes are defined in `lib/core/routing/app_router.dart`:
- `StatefulShellRoute.indexedStack` for bottom navigation
- Named routes with path parameters
- Query parameters for optional data

### Data Flow
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

---

## Coding Standards

### Dart/Flutter Style
- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dart format .` before committing
- Run `flutter analyze` to check for issues
- Prefer `const` constructors where possible
- Use `final` for immutable variables
- Prefer `late` for late-initialized variables

### Naming Conventions
- **Files:** `snake_case.dart` (e.g., `chat_client.dart`)
- **Classes:** `PascalCase` (e.g., `ChatClient`, `HelixRepository`)
- **Variables/Functions:** `camelCase` (e.g., `chatMessage`, `getUserProfile`)
- **Private members:** Prefix with `_` (e.g., `_controller`, `_send()`)
- **Providers:** Suffix with `Provider` (e.g., `chatControllerProvider`)
- **Constants:** `camelCase` or `lowerCamelCase` (e.g., `clientId`)

### File Organization
- One class per file (recommended)
- Group related classes in the same directory
- Keep `data/` and `presentation/` separate
- Use `core/` for shared utilities

### Error Handling
```dart
// Use try-catch with Object catch
try {
  final result = await apiCall();
} on Object catch (e) {
  // Handle error
  state = state.copyWith(error: e.toString());
}

// Use specific exceptions when possible
on FormatException catch (e) {
  // Handle parse error
}
```

### Null Safety
- Use `?` for nullable types
- Use `!` only when you're certain the value is not null
- Prefer `?? defaultValue` over null checks
- Use `late` for late-initialized non-nullable fields

---

## Testing Guidelines

### Unit Tests
- Location: `test/unit/`
- Test data layer: repositories, models, utilities
- Mock external dependencies

### Widget Tests
- Location: `test/`
- Test UI rendering and interactions
- Use `WidgetTester` for pump and find

### Test Patterns
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  setUp(() {
    // Setup before each test
  });

  tearDown(() {
    // Cleanup after each test
  });

  test('description', () {
    // Arrange
    // Act
    // Assert
  });

  testWidgets('widget test', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MyWidget(),
      ),
    );
    await tester.pump();
    expect(find.text('Hello'), findsOneWidget);
  });
}
```

### Mocking
- Use `mockito` or manual mocks
- Override providers in tests:
```dart
final overrides = [
  myProvider.overrideWithValue(mockValue),
];
```

---

## Security Considerations

### Environment Variables
- **NEVER** commit `.env` files
- Use `.env.example` as a template
- Rotate credentials regularly

### Token Storage
- Use `flutter_secure_storage` for OAuth tokens
- Never store tokens in plain text
- Clear tokens on logout

### API Keys
- `CLIENT_ID` is public (safe for client apps)
- `SECRET` should only be used for client-credentials flow
- **NEVER** ship `SECRET` in production release builds without a backend proxy

### OAuth Scopes
```dart
static const oauthScopes = [
  'chat:read',
  'chat:edit',
  'user:read:follows',
  'user:read:emotes',
];
```

---

## Common Tasks

### Adding a New Feature
1. Create directory structure: `lib/features/<feature_name>/`
2. Add `data/` directory for models and repositories
3. Add `presentation/` directory for screens and widgets
4. Define providers in appropriate files
5. Add routes in `app_router.dart` if needed
6. Write unit tests in `test/unit/`
7. Write widget tests if UI is complex

### Adding a New Provider
```dart
// In your feature's data directory
final myFeatureProvider = Provider<MyFeature>((ref) {
  final repo = ref.watch(myRepositoryProvider);
  return MyFeature(repo);
});
```

### Adding a New Screen
```dart
// In your feature's presentation directory
class MyScreen extends ConsumerWidget {
  const MyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Screen')),
      body: // Your UI here
    );
  }
}
```

### Adding a New Route
```dart
// In app_router.dart
GoRoute(
  path: '/my-route',
  builder: (context, state) => const MyScreen(),
),
```

---

## Debugging Tips

### Flutter Inspector
- Use Flutter Inspector in your IDE for widget tree inspection
- Check for layout issues, overflows, and rebuilds

### Logging
```dart
import 'dart:developer' as developer;

developer.log('Debug message', name: 'MyFeature');
print('Simple debug message'); // Avoid in production
```

### Performance
- Use `const` constructors to reduce rebuilds
- Profile with `flutter run --profile`
- Check for unnecessary rebuilds with Flutter Inspector
- Use `shouldRebuild` for custom comparisons

### Common Issues
- **Provider not found:** Ensure provider is in scope
- **Null check error:** Verify null safety usage
- **Layout overflow:** Check `Expanded`/`Flexible` usage
- **Build fails:** Run `flutter clean && flutter pub get`

---

## Git Workflow

### Commit Messages
- Use conventional commits format:
  - `feat:` for new features
  - `fix:` for bug fixes
  - `docs:` for documentation
  - `style:` for formatting
  - `refactor:` for code refactoring
  - `test:` for tests
  - `chore:` for maintenance

### Branch Naming
- `feature/<feature-name>`
- `fix/<bug-description>`
- `refactor/<refactor-description>`

### Pre-commit Checklist
1. Run `dart format .`
2. Run `flutter analyze`
3. Run `flutter test`
4. Verify `.env` is not staged
5. Review changes

---

## Environment Setup

### Required
- Flutter SDK (^3.13.0-282.1.beta)
- Dart SDK
- Android Studio / VS Code
- Android SDK (for Android builds)
- Xcode (for iOS builds, macOS only)

### Optional
- IntelliJ IDEA
- Flutter/Dart plugins for IDE

### Getting Started
```bash
# Clone the repository
git clone <repository-url>

# Navigate to project
cd nice-tw-tv

# Install dependencies
flutter pub get

# Copy environment template
cp .env.example .env

# Edit .env with your Twitch credentials
# Run the app
flutter run
```

---

## Resources

- [Flutter Documentation](https://flutter.dev/docs)
- [Dart Documentation](https://dart.dev/guides)
- [Riverpod Documentation](https://riverpod.dev/)
- [GoRouter Documentation](https://pub.dev/packages/go_router)
- [Twitch Developer Documentation](https://dev.twitch.tv/docs)
- [Twitch Helix API](https://dev.twitch.tv/docs/api/reference)

---

## Notes

- This is an Android-first application, but also targets iOS
- The app uses the official Twitch embed player for MVP stability
- Video uses `media_kit` for native HLS playback (experimental)
- Chat uses raw IRC protocol over WebSocket
- 7TV emote updates use WebSocket for real-time changes
- Environment variables are loaded from `.env` at startup
- Never commit `.env` or any credentials
