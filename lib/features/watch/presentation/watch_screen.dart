import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/core/routing/app_router.dart';
import 'package:nice_tv/features/chat/presentation/chat_panel.dart';
import 'package:nice_tv/features/history/data/history_controller.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';
import 'package:nice_tv/features/profile/data/follow_controller.dart';
import 'package:nice_tv/features/settings/data/layout_profile.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:nice_tv/features/vod/data/vod_progress_store.dart';
import 'package:nice_tv/features/watch/data/pip_service.dart';
import 'package:nice_tv/features/watch/data/mini_player_player_provider.dart';
import 'package:nice_tv/features/watch/data/player_overlay_controller.dart';
import 'package:nice_tv/features/watch/presentation/native_hls_player.dart';
import 'package:nice_tv/features/watch/presentation/twitch_embed_player.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WatchScreen extends ConsumerStatefulWidget {
  const WatchScreen({
    super.key,
    required this.channelLogin,
    this.title,
    this.broadcasterId,
    this.vodId,
    this.clipId,
    this.thumbnailUrl,
  });

  final String channelLogin;
  final String? title;
  final String? broadcasterId;
  final String? vodId;
  final String? clipId;
  final String? thumbnailUrl;

  @override
  ConsumerState<WatchScreen> createState() => _WatchScreenState();
}

