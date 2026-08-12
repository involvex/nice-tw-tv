---
title: Troubleshooting
nav_order: 6
---

# Troubleshooting

Common issues and how to resolve them.

## Flutter / Pub Issues

### `flutter pub get` fails with version conflicts

Run:
```bash
flutter pub upgrade --major-versions
```

If that doesn't work, check `pubspec.yaml` for conflicting version constraints.

### Build fails with "Gradle version not specified"

Ensure you have the correct Flutter SDK version installed:
```bash
flutter --version
flutter doctor
```

### `flutter analyze` shows many errors after update

Run the auto-fix:
```bash
dart fix --apply
```

Then run:
```bash
dart format .
flutter analyze
```

## Android Issues

### Emulator won't start

- Ensure HAXM is installed (Intel) or Hyper-V is enabled (AMD)
- Check that virtualization is enabled in BIOS
- Try `flutter emulators` to list available emulators

### App crashes on startup

- Check `flutter run` output for exceptions
- Verify `.env` exists and has correct values
- Ensure Twitch OAuth redirect URL is set to `https://twitch.tv/login`

### Release build fails with signing errors

- Verify `android/key.properties` exists (local) or GitHub Secrets are set (CI)
- Check keystore path, alias, and passwords
- Ensure `key.properties` is not committed (it's in `.gitignore`)

### "INSTALL_FAILED_VERSION_DOWNGRADE" on install

- Uninstall the existing app first:
  ```bash
  adb uninstall tv.nice.nice_tv
  ```

## OAuth / Authentication Issues

### "Invalid client_id" error

- Verify `CLIENT_ID` in `.env` matches the Twitch Developer Console
- Ensure `TOKEN_PROXY_URL` is correct if using the proxy
- Check that the redirect URL is exactly `https://twitch.tv/login`

### Login redirect doesn't work

- On Android, ensure the intent filter for `https://twitch.tv/login` is configured
- On iOS, check URL schemes in `Info.plist`

## Chat Issues

### Chat disconnects frequently

- Check network stability
- Verify IRC WebSocket endpoint (`wss://irc-ws.chat.twitch.tv:443`) is reachable
- The app has automatic reconnect logic; check logs for repeated failures

### Emotes not showing

- Verify internet connectivity
- Check that BTTV/FFZ/7TV APIs are reachable
- 7TV websocket updates may be delayed; try refreshing

## Video / Player Issues

### Stream won't play

- Check if the streamer is actually live
- Verify network connectivity
- Try switching between embed player and native HLS in settings

### Native HLS shows black screen

- Native HLS is experimental; the app should fall back to embed player
- Check `flutter run` verbose output for media_kit errors
- Report the issue with stream URL and device info

### Picture-in-Picture not working

- Ensure PiP is enabled in Android system settings
- Check that the app has the correct `android:exported` and intent filter settings
- Some devices have custom PiP implementations that may interfere

## General Debugging

### Enable verbose logging

```bash
flutter run --verbose
```

### Clear app data

```bash
# Android
adb shell pm clear tv.nice.nice_tv

# Or uninstall and reinstall
adb uninstall tv.nice.nice_tv
flutter run
```

### Check Flutter health

```bash
flutter doctor -v
```

## Still Stuck?

- Search [existing issues](https://github.com/<your-org>/nice-tw-tv/issues)
- Open a new issue with:
  - Flutter/Dart version (`flutter --version`)
  - Device/OS info
  - Steps to reproduce
  - Log output from `flutter run --verbose`
