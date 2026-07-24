import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ChatConnectionState {
  const ChatConnectionState({
    this.messages = const [],
    this.connected = false,
    this.connecting = false,
    this.error,
  });

  final List<ChatMessage> messages;
  final bool connected;
  final bool connecting;
  final String? error;

  ChatConnectionState copyWith({
    List<ChatMessage>? messages,
    bool? connected,
    bool? connecting,
    String? error,
    bool clearError = false,
  }) {
    return ChatConnectionState(
      messages: messages ?? this.messages,
      connected: connected ?? this.connected,
      connecting: connecting ?? this.connecting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TwitchIrcClient {
  TwitchIrcClient({required this.channelLogin});

  final String channelLogin;
  final _parser = const IrcMessageParser();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<ChatMessage>.broadcast();
  var _disposed = false;

  Stream<ChatMessage> get messages => _controller.stream;

  Future<void> connect({String? oauthToken, String? login}) async {
    await disconnect();
    _disposed = false;
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://irc-ws.chat.twitch.tv:443'),
    );
    _sub = _channel!.stream.listen(
      _onData,
      onError: (Object e) {
        _controller.add(ChatMessage.system('Chat error: $e'));
      },
      onDone: () {
        _controller.add(ChatMessage.system('Disconnected from chat'));
      },
    );

    final nick = (login != null && login.isNotEmpty)
        ? login
        : 'justinfan${DateTime.now().millisecondsSinceEpoch % 100000}';

    if (oauthToken != null && oauthToken.isNotEmpty) {
      _send('PASS oauth:$oauthToken');
    } else {
      _send('PASS SCHMOOPIIE');
    }
    _send('NICK $nick');
    _send('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
    _send('JOIN #${channelLogin.toLowerCase()}');
    _controller.add(
      ChatMessage.system('Joined #${channelLogin.toLowerCase()}'),
    );
  }

  void sendMessage(String text) {
    if (text.trim().isEmpty) return;
    _send('PRIVMSG #${channelLogin.toLowerCase()} :${text.trim()}');
  }

  void _send(String line) {
    _channel?.sink.add(line);
  }

  void _onData(dynamic data) {
    final raw = data.toString();
    for (final line in raw.split('\r\n')) {
      if (line.isEmpty) continue;
      if (line.startsWith('PING')) {
        _send(line.replaceFirst('PING', 'PONG'));
        continue;
      }
      final message = _parser.toChatMessage(line);
      if (message != null) {
        _controller.add(message);
      }
    }
  }

  Future<void> disconnect() async {
    await _sub?.cancel();
    _sub = null;
    await _channel?.sink.close();
    _channel = null;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await disconnect();
    await _controller.close();
  }
}

class ChatController extends Notifier<ChatConnectionState> {
  TwitchIrcClient? _client;
  StreamSubscription<ChatMessage>? _sub;
  String? _channel;

  @override
  ChatConnectionState build() {
    ref.onDispose(() {
      _sub?.cancel();
      _client?.dispose();
    });
    return const ChatConnectionState();
  }

  Future<void> connect(String channelLogin) async {
    _channel = channelLogin;
    state = state.copyWith(connecting: true, clearError: true, messages: []);
    await _sub?.cancel();
    await _client?.dispose();

    final auth = ref.read(authControllerProvider).value;
    _client = TwitchIrcClient(channelLogin: channelLogin);
    _sub = _client!.messages.listen((msg) {
      final next = [...state.messages, msg];
      final trimmed = next.length > 400
          ? next.sublist(next.length - 400)
          : next;
      state = state.copyWith(
        messages: trimmed,
        connected: true,
        connecting: false,
      );
    });

    try {
      await _client!.connect(
        oauthToken: auth?.isLoggedIn == true ? auth!.accessToken : null,
        login: auth?.login,
      );
      state = state.copyWith(connected: true, connecting: false);
    } on Object catch (e) {
      state = state.copyWith(
        connecting: false,
        connected: false,
        error: e.toString(),
      );
    }
  }

  void send(String text) {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true) {
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage.system('Sign in to send chat messages.'),
        ],
      );
      return;
    }
    _client?.sendMessage(text);
    // Optimistic local echo
    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          channel: _channel ?? '',
          login: auth!.login ?? '',
          displayName: auth.login ?? '',
          message: text.trim(),
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
      ],
    );
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatConnectionState>(
      ChatController.new,
    );
