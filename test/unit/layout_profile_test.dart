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
    );
    final restored = StreamerLayoutProfile.fromJson(profile.toJson());
    expect(restored.chatPlacement, ChatPlacement.side);
    expect(restored.chatDensity, 0);
    expect(restored.videoChatRatio, 0.7);
    expect(restored.playerBackend, PlayerBackend.nativeHls);
    expect(restored.preferredQuality, '720p60');
  });
}
