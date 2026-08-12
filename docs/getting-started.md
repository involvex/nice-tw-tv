---
title: Getting Started
nav_order: 2
---

# Getting Started

This guide will help you set up the Nice TV project locally for development.

## Prerequisites

- **Flutter SDK** `^3.13.0-282.1.beta` — install via [flutter.dev](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (bundled with Flutter)
- **Android Studio** or **VS Code** with Flutter/Dart plugins
- **Android SDK** (for Android builds)
- **Git**

## Clone the Repository

```bash
git clone https://github.com/<your-org>/nice-tw-tv.git
cd nice-tw-tv
```

## Environment Setup

1. Copy the example environment file:

   ```bash
   cp .env.example .env
   ```

2. Edit `.env` with your Twitch credentials:

   ```env
   CLIENT_ID=your_twitch_client_id
   TOKEN_PROXY_URL=https://nice-tv-token-proxy.involvex.workers.dev
   ```

   For local-only debug without the proxy, you may set `SECRET` instead of `TOKEN_PROXY_URL`.

3. In the [Twitch Developer Console](https://dev.twitch.tv/console), set OAuth Redirect URL to:

   ```
   https://twitch.tv/login
   ```

## Install Dependencies

```bash
flutter pub get
```

## Run the App

```bash
flutter run
```

To run on a specific device:

```bash
flutter devices
flutter run -d <device_id>
```

## Hot Reload

While the app is running:

- Press `r` in the terminal for hot reload
- Press `R` for hot restart

## Verify Setup

Run the verification checklist:

```bash
dart format .
flutter analyze
flutter test
```

## Next Steps

- Read the [Architecture](architecture.md) guide to understand the project structure
- Check [Build & Release](build-and-release.md) for building release APKs
- See [Contributing](contributing.md) for branching and commit conventions
