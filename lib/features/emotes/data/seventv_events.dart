import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/core/network/dio_providers.dart';
import 'package:nice_tv/features/emotes/data/emote.dart';
import 'package:nice_tv/features/emotes/data/emote_repository.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Live 7TV emote-set updates over `wss://events.7tv.io/v3`.
class SevenTvEventsClient {
  SevenTvEventsClient({required this.twitchUserId, required this.dio});

  final String twitchUserId;
  final Dio dio;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  Timer? _heartbeat;
  final _updates = StreamController<EmoteCatalog>.broadcast();
  String? _emoteSetId;
  var _disposed = false;

  Stream<EmoteCatalog> get updates => _updates.stream;

  Future<void> start() async {
    await stop();
    _disposed = false;
    try {
      final user = await dio.get<Map<String, dynamic>>(
        'https://7tv.io/v3/users/twitch/$twitchUserId',
      );
      final set = user.data?['emote_set'] as Map<String, dynamic>?;
      _emoteSetId = set?['id'] as String?;
      if (_emoteSetId == null) return;

      _channel = WebSocketChannel.connect(Uri.parse('wss://events.7tv.io/v3'));
      _sub = _channel!.stream.listen(
        _onData,
        onError: (_) {},
        onDone: () {
          if (!_disposed) {
            Future<void>.delayed(const Duration(seconds: 3), start);
          }
        },
      );
    } on Object {
      // Non-fatal: chat still works with static catalog.
    }
  }

  void _onData(dynamic data) {
    Map<String, dynamic>? envelope;
    try {
      envelope = jsonDecode(data.toString()) as Map<String, dynamic>;
    } on Object {
      return;
    }
    final op = envelope['op'] as int?;
    final d = envelope['d'];
    if (op == 1 && d is Map<String, dynamic>) {
      final intervalMs = (d['heartbeat_interval'] as num?)?.toInt() ?? 25000;
      _heartbeat?.cancel();
      _heartbeat = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
        _channel?.sink.add(jsonEncode({'op': 2}));
      });
      _subscribe();
      return;
    }
    if (op == 0 && d is Map<String, dynamic>) {
      final type = d['type'] as String? ?? '';
      if (type.startsWith('emote_set.')) {
        // ignore: discarded_futures
        _reloadSet();
      }
    }
  }

  void _subscribe() {
    final setId = _emoteSetId;
    if (setId == null) return;
    _channel?.sink.add(
      jsonEncode({
        'op': 35,
        'd': {
          'type': 'emote_set.*',
          'condition': {'object_id': setId},
        },
      }),
    );
  }

  Future<void> _reloadSet() async {
    final setId = _emoteSetId;
    if (setId == null) return;
    try {
      final response = await dio.get<Map<String, dynamic>>(
        'https://7tv.io/v3/emote-sets/$setId',
      );
      final emotes = response.data?['emotes'] as List<dynamic>? ?? [];
      final map = <String, Emote>{};
      for (final raw in emotes) {
        final json = raw as Map<String, dynamic>;
        final id = json['id'] as String? ?? '';
        final name = json['name'] as String? ?? '';
        if (id.isEmpty || name.isEmpty) continue;
        final dataNode = json['data'] as Map<String, dynamic>?;
        final host = dataNode?['host'] as Map<String, dynamic>?;
        final hostUrl = host?['url'] as String?;
        final files = host?['files'] as List<dynamic>? ?? [];
        String? fileName;
        for (final file in files) {
          final f = file as Map<String, dynamic>;
          final namePart = f['name'] as String? ?? '';
          if (namePart.contains('2x') || namePart.contains('3x')) {
            fileName = namePart;
            break;
          }
        }
        fileName ??= files.isNotEmpty
            ? (files.first as Map<String, dynamic>)['name'] as String?
            : null;
        if (hostUrl == null || fileName == null) continue;
        final url = hostUrl.startsWith('//')
            ? 'https:$hostUrl/$fileName'
            : '$hostUrl/$fileName';
        map[name] = Emote(
          id: id,
          name: name,
          url: url,
          provider: EmoteProvider.sevenTv,
        );
      }
      if (!_updates.isClosed) {
        _updates.add(EmoteCatalog(byName: map));
      }
    } on Object {
      // Ignore transient reload failures.
    }
  }

  Future<void> stop() async {
    _heartbeat?.cancel();
    _heartbeat = null;
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    _disposed = true;
    await stop();
    await _updates.close();
  }
}

class ChannelEmotesController extends AsyncNotifier<EmoteCatalog> {
  ChannelEmotesController(this.broadcasterId);

  final String broadcasterId;

  SevenTvEventsClient? _events;
  StreamSubscription<EmoteCatalog>? _sub;

  @override
  Future<EmoteCatalog> build() async {
    ref.onDispose(() {
      _sub?.cancel();
      _events?.dispose();
    });
    if (broadcasterId.isEmpty) return EmoteCatalog();

    final base = await ref
        .read(emoteRepositoryProvider)
        .loadForChannel(broadcasterId: broadcasterId);

    _events = SevenTvEventsClient(
      twitchUserId: broadcasterId,
      dio: ref.read(dioProvider),
    );
    _sub = _events!.updates.listen((sevenTvDelta) {
      final current = state.value ?? base;
      final merged = <String, Emote>{
        for (final entry in current.byName.entries)
          if (entry.value.provider != EmoteProvider.sevenTv)
            entry.key: entry.value,
        ...sevenTvDelta.byName,
      };
      state = AsyncData(EmoteCatalog(byName: merged));
    });
    // ignore: discarded_futures
    _events!.start();
    return base;
  }
}

final channelEmotesControllerProvider =
    AsyncNotifierProvider.family<ChannelEmotesController, EmoteCatalog, String>(
      ChannelEmotesController.new,
    );
