import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';

void main() {
  test('StreamerLayoutProfile round-trips JSON', () {
    const profile = StreamerLayoutProfile(
      chatPlacement: ChatPlacement.side,
      chatDensity: 0,
      videoChatRatio: 0.7,
      playerBackend: PlayerBackend.nativeHls,
      preferredQuality: '720p60',
      theaterMode: true,
    );
    final restored = StreamerLayoutProfile.fromJson(profile.toJson());
    expect(restored.chatPlacement, ChatPlacement.side);
    expect(restored.chatDensity, 0);
    expect(restored.videoChatRatio, 0.7);
    expect(restored.playerBackend, PlayerBackend.nativeHls);
    expect(restored.preferredQuality, '720p60');
    expect(restored.theaterMode, isTrue);
  });

  test('StreamerLayoutProfile theaterMode defaults to false', () {
    const profile = StreamerLayoutProfile();
    expect(profile.theaterMode, isFalse);
    final restored = StreamerLayoutProfile.fromJson(profile.toJson());
    expect(restored.theaterMode, isFalse);
  });

  test('StreamerLayoutProfile accentArgb and qualityOverride round-trip', () {
    const profile = StreamerLayoutProfile(
      accentArgb: 0xFF1FA2A6,
      qualityOverride: 'auto',
    );
    final restored = StreamerLayoutProfile.fromJson(profile.toJson());
    expect(restored.accentArgb, 0xFF1FA2A6);
    expect(restored.qualityOverride, 'auto');
  });

  test(
    'StreamerLayoutProfile defaults for omitted accentArgb and qualityOverride',
    () {
      const profile = StreamerLayoutProfile();
      expect(profile.accentArgb, null);
      expect(profile.qualityOverride, null);
      final restored = StreamerLayoutProfile.fromJson(profile.toJson());
      expect(restored.accentArgb, null);
      expect(restored.qualityOverride, null);
    },
  );
}
