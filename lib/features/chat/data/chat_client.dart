import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum ChatLinkStatus { disconnected, connecting, connected, reconnecting }

class ChatConnectionState {
  const ChatConnectionState({
    this.messages = const [],
    this.status = ChatLinkStatus.disconnected,
    this.error,
    this.canSend = false,
  });

  final List<ChatMessage> messages;
  final ChatLinkStatus status;
  final String? error;
  final bool canSend;

  bool get connected => status == ChatLinkStatus.connected;
  bool get connecting =>
      status == ChatLinkStatus.connecting ||
      status == ChatLinkStatus.reconnecting;

  ChatConnectionState copyWith({
    List<ChatMessage>? messages,
    ChatLinkStatus? status,
    String? error,
    bool clearError = false,
    bool? canSend,
  }) {
    return ChatConnectionState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      canSend: canSend ?? this.canSend,
    );
  }
}

enum IrcEventKind { message, disconnected, error }

class IrcClientEvent {
  const IrcClientEvent.message(ChatMessage msg)
    : kind = IrcEventKind.message,
      message = msg,
      error = null;

  const IrcClientEvent.disconnected()
    : kind = IrcEventKind.disconnected,
      message = null,
      error = null;

  const IrcClientEvent.error(this.error)
    : kind = IrcEventKind.error,
      message = null;

  final IrcEventKind kind;
  final ChatMessage? message;
  final Object? error;
}

class TwitchIrcClient {
  TwitchIrcClient({required this.channelLogin});

  final String channelLogin;
  final _parser = const IrcMessageParser();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _sub;
  final _controller = StreamController<IrcClientEvent>.broadcast();
  var _disposed = false;
  var _intentionalClose = false;
  String? _oauthToken;
  String? _login;

  Stream<IrcClientEvent> get events => _controller.stream;

  Future<void> connect({String? oauthToken, String? login}) async {
    _oauthToken = oauthToken;
    _login = login;
    await _openSocket();
  }

  Future<void> _openSocket() async {
    await _closeSocket();
    if (_disposed) return;
    _intentionalClose = false;
    _channel = WebSocketChannel.connect(
      Uri.parse('wss://irc-ws.chat.twitch.tv:443'),
    );
    _sub = _channel!.stream.listen(
      _onData,
      onError: (Object e) {
        if (_disposed || _intentionalClose) return;
        _controller.add(IrcClientEvent.error(e));
        _controller.add(const IrcClientEvent.disconnected());
      },
      onDone: () {
        if (_disposed || _intentionalClose) return;
        _controller.add(const IrcClientEvent.disconnected());
      },
      cancelOnError: true,
    );

    final nick = (_login != null && _login!.isNotEmpty)
        ? _login!
        : 'justinfan${DateTime.now().millisecondsSinceEpoch % 100000}';

    if (_oauthToken != null && _oauthToken!.isNotEmpty) {
      _send('PASS oauth:$_oauthToken');
    } else {
      _send('PASS SCHMOOPIIE');
    }
    _send('NICK $nick');
    _send('CAP REQ :twitch.tv/tags twitch.tv/commands twitch.tv/membership');
    _send('JOIN #${channelLogin.toLowerCase()}');
  }

  void sendMessage(String text, {String? replyParentMsgId}) {
    if (text.trim().isEmpty) return;
    final channel = channelLogin.toLowerCase();
    if (replyParentMsgId != null && replyParentMsgId.isNotEmpty) {
      _send('@reply-parent-msg-id=$replyParentMsgId PRIVMSG #$channel :${text.trim()}');
    } else {
      _send('PRIVMSG #$channel :${text.trim()}');
    }
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
        _controller.add(IrcClientEvent.message(message));
      }
    }
  }

  Future<void> _closeSocket() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _channel?.sink.close();
    } on Object {
      // Ignore close races during reconnect.
    }
    _channel = null;
  }

  Future<void> disconnect() async {
    _intentionalClose = true;
    await _closeSocket();
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _intentionalClose = true;
    await _closeSocket();
    await _controller.close();
  }
}

class ChatController extends Notifier<ChatConnectionState> {
  TwitchIrcClient? _client;
  StreamSubscription<IrcClientEvent>? _sub;
  String? _channel;
  Timer? _reconnectTimer;
  var _attempt = 0;
  var _disposed = false;

