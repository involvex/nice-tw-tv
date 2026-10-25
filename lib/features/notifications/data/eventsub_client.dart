import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class EventSubOnlineEvent {
  const EventSubOnlineEvent({
    required this.broadcasterId,
    required this.broadcasterLogin,
    required this.broadcasterName,
    required this.startedAt,
  });

  final String broadcasterId;
  final String broadcasterLogin;
  final String broadcasterName;
  final DateTime startedAt;
}

/// Twitch EventSub WebSocket client for `stream.online` on followed channels.
class EventSubLiveClient {
  EventSubLiveClient({required this.helix, required this.dio});

  final HelixRepository helix;
  final Dio dio;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<EventSubOnlineEvent>.broadcast();
  var _disposed = false;
  String? _sessionId;

  String? _userId;
  int _maxSubscriptions = 40;
  Timer? _reconnectTimer;
  var _backoffSeconds = 1;
  static const _maxBackoffSeconds = 30;
  var _intentionalStop = false;

  Stream<EventSubOnlineEvent> get onlineEvents => _controller.stream;

  Future<void> start({
    required String userId,
    int maxSubscriptions = 40,
  }) async {
    _userId = userId;
    _maxSubscriptions = maxSubscriptions;
    _intentionalStop = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket();
    _intentionalStop = false;
    if (_disposed) return;

    _channel = WebSocketChannel.connect(
      Uri.parse('wss://eventsub.wss.twitch.tv/ws'),
    );
    _sub = _channel!.stream.listen(
      (data) => _onMessage(data, userId: userId, max: maxSubscriptions),
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  Future<void> _onMessage(
    dynamic data, {
    required String userId,
    required int max,
  }) async {
    if (_disposed) return;
    try {
      final json = jsonDecode(data.toString()) as Map<String, dynamic>;
      final metadata = json['metadata'] as Map<String, dynamic>? ?? {};
      final messageType = metadata['message_type'] as String? ?? '';
      final payload = json['payload'] as Map<String, dynamic>? ?? {};

      if (messageType == 'session_welcome') {
        final session = payload['session'] as Map<String, dynamic>? ?? {};
        _sessionId = session['id'] as String?;
        _backoffSeconds = 1;
        if (_sessionId != null) {
          await _subscribeFollowed(userId: userId, max: max);
        }
        return;
      }

      if (messageType == 'session_reconnect') {
        final session = payload['session'] as Map<String, dynamic>? ?? {};
        final url = session['reconnect_url'] as String?;
        if (url != null) {
          await _reconnect(url, userId: userId, max: max);
        }
        return;
      }

      if (messageType == 'notification') {
        final subscription =
            payload['subscription'] as Map<String, dynamic>? ?? {};
        final type = subscription['type'] as String? ?? '';
        if (type != 'stream.online') return;
        final event = payload['event'] as Map<String, dynamic>? ?? {};
        _controller.add(
          EventSubOnlineEvent(
            broadcasterId: event['broadcaster_user_id'] as String? ?? '',
            broadcasterLogin: event['broadcaster_user_login'] as String? ?? '',
            broadcasterName: event['broadcaster_user_name'] as String? ?? '',
            startedAt:
                DateTime.tryParse(event['started_at'] as String? ?? '') ??
                DateTime.now(),
          ),
        );
      }
    } on Object {
      // Ignore malformed frames.
    }
  }

  Future<void> _subscribeFollowed({
    required String userId,
    required int max,
  }) async {
    final sessionId = _sessionId;
    if (sessionId == null) return;
    final followed = await helix.getFollowedChannels(
      userId: userId,
      first: max,
    );
    for (final channel in followed.take(max)) {
      try {
        await helix.createEventSubSubscription(
          type: 'stream.online',
          version: '1',
          condition: {'broadcaster_user_id': channel.id},
          sessionId: sessionId,
        );
      } on Object {
        // Subscription may already exist or hit rate limits — continue.
      }
    }
  }

  Future<void> _reconnect(
    String url, {
    required String userId,
    required int max,
  }) async {
    _intentionalStop = true;
    await _sub?.cancel();
    try {
      await _channel?.sink.close();
    } on Object {
      // ignore
    }
    _intentionalStop = false;
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _sub = _channel!.stream.listen(
      (data) => _onMessage(data, userId: userId, max: max),
      onError: (_) => _scheduleReconnect(),
      onDone: _scheduleReconnect,
      cancelOnError: true,
    );
  }

  void _scheduleReconnect() {
    if (_disposed || _intentionalStop) return;
    final userId = _userId;
    if (userId == null) return;
    if (_reconnectTimer?.isActive == true) return;

    final delay = Duration(seconds: _backoffSeconds);
    _backoffSeconds = (_backoffSeconds * 2).clamp(1, _maxBackoffSeconds);
    _reconnectTimer = Timer(delay, () {
      if (_disposed || _intentionalStop) return;
      // ignore: discarded_futures
      start(userId: userId, maxSubscriptions: _maxSubscriptions);
    });
  }

  Future<void> _closeSocket() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } on Object {
      // ignore
    }
    _channel = null;
    _sessionId = null;
  }

  Future<void> stop() async {
    _intentionalStop = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _closeSocket();
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _controller.close();
  }
}
