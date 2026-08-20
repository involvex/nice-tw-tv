import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/notifications/data/eventsub_client.dart';
import 'package:nice_tv/features/notifications/data/local_push_service.dart';
import 'package:nice_tv/features/settings/data/quiet_hours.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LiveNotificationItem {
  const LiveNotificationItem({
    required this.id,
    required this.userId,
    required this.userLogin,
    required this.userName,
    required this.title,
    required this.gameName,
    required this.wentLiveAt,
    this.read = false,
  });

  final String id;
  final String userId;
  final String userLogin;
  final String userName;
  final String title;
  final String gameName;
  final DateTime wentLiveAt;
  final bool read;

  LiveNotificationItem copyWith({bool? read}) {
    return LiveNotificationItem(
      id: id,
      userId: userId,
      userLogin: userLogin,
      userName: userName,
      title: title,
      gameName: gameName,
      wentLiveAt: wentLiveAt,
      read: read ?? this.read,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userLogin': userLogin,
    'userName': userName,
    'title': title,
    'gameName': gameName,
    'wentLiveAt': wentLiveAt.toIso8601String(),
    'read': read,
  };

  factory LiveNotificationItem.fromJson(Map<String, dynamic> json) {
    return LiveNotificationItem(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      userLogin: json['userLogin'] as String? ?? '',
      userName: json['userName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      gameName: json['gameName'] as String? ?? '',
      wentLiveAt:
          DateTime.tryParse(json['wentLiveAt'] as String? ?? '') ??
          DateTime.now(),
      read: json['read'] as bool? ?? false,
    );
  }

  factory LiveNotificationItem.fromStream(TwitchStream stream) {
    return LiveNotificationItem(
      id: '${stream.userId}-${stream.startedAt.toIso8601String()}',
      userId: stream.userId,
      userLogin: stream.userLogin,
      userName: stream.userName,
      title: stream.title,
      gameName: stream.gameName,
      wentLiveAt: stream.startedAt,
    );
  }

  factory LiveNotificationItem.fromEventSub(EventSubOnlineEvent event) {
    return LiveNotificationItem(
      id: '${event.broadcasterId}-${event.startedAt.toIso8601String()}',
      userId: event.broadcasterId,
      userLogin: event.broadcasterLogin,
      userName: event.broadcasterName,
      title: 'Started streaming',
      gameName: '',
      wentLiveAt: event.startedAt,
    );
  }
}

class NotificationsInboxState {
  const NotificationsInboxState({
    this.items = const [],
    this.isLoading = false,
    this.error,
    this.lastPolledAt,
    this.eventSubConnected = false,
  });

  final List<LiveNotificationItem> items;
  final bool isLoading;
  final String? error;
  final DateTime? lastPolledAt;
  final bool eventSubConnected;

  int get unreadCount => items.where((e) => !e.read).length;

  NotificationsInboxState copyWith({
    List<LiveNotificationItem>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
    DateTime? lastPolledAt,
    bool? eventSubConnected,
  }) {
    return NotificationsInboxState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      lastPolledAt: lastPolledAt ?? this.lastPolledAt,
      eventSubConnected: eventSubConnected ?? this.eventSubConnected,
    );
  }
}

/// Diffs currently live followed channels against the previous snapshot.
List<LiveNotificationItem> diffWentLive({
  required Set<String> previousLiveUserIds,
  required List<TwitchStream> currentLive,
  required Set<String> knownNotificationIds,
}) {
  final fresh = <LiveNotificationItem>[];
  for (final stream in currentLive) {
    if (previousLiveUserIds.contains(stream.userId)) continue;
    final item = LiveNotificationItem.fromStream(stream);
    if (knownNotificationIds.contains(item.id)) continue;
    fresh.add(item);
  }
  return fresh;
}

