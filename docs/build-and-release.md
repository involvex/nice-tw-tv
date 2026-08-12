---
title: Build & Release
nav_order: 5
---

# Build & Release

This guide covers building the app for release and creating GitHub Releases via tags.

## Build Commands

### Debug Build

```bash
flutter run
```

### Release APK (local)

```bash
flutter build apk --release
```

The release APK is output to:

```
build\app\outputs\flutter-apk\app-release.apk
```

### Release App Bundle (Play Store)

```bash
flutter build appbundle --release
```

### iOS Build

```bash
flutter build ios --release
```

### Clean Build Artifacts

```bash
flutter clean
flutter pub get
```

## Signing Setup (Android)

Release APKs and AABs must be signed. Nice TV uses a keystore stored in GitHub Secrets for CI.

### Generate a Release Keystore

```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

### Encode for GitHub Secrets

```bash
# On Linux/macOS/Git Bash
base64 upload-keystore.jks | tr -d '\n' > keystore_base64.txt

# On Windows PowerShell
[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload-keystore.jks")) > keystore_base64.txt
```

### Add Secrets to GitHub

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|--------|-------------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded JKS keystore |
| `ANDROID_KEY_ALIAS` | Key alias (e.g., `upload`) |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

## Creating a Release

1. Update the version in `pubspec.yaml`:

   ```yaml
   version: 1.3.1+4
   ```

2. Commit the version bump:

   ```bash
   git add pubspec.yaml
   git commit -m "chore: bump version to 1.3.1"
   ```

3. Create and push a tag:

   ```bash
   git tag v1.3.1
   git push origin v1.3.1
   ```

4. The GitHub Actions release workflow will automatically:
   - Build a signed release APK
   - Upload it as a GitHub Release asset
   - Upload it as a workflow artifact

## Verification Checklist

```bash
dart format .
flutter analyze
flutter test
```

Smoke on device: sign in, Following tab, watch + chat send, notifications inbox after a followed channel goes live, native HLS failure falls back to embed.
