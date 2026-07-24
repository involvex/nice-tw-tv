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
  }) : assert(
         channelLogin != null || vodId != null,
         'Provide channelLogin or vodId',
       );

  final String? channelLogin;
  final String? vodId;

  @override
  ConsumerState<NativeHlsPlayer> createState() => _NativeHlsPlayerState();
}

class _NativeHlsPlayerState extends ConsumerState<NativeHlsPlayer> {
  late final Player _player;
  late final VideoController _controller;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  @override
  void didUpdateWidget(covariant NativeHlsPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelLogin != widget.channelLogin ||
        oldWidget.vodId != widget.vodId) {
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
      final uri = widget.vodId != null
          ? await resolver.resolveVod(widget.vodId!)
          : await resolver.resolveLive(widget.channelLogin!);
      await _player.open(Media(uri.toString()));
      if (mounted) setState(() => _loading = false);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
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