class _WatchScreenState extends ConsumerState<WatchScreen> with RouteAware {
  final _embedKey = GlobalKey<TwitchEmbedPlayerState>();
  final _nativeKey = GlobalKey<NativeHlsPlayerState>();
  var _qualities = <String>['auto'];
  String? _activeQuality;
  var _pipSupported = false;
  var _forceEmbedFallback = false;
  Timer? _historyTimer;
  Timer? _positionTimer;
  Duration? _resumePosition;
  bool _miniplayerCollapsed = false;
  bool _routeSubscribed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        routeObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
    final stream = ref.read(miniPlayerControllerProvider);
    if (stream != null &&
        stream.channelLogin == widget.channelLogin &&
        stream.vodId == widget.vodId &&
        stream.clipId == widget.clipId) {
      ref.read(miniPlayerControllerProvider.notifier).close();
    }
  }

  @override
  void didPushNext() {
    _collapseToMiniplayer();
  }

  @override
  void didPop() {
    _collapseToMiniplayer();
  }

  Future<void> _collapseToMiniplayer() async {
    if (_miniplayerCollapsed) return;
    _miniplayerCollapsed = true;
    final isClip = widget.clipId != null;
    final profile = ref
        .read(layoutProfilesControllerProvider.notifier)
        .forChannel(widget.channelLogin);
    final globalBackend = ref.read(playerBackendControllerProvider);
    final preferredBackend = profile.playerBackend ?? globalBackend;
    final useNative =
        !isClip &&
        preferredBackend == PlayerBackend.nativeHls &&
        !_forceEmbedFallback;
    Duration? position;
    if (useNative) {
      position = _nativeKey.currentState?.currentPosition;
    } else {
      position = await _embedKey.currentState?.getCurrentPosition();
    }
    ref
        .read(miniPlayerControllerProvider.notifier)
        .start(
          ActiveStream(
            channelLogin: widget.channelLogin,
            title: widget.title,
            broadcasterId: widget.broadcasterId,
            vodId: widget.vodId,
            clipId: widget.clipId,
            backend: preferredBackend,
            forceEmbedFallback: _forceEmbedFallback,
            initialQuality:
                _activeQuality ??
                profile.preferredQuality ??
                ref.read(settingsControllerProvider).videoQuality,
            initialMuted: ref.read(settingsControllerProvider).videoMuted,
            initialVolume: ref.read(settingsControllerProvider).videoVolume,
            resumePosition: position,
            initialPlaybackSpeed: ref
                .read(settingsControllerProvider)
                .playbackSpeed,
          ),
        );
    if (_pipSupported) {
      PipService.enter();
    }
  }

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    PipService.isSupported().then((value) {
      if (mounted) setState(() => _pipSupported = value);
    });
    if (widget.vodId != null) {
      SharedPreferences.getInstance().then((prefs) {
        final store = VodProgressStore(prefs);
        final pos = store.readPosition(widget.vodId!);
        if (pos == null) return;
        _resumePosition = pos;
        if (mounted) setState(() {});
      });
      _saveVodMetadata();
    }
    _scheduleHistory();
    _schedulePositionSave();
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _historyTimer?.cancel();
    _positionTimer?.cancel();
    super.dispose();
  }

  Future<void> _saveVodMetadata() async {
    if (widget.vodId == null) return;
    final store = ref.read(vodProgressStoreProvider);
    final existing = store.readEntry(widget.vodId!);
    if (existing != null &&
        existing.title.isNotEmpty &&
        existing.thumbnailUrl.isNotEmpty) {
      return;
    }
    await store.saveProgress(
      VodProgressEntry(
        vodId: widget.vodId!,
        position: Duration.zero,
        title: widget.title ?? '',
        userName: widget.channelLogin,
        userLogin: widget.channelLogin,
        thumbnailUrl: widget.thumbnailUrl ?? '',
        duration: Duration.zero,
      ),
    );
  }

  void _schedulePositionSave() {
    if (widget.vodId == null) return;
    _positionTimer?.cancel();
    _positionTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;
      final isClip = widget.clipId != null;
      final profile = ref
          .read(layoutProfilesControllerProvider.notifier)
          .forChannel(widget.channelLogin);
      final globalBackend = ref.read(playerBackendControllerProvider);
      final preferredBackend = profile.playerBackend ?? globalBackend;
      final useNative =
          !isClip &&
          preferredBackend == PlayerBackend.nativeHls &&
          !_forceEmbedFallback;
      Duration? position;
      if (useNative) {
        position = _nativeKey.currentState?.currentPosition;
      } else {
        position = await _embedKey.currentState?.getCurrentPosition();
      }
      if (position == null) return;
      final vodId = widget.vodId!;
      final store = ref.read(vodProgressStoreProvider);
      final existing = store.readEntry(vodId);
      final duration = useNative
          ? _nativeKey.currentState?.player.state.duration
          : null;
      if (duration != null &&
          duration != Duration.zero &&
          position > duration - const Duration(seconds: 10)) {
        await store.clear(vodId);
      } else if (existing == null || position > existing.position) {
        await store.saveProgress(
          VodProgressEntry(
            vodId: vodId,
            position: position,
            title: existing?.title ?? widget.title ?? '',
            userName: existing?.userName ?? widget.channelLogin,
            userLogin: existing?.userLogin ?? widget.channelLogin,
            thumbnailUrl: existing?.thumbnailUrl ?? widget.thumbnailUrl ?? '',
            duration: duration ?? existing?.duration ?? Duration.zero,
          ),
        );
      }
    });
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

  Future<void> _toggleMute() async {
    final settings = ref.read(settingsControllerProvider);
    final nextMuted = !settings.videoMuted;
    await ref
        .read(settingsControllerProvider.notifier)
        .setVideoMuted(nextMuted);
    final profile = ref
        .read(layoutProfilesControllerProvider.notifier)
        .forChannel(widget.channelLogin);
    final isClip = widget.clipId != null;
    final globalBackend = ref.read(playerBackendControllerProvider);
    final preferredBackend = profile.playerBackend ?? globalBackend;
    final useNative =
        !isClip &&
        preferredBackend == PlayerBackend.nativeHls &&
        !_forceEmbedFallback;
    if (useNative) {
      await _nativeKey.currentState?.setMuted(nextMuted);
    } else {
      await _embedKey.currentState?.setMuted(nextMuted);
    }
    setState(() {});
  }

  Future<void> _saveProfile(StreamerLayoutProfile profile) async {
    await ref
        .read(layoutProfilesControllerProvider.notifier)
        .save(widget.channelLogin, profile);
  }

  void _onPlayerEvent(TwitchPlayerEvent event) {
    debugPrint(
      'WatchScreen: _onPlayerEvent - type: ${event.type}, quality: ${event.quality}, qualities: ${event.qualities}, message: ${event.message}',
    );
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
    debugPrint('WatchScreen: _onNativeFailed - error: $error');
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
    final settings = ref.watch(settingsControllerProvider);
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
              externalPlayer: ref.read(miniPlayerMediaKitPlayerProvider),
              channelLogin: widget.vodId == null ? widget.channelLogin : null,
              vodId: widget.vodId,
              initialQuality: quality,
              initialMuted: settings.videoMuted,
              initialVolume: settings.videoVolume,
              resumePosition: _resumePosition,
              initialPlaybackSpeed: settings.playbackSpeed,
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
              initialMuted: settings.videoMuted,
              initialVolume: settings.videoVolume,
              resumePosition: _resumePosition,
              initialPlaybackSpeed: settings.playbackSpeed,
              onEvent: _onPlayerEvent,
            ),
    );

    final chat = ChatPanel(
      channelLogin: widget.channelLogin,
      broadcasterId: widget.broadcasterId,
      densityOverride: profile.chatDensity,
    );

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        debugPrint(
          'WatchScreen: PopScope onPopInvokedWithResult - didPop: $didPop, result: $result',
        );
      },
      child: Scaffold(
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
            if (widget.broadcasterId != null)
              Consumer(
                builder: (context, ref, _) {
                  final followState = ref.watch(
                    followControllerProvider(widget.broadcasterId!),
                  );
                  final isFollowing = followState.value?.isFollowing ?? false;
                  final isLoading = followState.value?.isLoading ?? false;
                  return IconButton(
                    tooltip: isFollowing ? 'Unfollow' : 'Follow',
                    onPressed: isLoading
                        ? null
                        : () async {
                            try {
                              await ref
                                  .read(
                                    followControllerProvider(
                                      widget.broadcasterId!,
                                    ).notifier,
                                  )
                                  .toggle();
                            } on Object catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update follow: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                    icon: Icon(
                      isFollowing ? Icons.favorite : Icons.favorite_border,
                      color: isFollowing ? Colors.red : null,
                    ),
                  );
                },
              ),
            IconButton(
              tooltip: 'View profile',
              onPressed: () => context.push(
                '/profile/${widget.channelLogin}?userId=${widget.broadcasterId}',
              ),
              icon: const Icon(Icons.person_outline),
            ),
            IconButton(
              tooltip: settings.videoMuted ? 'Unmute' : 'Mute',
              onPressed: _toggleMute,
              icon: Icon(
                settings.videoMuted
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
              ),
            ),
            IconButton(
              tooltip: 'Share',
              onPressed: () {
                String url;
                if (widget.clipId != null && widget.clipId!.isNotEmpty) {
                  url = 'https://clips.twitch.tv/${widget.clipId}';
                } else if (widget.vodId != null && widget.vodId!.isNotEmpty) {
                  url = 'https://www.twitch.tv/videos/${widget.vodId}';
                } else {
                  url = 'https://www.twitch.tv/${widget.channelLogin}';
                }
                SharePlus.instance.share(ShareParams(text: url));
              },
              icon: const Icon(Icons.share_outlined),
            ),
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
            PopupMenuButton<double>(
              tooltip: 'Speed',
              initialValue: settings.playbackSpeed,
              onSelected: (speed) async {
                await ref
                    .read(settingsControllerProvider.notifier)
                    .setPlaybackSpeed(speed);
                await _nativeKey.currentState?.setPlaybackSpeed(speed);
                await _embedKey.currentState?.setPlaybackSpeed(speed);
              },
              itemBuilder: (context) => [
                for (final s in const [
                  0.25,
                  0.5,
                  0.75,
                  1.0,
                  1.25,
                  1.5,
                  1.75,
                  2.0,
                ])
                  PopupMenuItem(
                    value: s,
                    child: Text(
                      s == 1.0 ? 'Normal' : '${s}x',
                      style: TextStyle(
                        fontWeight: settings.playbackSpeed == s
                            ? FontWeight.w700
                            : null,
                      ),
                    ),
                  ),
              ],
              icon: const Icon(Icons.speed_outlined),
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
      ),
    );
  }
}
