import 'package:nice_tv/features/chat/data/irc_message.dart';

List<ChatMessage> searchMessages(List<ChatMessage> messages, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return messages;
  return messages.where((m) {
    if (m.message.toLowerCase().contains(q)) return true;
    if (m.displayName.toLowerCase().contains(q)) return true;
    if (m.login.toLowerCase().contains(q)) return true;
    return false;
  }).toList();
}
