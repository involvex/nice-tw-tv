import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:nice_tv/features/watch/data/hls_resolver.dart';

class NativeHlsPlayer extends ConsumerStatefulWidget {
  const NativeHlsPlayer({
    super.key,
    this.channelLogin,
    this.vodId,
    this.onFailed,
    this.onQualities,
    this.initialQuality,
    this.initialMuted = false,
    this.initialVolume = 0.7,
    this.resumePosition,
    this.initialPlaybackSpeed = 1.0,
    this.externalPlayer,
  }) : assert(
         channelLogin != null || vodId != null,
         'Provide channelLogin or vodId',
       );

  final String? channelLogin;
  final String? vodId;
  final ValueChanged<Object>? onFailed;
  final ValueChanged<List<String>>? onQualities;
  final String? initialQuality;
  final bool initialMuted;
  final double initialVolume;
  final Duration? resumePosition;
  final double initialPlaybackSpeed;
  final Player? externalPlayer;

  @override
  ConsumerState<NativeHlsPlayer> createState() => NativeHlsPlayerState();
}

class NativeHlsPlayerState extends ConsumerState<NativeHlsPlayer> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  var _loading = true;
  var _failureReported = false;
  HlsPlaylist? _playlist;
  String _activeQuality = 'auto';
  double _volume = 0.7;
  var _muted = false;
  double _unmuteVolume = 0.7;
  double _playbackSpeed = 1.0;

  Player get player => _player;
  String get activeQuality => _activeQuality;

  @override
  void initState() {
    super.initState();
    _player = widget.externalPlayer ?? Player();
    _controller = VideoController(_player);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(covariant NativeHlsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelLogin != widget.channelLogin ||
        oldWidget.vodId != widget.vodId) {
      _failureReported = false;
      _open();
    }
  }

  Future<void> _open() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resolver = ref.read(hlsResolverProvider);
      final playlist = widget.vodId != null
          ? await resolver.resolveVodPlaylist(widget.vodId!)
          : await resolver.resolveLivePlaylist(widget.channelLogin!);
      _playlist = playlist;
      final names = [
        'auto',
        ...playlist.variants
            .where((v) => !v.isAudioOnly)
            .map((v) => v.name)
            .where((n) => n.toLowerCase() != 'auto'),
      ];
      widget.onQualities?.call(names);

      final preferred = widget.initialQuality;
      final target = preferred == null || preferred == 'auto'
          ? null
          : playlist.variants
                .where((v) => v.name == preferred && !v.isAudioOnly)
                .firstOrNull;
      _activeQuality = target?.name ?? 'auto';
      _volume = widget.initialVolume;
      _muted = widget.initialMuted;
      _unmuteVolume = widget.initialVolume;
      _playbackSpeed = widget.initialPlaybackSpeed;
      await _player.open(Media((target?.url ?? playlist.masterUrl).toString()));
      await _player.setVolume(_muted ? 0 : _volume * 100);
      await _player.setRate(_playbackSpeed);
      final resume = widget.resumePosition;
      if (resume != null &&
          resume > Duration.zero &&
          resume < _player.state.duration - const Duration(seconds: 10)) {
        await _player.seek(resume);
      }
      if (mounted) setState(() => _loading = false);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
      if (!_failureReported) {
        _failureReported = true;
        widget.onFailed?.call(e);
      }
    }
  }

  Future<void> setQuality(String quality) async {
    final playlist = _playlist;
    if (playlist == null) return;
    if (quality == 'auto') {
      _activeQuality = 'auto';
      await _player.open(Media(playlist.masterUrl.toString()));
      return;
    }
    final match = playlist.variants
        .where((v) => v.name == quality && !v.isAudioOnly)
        .firstOrNull;
    if (match == null) return;
    _activeQuality = match.name;
    await _player.open(Media(match.url.toString()));
    if (mounted) setState(() {});
  }

  Future<void> retry() => _open();

  Future<void> setMuted(bool muted) async {
    _muted = muted;
    if (!muted) {
      await _player.setVolume(_unmuteVolume * 100);
    } else {
      await _player.setVolume(0);
    }
  }

  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    if (!_muted) {
      await _player.setVolume(_volume * 100);
    } else {
      _unmuteVolume = _volume;
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  Duration? get currentPosition {
    final d = _player.state.duration;
    if (d == Duration.zero) return null;
    return _player.state.position;
  }

  Future<void> setPlaybackSpeed(double speed) async {
    _playbackSpeed = speed;
    await _player.setRate(speed);
  }

  @override
  void dispose() {
    if (widget.externalPlayer == null) {
      _player.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Native HLS failed.\n$_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _open, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Video(controller: _controller, controls: NoVideoControls),
        if (_loading)
          const ColoredBox(
            color: Colors.black54,
            child: Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
