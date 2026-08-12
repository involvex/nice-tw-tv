import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TwitchPlayerEvent {
  const TwitchPlayerEvent({
    required this.type,
    this.quality,
    this.qualities = const [],
    this.message,
  });

  final String type;
  final String? quality;
  final List<String> qualities;
  final String? message;

  factory TwitchPlayerEvent.fromJson(Map<String, dynamic> json) {
    final rawQualities = json['qualities'];
    return TwitchPlayerEvent(
      type: json['type'] as String? ?? '',
      quality: json['quality'] as String?,
      qualities: rawQualities is List
          ? rawQualities.map((e) => e.toString()).toList()
          : const [],
      message: json['message'] as String?,
    );
  }
}

/// Twitch interactive embed with a JS bridge for quality controls.
class TwitchEmbedPlayer extends StatefulWidget {
  const TwitchEmbedPlayer({
    super.key,
    this.channelLogin,
    this.vodId,
    this.clipId,
    this.initialQuality = 'auto',
    this.onEvent,
  }) : assert(
         channelLogin != null || vodId != null || clipId != null,
         'Provide channelLogin, vodId, or clipId',
       );

  final String? channelLogin;
  final String? vodId;
  final String? clipId;
  final String initialQuality;
  final ValueChanged<TwitchPlayerEvent>? onEvent;

  @override
  State<TwitchEmbedPlayer> createState() => TwitchEmbedPlayerState();
}

class TwitchEmbedPlayerState extends State<TwitchEmbedPlayer> {
  WebViewController? _controller;
  var _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF000000))
      ..enableZoom(false)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            // Block main frame navigation away from Twitch domains
            // Allow iframe navigations (ads) to prevent embed breakage
            // Note: isForMainFrame not available in this version, so we allow all
            // iframe-like URLs (common ad domains) while blocking main frame redirects
            final url = request.url;

            // Allow known ad/analytics domains that load in iframes
            final isLikelyIframeContent =
                url.contains('googleads.g.doubleclick.net') ||
                url.contains('googlesyndication.com') ||
                url.contains('google-analytics.com') ||
                url.contains('googletagmanager.com') ||
                url.contains('doubleclick.net') ||
                url.contains('ads.twitch.tv') ||
                url.contains('ttv-api.twitch.tv') ||
                url.contains('api.twitch.tv') ||
                url.contains('usher.ttvnw.net') ||
                url.contains('passport.twitch.tv') ||
                url.contains('sso.twitch.tv') ||
                url.contains('id.twitch.tv') ||
                url.contains('assets.twitch.tv') ||
                url.contains('extensions.twitch.tv');

            // Allow all twitch.tv subdomains, embed.twitch.tv, and safe schemes
            final isTwitchDomain =
                url.startsWith('https://') &&
                (url.contains('.twitch.tv/') ||
                    url.contains('.twitchcdn.net/') ||
                    url.contains('.ttvnw.net/'));
            final allowed =
                isTwitchDomain ||
                isLikelyIframeContent ||
                url.startsWith('https://embed.twitch.tv/') ||
                url.startsWith('https://player.twitch.tv/') ||
                url.startsWith('data:') ||
                url.startsWith('blob:') ||
                url.startsWith('about:') ||
                url.startsWith('file:') ||
                url.startsWith('javascript:') ||
                url.startsWith('https://www.google.com/') ||
                url.startsWith('https://fonts.googleapis.com/') ||
                url.startsWith('https://fonts.gstatic.com/');
            if (!allowed) {
              // Log blocked navigation for debugging
              debugPrint('TwitchEmbedPlayer: Blocked navigation: $url');
            }
            return allowed
                ? NavigationDecision.navigate
                : NavigationDecision.prevent;
          },
          onPageStarted: (url) {
            debugPrint('TwitchEmbedPlayer: WebView page started: $url');
          },
          onPageFinished: (url) {
            debugPrint('TwitchEmbedPlayer: WebView page finished: $url');
          },
          onWebResourceError: (error) {
            debugPrint(
              'TwitchEmbedPlayer: WebView resource error: ${error.url} - ${error.description}',
            );
          },
        ),
      )
      ..addJavaScriptChannel(
        'NiceTvPlayer',
        onMessageReceived: (message) {
          try {
            final json = jsonDecode(message.message) as Map<String, dynamic>;
            final event = TwitchPlayerEvent.fromJson(json);
            if (event.type == 'ready' || event.type == 'playing') {
              _ready = true;
            }
            widget.onEvent?.call(event);
          } on Object {
            // Ignore malformed bridge payloads.
          }
        },
      );
    _controller = controller;
    if (mounted) setState(() {});
    await _load(controller);
  }

  @override
  void didUpdateWidget(covariant TwitchEmbedPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.channelLogin != widget.channelLogin ||
        oldWidget.vodId != widget.vodId ||
        oldWidget.clipId != widget.clipId) {
      _ready = false;
      final controller = _controller;
      if (controller != null) {
        // ignore: discarded_futures
        _load(controller);
      }
    }
  }

  Future<void> _load(WebViewController controller) async {
    final template = await rootBundle.loadString('assets/twitch_player.html');
    final config = <String, dynamic>{
      if (widget.channelLogin != null) 'channel': widget.channelLogin,
      if (widget.vodId != null) 'video': widget.vodId,
      if (widget.clipId != null) 'clip': widget.clipId,
      'quality': widget.initialQuality,
    };
    final html = template.replaceFirst(
      '<body>',
      '<body><script>window.NiceTvConfig=${jsonEncode(config)};</script>',
    );
    await controller.loadHtmlString(html, baseUrl: 'https://twitch.tv/');
  }

  Future<void> setQuality(String quality) async {
    final controller = _controller;
    if (controller == null) return;
    final q = jsonEncode(quality);
    await controller.runJavaScript(
      'window.NiceTvSetQuality && NiceTvSetQuality($q);',
    );
  }

  Future<void> refreshQualities() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.runJavaScript(
      'window.NiceTvGetQualities && NiceTvGetQualities();',
    );
  }

  Future<void> pause() async {
    await _controller?.runJavaScript('window.NiceTvPause && NiceTvPause();');
  }

  Future<void> play() async {
    await _controller?.runJavaScript('window.NiceTvPlay && NiceTvPlay();');
  }

  bool get isReady => _ready;

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return WebViewWidget(controller: controller);
  }
}