  @override
  ChatConnectionState build() {
    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _reconnectTimer?.cancel();
      _sub?.cancel();
      _client?.dispose();
    });
    return const ChatConnectionState();
  }

  bool get _loggedIn {
    final auth = ref.read(authControllerProvider).value;
    return auth?.isLoggedIn == true;
  }

  ChatConnectionState _withSend(ChatConnectionState next) {
    return next.copyWith(
      canSend: _loggedIn && next.status == ChatLinkStatus.connected,
    );
  }

  Future<void> connect(String channelLogin) async {
    _reconnectTimer?.cancel();
    _attempt = 0;
    _channel = channelLogin;
    state = _withSend(
      state.copyWith(
        status: ChatLinkStatus.connecting,
        clearError: true,
        messages: [],
      ),
    );
    await _sub?.cancel();
    await _client?.dispose();

    final auth = ref.read(authControllerProvider).value;
    _client = TwitchIrcClient(channelLogin: channelLogin);
    _sub = _client!.events.listen(_onEvent);

    try {
      await _client!.connect(
        oauthToken: auth?.isLoggedIn == true ? auth!.accessToken : null,
        login: auth?.login,
      );
      _appendSystem('Joined #${channelLogin.toLowerCase()}');
      state = _withSend(
        state.copyWith(status: ChatLinkStatus.connected, clearError: true),
      );
    } on Object catch (e) {
      state = _withSend(
        state.copyWith(
          status: ChatLinkStatus.disconnected,
          error: e.toString(),
        ),
      );
      _scheduleReconnect();
    }
  }

  void _onEvent(IrcClientEvent event) {
    if (_disposed) return;
    switch (event.kind) {
      case IrcEventKind.message:
        final msg = event.message!;
        final next = [...state.messages, msg];
        final trimmed = next.length > 400
            ? next.sublist(next.length - 400)
            : next;
        state = _withSend(
          state.copyWith(
            messages: trimmed,
            status: ChatLinkStatus.connected,
            clearError: true,
          ),
        );
        _attempt = 0;
      case IrcEventKind.error:
        _appendSystem('Chat error: ${event.error}');
      case IrcEventKind.disconnected:
        if (state.status == ChatLinkStatus.disconnected) return;
        _appendSystem('Disconnected from chat');
        state = _withSend(state.copyWith(status: ChatLinkStatus.disconnected));
        _scheduleReconnect();
    }
  }

  void _appendSystem(String text) {
    final next = [...state.messages, ChatMessage.system(text)];
    final trimmed = next.length > 400 ? next.sublist(next.length - 400) : next;
    state = state.copyWith(messages: trimmed);
  }

  void _scheduleReconnect() {
    if (_disposed || _channel == null) return;
    _reconnectTimer?.cancel();
    final delaySeconds = (1 << _attempt.clamp(0, 5)).clamp(1, 32);
    _attempt++;
    state = _withSend(
      state.copyWith(status: ChatLinkStatus.reconnecting, clearError: true),
    );
    _appendSystem('Reconnecting in ${delaySeconds}s…');
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      // ignore: discarded_futures
      _reconnectNow();
    });
  }

  Future<void> _reconnectNow() async {
    if (_disposed || _channel == null || _client == null) return;
    state = _withSend(
      state.copyWith(status: ChatLinkStatus.reconnecting, clearError: true),
    );
    try {
      final auth = ref.read(authControllerProvider).value;
      await _client!.connect(
        oauthToken: auth?.isLoggedIn == true ? auth!.accessToken : null,
        login: auth?.login,
      );
      _appendSystem('Rejoined #${_channel!.toLowerCase()}');
      state = _withSend(
        state.copyWith(status: ChatLinkStatus.connected, clearError: true),
      );
      _attempt = 0;
    } on Object catch (e) {
      state = _withSend(
        state.copyWith(
          status: ChatLinkStatus.disconnected,
          error: e.toString(),
        ),
      );
      _scheduleReconnect();
    }
  }

  Future<void> retryNow() async {
    _reconnectTimer?.cancel();
    await _reconnectNow();
  }

  void send(String text, {String? replyParentMsgId, ChatReplyParent? replyEcho}) {
    if (!_loggedIn) {
      _appendSystem('Sign in to send chat messages.');
      return;
    }
    if (state.status != ChatLinkStatus.connected) {
      _appendSystem('Chat is disconnected. Wait for reconnect to send.');
      return;
    }
    final auth = ref.read(authControllerProvider).value!;
    _client?.sendMessage(text, replyParentMsgId: replyParentMsgId);
    state = _withSend(
      state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(
            id: 'local-${DateTime.now().microsecondsSinceEpoch}',
            channel: _channel ?? '',
            login: auth.login ?? '',
            displayName: auth.login ?? '',
            message: text.trim(),
            color: null,
            isAction: false,
            timestamp: DateTime.now(),
            badges: const [],
            replyParent: replyEcho,
          ),
        ],
      ),
    );
  }
}

final chatControllerProvider =
    NotifierProvider.autoDispose<ChatController, ChatConnectionState>(
      ChatController.new,
    );
