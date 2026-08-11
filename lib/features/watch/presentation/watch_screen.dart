import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/chat/presentation/chat_panel.dart';
import 'package:nice_tv/features/history/data/history_controller.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:nice_tv/features/watch/data/pip_service.dart';
import 'package:nice_tv/features/watch/presentation/native_hls_player.dart';
import 'package:nice_tv/features/watch/presentation/twitch_embed_player.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.channelLogin,
    this.title,
    this.broadcasterId,
    this.vodId,
    this.clipId,
  });

  final String channelLogin;
  final String? title;
  final String? broadcasterId;
  final String? vodId;
  final String? clipId;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> {
  final _embedKey = GlobalKey<TwitchEmbedPlayerState>();
  final _nativeKey = GlobalKey<NativeHlsPlayerState>();
  var _qualities = <String>['auto'];
  String? _activeQuality;
  var _pipSupported = false;
  var _forceEmbedFallback = false;
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    PipService.isSupported().then((value) {
      if (mounted) setState(() => _pipSupported = value);
    });
    _scheduleHistory();
  }

  @override
  void dispose() {
    _historyTimer?.cancel();
    super.dispose();
  }

  void _scheduleHistory() {
    _historyTimer?.cancel();
    _historyTimer = Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      final title = widget.title;
      if (title == null || title.isEmpty) return;
      final thumbnail = widget.clipId != null
          ? 'https://static-cdn.jtvnw.net/previews-ttv/live_user_${widget.channelLogin}-440x248.jpg'
          : widget.broadcasterId != null
          ? 'https://static-cdn.jtvnw.net/previews-ttv/live_user_${widget.channelLogin}-440x248.jpg'
          : '';
      final entry = HistoryEntry(
        userLogin: widget.channelLogin,
        userName: widget.channelLogin,
        title: title,
        gameName: null,
        thumbnailUrl: thumbnail,
        watchedAt: DateTime.now(),
        streamId: widget.broadcasterId,
      );
      ref.read(historyControllerProvider.notifier).addEntry(entry);
    });
  }

  StreamerLayoutProfile get _profile => ref
      .read(layoutProfilesControllerProvider.notifier)
      .forChannel(widget.channelLogin);

  String get _quality {
    return _profile.preferredQuality ??
        ref.read(settingsControllerProvider).videoQuality;
  }

  Future<void> _setQuality(String quality) async {
    setState(() => _activeQuality = quality);
    final profile = _profile.copyWith(preferredQuality: quality);
    await ref
        .read(layoutProfilesControllerProvider.notifier)
        .save(widget.channelLogin, profile);
    await ref
        .read(settingsControllerProvider.notifier)
        .setVideoQuality(quality);
    await _embedKey.currentState?.setQuality(quality);
    await _nativeKey.currentState?.setQuality(quality);
  }

  Future<void> _saveProfile(StreamerLayoutProfile profile) async {
    await ref
        .read(layoutProfilesControllerProvider.notifier)
        .save(widget.channelLogin, profile);
  }

  void _onPlayerEvent(TwitchPlayerEvent event) {
    if (event.qualities.isNotEmpty) {
      setState(() {
        _qualities = {
          'auto',
          ...event.qualities.where((q) => q.isNotEmpty && q != 'Auto'),
        }.toList();
      });
    }
    if (event.quality != null && event.quality!.isNotEmpty) {
      setState(() => _activeQuality = event.quality);
    }
  }

  void _onNativeFailed(Object error) {
    if (!mounted || _forceEmbedFallback) return;
    setState(() => _forceEmbedFallback = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Native HLS failed — switched to embed player'),
      ),
    );
  }

  Future<void> _openLayoutSheet() async {
    final profile = ref
        .read(layoutProfilesControllerProvider.notifier)
        .forChannel(widget.channelLogin);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        var draft = profile;
        return StatefulBuilder(
          builder: (context, setModal) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Layout for ${widget.channelLogin}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Chat placement',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<ChatPlacement>(
                    segments: const [
                      ButtonSegment(
                        value: ChatPlacement.bottom,
                        label: Text('Bottom'),
                        icon: Icon(Icons.vertical_align_bottom),
                      ),
                      ButtonSegment(
                        value: ChatPlacement.side,
                        label: Text('Side'),
                        icon: Icon(Icons.view_sidebar_outlined),
                      ),
                      ButtonSegment(
                        value: ChatPlacement.hidden,
                        label: Text('Hidden'),
                        icon: Icon(Icons.visibility_off_outlined),
                      ),
                    ],
                    selected: {draft.chatPlacement},
                    onSelectionChanged: (set) {
                      setModal(() {
                        draft = draft.copyWith(chatPlacement: set.first);
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Chat density'),
                    trailing: DropdownButton<int>(
                      value: draft.chatDensity ?? -1,
                      items: const [
                        DropdownMenuItem(value: -1, child: Text('Global')),
                        DropdownMenuItem(value: 0, child: Text('Compact')),
                        DropdownMenuItem(value: 1, child: Text('Default')),
                        DropdownMenuItem(value: 2, child: Text('Spacious')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModal(() {
                          draft = value < 0
                              ? draft.copyWith(clearChatDensity: true)
                              : draft.copyWith(chatDensity: value);
                        });
                      },
                    ),
                  ),
                  Text(
                    'Split ratio (${(draft.videoChatRatio * 100).round()}% video)',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Slider(
                    value: draft.videoChatRatio.clamp(0.4, 0.8),
                    min: 0.4,
                    max: 0.8,
                    onChanged: (value) {
                      setModal(() {
                        draft = draft.copyWith(videoChatRatio: value);
                      });
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Player'),
                    trailing: DropdownButton<String>(
                      value: draft.playerBackend?.name ?? 'global',
                      items: const [
                        DropdownMenuItem(
                          value: 'global',
                          child: Text('Global'),
                        ),
                        DropdownMenuItem(value: 'embed', child: Text('Embed')),
                        DropdownMenuItem(
                          value: 'nativeHls',
                          child: Text('Native HLS'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setModal(() {
                          if (value == 'global') {
                            draft = draft.copyWith(clearPlayerBackend: true);
                          } else if (value == 'embed') {
                            draft = draft.copyWith(
                              playerBackend: PlayerBackend.embed,
                            );
                          } else {
                            draft = draft.copyWith(
                              playerBackend: PlayerBackend.nativeHls,
                            );
                          }
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      await _saveProfile(draft);
                      if (context.mounted) Navigator.pop(context);
                      setState(() {
                        _forceEmbedFallback = false;
                      });
                    },
                    child: const Text('Save profile'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final profiles = ref.watch(layoutProfilesControllerProvider);
    final profile =
        profiles[widget.channelLogin.toLowerCase()] ??
        const StreamerLayoutProfile();
    final globalBackend = ref.watch(playerBackendControllerProvider);
    final preferredBackend = profile.playerBackend ?? globalBackend;
    final isClip = widget.clipId != null;
    final useNative =
        !isClip &&
        preferredBackend == PlayerBackend.nativeHls &&
        !_forceEmbedFallback;
    final quality = profile.preferredQuality ?? _quality;
    final showChat = !isClip && profile.chatPlacement != ChatPlacement.hidden;
    final forceSide =
        profile.chatPlacement == ChatPlacement.side ||
        (profile.chatPlacement == ChatPlacement.bottom && isLandscape);
    final videoFlex = (profile.videoChatRatio * 10).round().clamp(4, 8);
    final chatFlex = (10 - videoFlex).clamp(2, 6);

    final player = AspectRatio(
      aspectRatio: 16 / 9,
      child: useNative
          ? NativeHlsPlayer(
              key: _nativeKey,
              channelLogin: widget.vodId == null ? widget.channelLogin : null,
              vodId: widget.vodId,
              initialQuality: quality,
              onFailed: _onNativeFailed,
              onQualities: (names) {
                if (!mounted) return;
                setState(() {
                  _qualities = names;
                  _activeQuality ??= quality;
                });
              },
            )
          : TwitchEmbedPlayer(
              key: _embedKey,
              channelLogin: isClip || widget.vodId != null
                  ? null
                  : widget.channelLogin,
              vodId: widget.vodId,
              clipId: widget.clipId,
              initialQuality: quality,
              onEvent: _onPlayerEvent,
            ),
    );

    final chat = ChatPanel(
      channelLogin: widget.channelLogin,
      broadcasterId: widget.broadcasterId,
      densityOverride: profile.chatDensity,
    );

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.clipId != null
                  ? 'Clip'
                  : widget.vodId != null
                  ? 'VOD'
                  : widget.channelLogin,
            ),
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
          if (_pipSupported)
            IconButton(
              tooltip: 'Picture in picture',
              onPressed: () => PipService.enter(),
              icon: const Icon(Icons.picture_in_picture_alt_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Quality',
            initialValue: _activeQuality ?? quality,
            onSelected: _setQuality,
            itemBuilder: (context) => [
              for (final q in _qualities)
                PopupMenuItem(value: q, child: Text(q)),
            ],
            icon: const Icon(Icons.high_quality_outlined),
          ),
          IconButton(
            tooltip: 'Layout profile',
            onPressed: _openLayoutSheet,
            icon: const Icon(Icons.dashboard_customize_outlined),
          ),
          IconButton(
            tooltip: showChat ? 'Hide chat' : 'Show chat',
            onPressed: () async {
              final next = showChat
                  ? ChatPlacement.hidden
                  : (isLandscape ? ChatPlacement.side : ChatPlacement.bottom);
              await _saveProfile(profile.copyWith(chatPlacement: next));
              setState(() {});
            },
            icon: Icon(
              showChat ? Icons.chat_bubble : Icons.chat_bubble_outline,
            ),
          ),
        ],
      ),
      body: forceSide && showChat
          ? Row(
              children: [
                Expanded(flex: videoFlex, child: player),
                Expanded(
                  flex: chatFlex,
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
                if (showChat) Expanded(child: chat),
              ],
            ),
    );
  }
}