class NotificationsInboxController extends Notifier<NotificationsInboxState>
    with WidgetsBindingObserver {
  static const _itemsKey = 'live_notifications_inbox';
  static const _liveIdsKey = 'live_notifications_snapshot_ids';
  static const _pollInterval = Duration(minutes: 2);

  Timer? _timer;
  var _bootstrapped = false;
  EventSubLiveClient? _eventSub;
  StreamSubscription<EventSubOnlineEvent>? _eventSubSub;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  NotificationsInboxState build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _timer?.cancel();
      _eventSubSub?.cancel();
      _eventSub?.dispose();
    });

    final items = _loadItems();
    Future.microtask(() async {
      await ref.read(localPushServiceProvider).init();
      await refresh(force: true);
      await _startEventSub();
      _startTimer();
    });

    ref.listen(authControllerProvider, (prev, next) {
      final loggedIn = next.value?.isLoggedIn == true;
      if (loggedIn) {
        // ignore: discarded_futures
        refresh(force: true);
        // ignore: discarded_futures
        _startEventSub();
      } else {
        // ignore: discarded_futures
        _stopEventSub();
      }
    });

    return NotificationsInboxState(items: items);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // ignore: discarded_futures
      refresh(force: true);
      // ignore: discarded_futures
      _startEventSub();
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_pollInterval, (_) {
      // ignore: discarded_futures
      refresh();
    });
  }

  Future<void> _startEventSub() async {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true || auth?.userId == null) return;
    await _stopEventSub();
    _eventSub = EventSubLiveClient(
      helix: ref.read(helixRepositoryProvider),
      dio: ref.read(dioProvider),
    );
    _eventSubSub = _eventSub!.onlineEvents.listen(_onEventSubOnline);
    try {
      await _eventSub!.start(userId: auth!.userId!);
      state = state.copyWith(eventSubConnected: true);
    } on Object {
      state = state.copyWith(eventSubConnected: false);
    }
  }

  Future<void> _stopEventSub() async {
    await _eventSubSub?.cancel();
    _eventSubSub = null;
    await _eventSub?.dispose();
    _eventSub = null;
    state = state.copyWith(eventSubConnected: false);
  }

  Future<void> _onEventSubOnline(EventSubOnlineEvent event) async {
    final item = LiveNotificationItem.fromEventSub(event);
    await _ingestFresh([item], notify: true);
    final snapshot = _loadLiveSnapshot()..add(event.broadcasterId);
    await _saveLiveSnapshot(snapshot);
  }

  Future<void> _ingestFresh(
    List<LiveNotificationItem> fresh, {
    required bool notify,
  }) async {
    if (fresh.isEmpty) return;
    final known = state.items.map((e) => e.id).toSet();
    final novel = fresh.where((e) => !known.contains(e.id)).toList();
    if (novel.isEmpty) return;
    var nextItems = [...novel, ...state.items];
    if (nextItems.length > 100) nextItems = nextItems.sublist(0, 100);
    await _saveItems(nextItems);
    state = state.copyWith(items: nextItems);
    if (notify) {
      final settings = ref.read(settingsControllerProvider);
      final inQuiet =
          settings.quietHoursEnabled &&
          isInQuietHours(
            DateTime.now(),
            settings.quietHoursStart,
            settings.quietHoursEnd,
          );
      final push = ref.read(localPushServiceProvider);
      for (final item in novel) {
        if (inQuiet) continue;
        await push.showWentLive(item);
      }
    }
  }

  List<LiveNotificationItem> _loadItems() {
    final raw = _prefs.getString(_itemsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => LiveNotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> _saveItems(List<LiveNotificationItem> items) async {
    final encoded = jsonEncode(items.map((e) => e.toJson()).toList());
    await _prefs.setString(_itemsKey, encoded);
  }

  Set<String> _loadLiveSnapshot() {
    final raw = _prefs.getStringList(_liveIdsKey) ?? const [];
    return raw.toSet();
  }

  Future<void> _saveLiveSnapshot(Set<String> ids) async {
    await _prefs.setStringList(_liveIdsKey, ids.toList());
  }

  Future<void> refresh({bool force = false}) async {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true || auth?.userId == null) {
      state = state.copyWith(isLoading: false, clearError: true);
      return;
    }

    if (state.isLoading && !force) return;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final page = await ref
          .read(helixRepositoryProvider)
          .getFollowedStreams(userId: auth!.userId!, first: 100);
      final previous = _loadLiveSnapshot();
      final knownIds = state.items.map((e) => e.id).toSet();
      final seeded = !_bootstrapped && previous.isEmpty;

      if (!seeded) {
        final fresh = diffWentLive(
          previousLiveUserIds: previous,
          currentLive: page.streams,
          knownNotificationIds: knownIds,
        );
        await _ingestFresh(fresh, notify: true);
      }

      final liveIds = page.streams.map((e) => e.userId).toSet();
      await _saveLiveSnapshot(liveIds);
      _bootstrapped = true;

      state = state.copyWith(
        isLoading: false,
        lastPolledAt: DateTime.now(),
        clearError: true,
      );
    } on Object catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markAllRead() async {
    final next = state.items.map((e) => e.copyWith(read: true)).toList();
    await _saveItems(next);
    state = state.copyWith(items: next);
  }

  Future<void> markRead(String id) async {
    final next = state.items
        .map((e) => e.id == id ? e.copyWith(read: true) : e)
        .toList();
    await _saveItems(next);
    state = state.copyWith(items: next);
  }

  Future<void> clearAll() async {
    await _saveItems(const []);
    state = state.copyWith(items: const []);
  }
}

final notificationsInboxProvider =
    NotifierProvider<NotificationsInboxController, NotificationsInboxState>(
      NotificationsInboxController.new,
    );
