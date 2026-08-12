import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';

class ActiveStream {
  const ActiveStream({
    required this.channelLogin,
    this.title,
    this.broadcasterId,
    this.vodId,
    this.clipId,
    required this.backend,
    this.forceEmbedFallback = false,
    this.initialQuality = 'auto',
    this.initialMuted = false,
    this.initialVolume = 0.7,
    this.resumePosition,
    this.initialPlaybackSpeed = 1.0,
  });

  final String channelLogin;
  final String? title;
  final String? broadcasterId;
  final String? vodId;
  final String? clipId;
  final PlayerBackend backend;
  final bool forceEmbedFallback;
  final String initialQuality;
  final bool initialMuted;
  final double initialVolume;
  final Duration? resumePosition;
  final double initialPlaybackSpeed;

  ActiveStream copyWith({
    String? channelLogin,
    String? title,
    String? broadcasterId,
    String? vodId,
    String? clipId,
    PlayerBackend? backend,
    bool? forceEmbedFallback,
    String? initialQuality,
    bool? initialMuted,
    double? initialVolume,
    Duration? resumePosition,
    double? initialPlaybackSpeed,
  }) {
    return ActiveStream(
      channelLogin: channelLogin ?? this.channelLogin,
      title: title ?? this.title,
      broadcasterId: broadcasterId ?? this.broadcasterId,
      vodId: vodId ?? this.vodId,
      clipId: clipId ?? this.clipId,
      backend: backend ?? this.backend,
      forceEmbedFallback: forceEmbedFallback ?? this.forceEmbedFallback,
      initialQuality: initialQuality ?? this.initialQuality,
      initialMuted: initialMuted ?? this.initialMuted,
      initialVolume: initialVolume ?? this.initialVolume,
      resumePosition: resumePosition ?? this.resumePosition,
      initialPlaybackSpeed: initialPlaybackSpeed ?? this.initialPlaybackSpeed,
    );
  }
}

class MiniPlayerController extends Notifier<ActiveStream?> {
  @override
  ActiveStream? build() => null;

  void start(ActiveStream stream) {
    state = stream;
  }

  void close() {
    state = null;
  }
}

final miniPlayerControllerProvider =
    NotifierProvider<MiniPlayerController, ActiveStream?>(
      MiniPlayerController.new,
    );
