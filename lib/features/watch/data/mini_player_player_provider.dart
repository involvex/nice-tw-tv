import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';

final miniPlayerMediaKitPlayerProvider = Provider<Player>((ref) {
  final player = Player();
  ref.onDispose(() => player.dispose());
  return player;
});
