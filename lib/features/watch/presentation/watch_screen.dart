import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/chat/presentation/chat_panel.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:webview_flutter/webview_flutter.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.channelLogin,
    this.title,
    this.broadcasterId,
  });

  final String channelLogin;
  final String? title;
  final String? broadcasterId;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  late final WebViewController _player;
  var _chatExpanded = true;

  @override
  void initState() {
    super.initState();
    _player = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000));
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPlayer());
  }

  void _loadPlayer() {
    final quality = ref.read(settingsControllerProvider).videoQuality;
    final uri = Uri.https('player.twitch.tv', '/', {
      'channel': widget.channelLogin,
      'parent': 'twitch.tv',
      'muted': 'false',
      if (quality != 'auto') 'quality': quality,
    });
    _player.loadRequest(uri);
  }

  Future<void> _setQuality(String quality) async {
    await ref
        .read(settingsControllerProvider.notifier)
        .setVideoQuality(quality);
    await _player.runJavaScript('''
      (function() {
        try {
          var buttons = Array.from(document.querySelectorAll('button, div[role="button"]'));
        } catch (e) {}
      })();
    ''');
    _loadPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;

    final player = AspectRatio(
      aspectRatio: 16 / 9,
      child: WebViewWidget(controller: _player),
    );

    final chat = ChatPanel(
      channelLogin: widget.channelLogin,
      broadcasterId: widget.broadcasterId,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.channelLogin),
            if (widget.title != null)
              Text(
                widget.title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Quality',
            onSelected: _setQuality,
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'auto', child: Text('Auto')),
              PopupMenuItem(value: '160p', child: Text('160p')),
              PopupMenuItem(value: '360p', child: Text('360p')),
              PopupMenuItem(value: '480p', child: Text('480p')),
              PopupMenuItem(value: '720p', child: Text('720p')),
              PopupMenuItem(value: '1080p', child: Text('1080p')),
            ],
            icon: const Icon(Icons.high_quality_outlined),
          ),
          IconButton(
            tooltip: _chatExpanded ? 'Hide chat' : 'Show chat',
            onPressed: () => setState(() => _chatExpanded = !_chatExpanded),
            icon: Icon(
              _chatExpanded ? Icons.chat_bubble : Icons.chat_bubble_outline,
            ),
          ),
        ],
      ),
      body: isLandscape
          ? Row(
              children: [
                Expanded(flex: 3, child: player),
                if (_chatExpanded)
                  Expanded(
                    flex: 2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(color: theme.dividerColor),
                        ),
                      ),
                      child: chat,
                    ),
                  ),
              ],
            )
          : Column(
              children: [
                player,
                if (_chatExpanded) Expanded(child: chat),
              ],
            ),
    );
  }
}
