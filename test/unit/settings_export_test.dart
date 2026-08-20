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
      expect(restored.chatTimestamps, false);
      expect(restored.maskLinks, false);
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
      expect(restored.chatTimestamps, isFalse);
      expect(restored.maskLinks, isFalse);
      expect(restored.quietHoursEnabled, isFalse);
    });

    test('returns null for malformed input', () {
      expect(parseExportPayload('not json'), isNull);
      expect(parseExportPayload('{"version":2}'), isNull);
    });
  });
}
