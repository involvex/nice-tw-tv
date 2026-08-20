import 'dart:convert';

import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatHistoryStore {
  ChatHistoryStore(this._prefs);

  static const _maxMessages = 200;

  final SharedPreferences _prefs;

  String _keyFor(String channel) => 'chat_history_${channel.toLowerCase()}';

  List<ChatMessage> read(String channel) {
    final raw = _prefs.getString(_keyFor(channel));
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on Object {
      return const [];
    }
  }

  Future<void> write(String channel, List<ChatMessage> messages) async {
    final kept = messages.length > _maxMessages
        ? messages.sublist(messages.length - _maxMessages)
        : messages;
    final encoded = jsonEncode(kept.map((m) => m.toJson()).toList());
    await _prefs.setString(_keyFor(channel), encoded);
  }
}
