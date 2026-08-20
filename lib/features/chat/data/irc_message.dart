import 'package:nice_tv/features/emotes/data/emote.dart';

class ChatBadgeRef {
  const ChatBadgeRef({required this.setId, required this.version});

  final String setId;
  final String version;

  static List<ChatBadgeRef> parse(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    return raw.split(',').where((e) => e.contains('/')).map((pair) {
      final parts = pair.split('/');
      return ChatBadgeRef(setId: parts[0], version: parts[1]);
    }).toList();
  }
}

class ChatReplyParent {
  const ChatReplyParent({
    required this.messageId,
    required this.userLogin,
    required this.displayName,
    required this.body,
  });

  final String messageId;
  final String userLogin;
  final String displayName;
  final String body;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.channel,
    required this.login,
    required this.displayName,
    required this.message,
    required this.color,
    required this.isAction,
    required this.timestamp,
    this.system = false,
    this.badges = const [],
    this.bits,
    this.replyParent,
  });

  final String id;
  final String channel;
  final String login;
  final String displayName;
  final String message;
  final String? color;
  final bool isAction;
  final DateTime timestamp;
  final bool system;
  final List<ChatBadgeRef> badges;

  /// Bits cheered in this message, if any.
  final int? bits;
  final ChatReplyParent? replyParent;

  bool get isCheer => bits != null && bits! > 0;

  ChatMessage copyWith({String? message}) {
    return ChatMessage(
      id: id,
      channel: channel,
      login: login,
      displayName: displayName,
      message: message ?? this.message,
      color: color,
      isAction: isAction,
      timestamp: timestamp,
      system: system,
      badges: badges,
      bits: bits,
      replyParent: replyParent,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'channel': channel,
    'login': login,
    'displayName': displayName,
    'message': message,
    'color': color,
    'isAction': isAction,
    'timestamp': timestamp.toIso8601String(),
    'system': system,
    'badges': badges
        .map((b) => {'set': b.setId, 'version': b.version})
        .toList(),
    'bits': bits,
    'replyParent': replyParent == null
        ? null
        : {
            'messageId': replyParent!.messageId,
            'userLogin': replyParent!.userLogin,
            'displayName': replyParent!.displayName,
            'body': replyParent!.body,
          },
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawBadges = json['badges'] as List<dynamic>? ?? const [];
    final reply = json['replyParent'] as Map<String, dynamic>?;
    return ChatMessage(
      id: json['id'] as String? ?? '',
      channel: json['channel'] as String? ?? '',
      login: json['login'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      message: json['message'] as String? ?? '',
      color: json['color'] as String?,
      isAction: json['isAction'] as bool? ?? false,
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      system: json['system'] as bool? ?? false,
      badges: rawBadges.map((e) {
        final map = e as Map<String, dynamic>;
        return ChatBadgeRef(
          setId: map['set'] as String? ?? '',
          version: map['version'] as String? ?? '',
        );
      }).toList(),
      bits: json['bits'] as int?,
      replyParent: reply == null
          ? null
          : ChatReplyParent(
              messageId: reply['messageId'] as String? ?? '',
              userLogin: reply['userLogin'] as String? ?? '',
              displayName: reply['displayName'] as String? ?? '',
              body: reply['body'] as String? ?? '',
            ),
    );
  }

  factory ChatMessage.system(String text) {
    return ChatMessage(
      id: 'sys-${DateTime.now().microsecondsSinceEpoch}',
      channel: '',
      login: 'system',
      displayName: 'Nice TV',
      message: text,
      color: null,
      isAction: false,
      timestamp: DateTime.now(),
      system: true,
    );
  }
}

class IrcMessageParser {
  const IrcMessageParser();

  /// Parses a single IRC line into tags, command, and params.
  static ({
    Map<String, String> tags,
    String? prefix,
    String command,
    List<String> params,
  })
  parseLine(String raw) {
    var line = raw.trimRight();
    final tags = <String, String>{};
    String? prefix;
    if (line.startsWith('@')) {
      final space = line.indexOf(' ');
      final tagPart = line.substring(1, space);
      line = line.substring(space + 1);
      for (final pair in tagPart.split(';')) {
        final eq = pair.indexOf('=');
        if (eq == -1) {
          tags[pair] = '';
        } else {
          tags[pair.substring(0, eq)] = _unescapeTag(pair.substring(eq + 1));
        }
      }
    }
    if (line.startsWith(':')) {
      final space = line.indexOf(' ');
      prefix = line.substring(1, space);
      line = line.substring(space + 1);
    }
    final parts = <String>[];
    final trailingIdx = line.indexOf(' :');
    String commandAndMiddle;
    if (trailingIdx != -1) {
      commandAndMiddle = line.substring(0, trailingIdx);
      parts.add(line.substring(trailingIdx + 2));
    } else {
      commandAndMiddle = line;
    }
    final tokens = commandAndMiddle.split(' ').where((e) => e.isNotEmpty);
    final list = tokens.toList();
    final command = list.isEmpty ? '' : list.first;
    final middle = list.length > 1 ? list.sublist(1) : <String>[];
    return (
      tags: tags,
      prefix: prefix,
      command: command,
      params: [...middle, ...parts],
    );
  }

  static String _unescapeTag(String value) {
    return value
        .replaceAll(r'\s', ' ')
        .replaceAll(r'\:', ';')
        .replaceAll(r'\\', r'\')
        .replaceAll(r'\r', '\r')
        .replaceAll(r'\n', '\n');
  }

  ChatMessage? toChatMessage(String raw) {
    final parsed = parseLine(raw);
    if (parsed.command != 'PRIVMSG' || parsed.params.length < 2) return null;
    final channel = parsed.params.first.replaceFirst('#', '');
    final message = parsed.params.last;
    final isAction =
        message.startsWith('\u0001ACTION ') && message.endsWith('\u0001');
    final body = isAction ? message.substring(8, message.length - 1) : message;
    final login =
        parsed.tags['login'] ?? (parsed.prefix?.split('!').first ?? 'unknown');
    final display = parsed.tags['display-name']?.isNotEmpty == true
        ? parsed.tags['display-name']!
        : login;
    final bitsRaw = parsed.tags['bits'];
    final bits = bitsRaw == null || bitsRaw.isEmpty
        ? null
        : int.tryParse(bitsRaw);

    ChatReplyParent? reply;
    final parentId = parsed.tags['reply-parent-msg-id'];
    if (parentId != null && parentId.isNotEmpty) {
      reply = ChatReplyParent(
        messageId: parentId,
        userLogin: parsed.tags['reply-parent-user-login'] ?? '',
        displayName: parsed.tags['reply-parent-display-name'] ?? '',
        body: parsed.tags['reply-parent-msg-body'] ?? '',
      );
    }

    return ChatMessage(
      id:
          parsed.tags['id'] ??
          '${DateTime.now().microsecondsSinceEpoch}-$login',
      channel: channel,
      login: login,
      displayName: display,
      message: body,
      color: parsed.tags['color']?.isEmpty == true
          ? null
          : parsed.tags['color'],
      isAction: isAction,
      timestamp: DateTime.now(),
      badges: ChatBadgeRef.parse(parsed.tags['badges']),
      bits: bits,
      replyParent: reply,
    );
  }
}

/// Splits chat text into plain segments and emote names found in [catalog].
/// Cheer tokens like `Cheer100` are kept as text (styled by the UI).
List<ChatSegment> tokenizeMessage(String message, EmoteCatalog catalog) {
  final parts = message.split(' ');
  final segments = <ChatSegment>[];
  final buffer = StringBuffer();

  void flushText() {
    if (buffer.isEmpty) return;
    segments.add(ChatSegment.text(buffer.toString()));
    buffer.clear();
  }

  for (var i = 0; i < parts.length; i++) {
    final word = parts[i];
    final emote = catalog[word];
    if (emote != null) {
      flushText();
      segments.add(ChatSegment.emote(emote));
      if (i < parts.length - 1) buffer.write(' ');
    } else {
      buffer.write(word);
      if (i < parts.length - 1) buffer.write(' ');
    }
  }
  flushText();
  return segments;
}

sealed class ChatSegment {
  const ChatSegment();
  factory ChatSegment.text(String value) = TextSegment;
  factory ChatSegment.emote(Emote emote) = EmoteSegment;
}

class TextSegment extends ChatSegment {
  const TextSegment(this.value);
  final String value;
}

class EmoteSegment extends ChatSegment {
  const EmoteSegment(this.emote);
  final Emote emote;
}

/// Parsed subset of Twitch IRC `ROOMSTATE` tags.
class RoomState {
  const RoomState({
    this.slow = false,
    this.followersOnly = false,
    this.followerOnlyMinutes = 0,
    this.subscribersOnly = false,
    this.emotesOnly = false,
  });

  final bool slow;
  final bool followersOnly;
  final int followerOnlyMinutes;
  final bool subscribersOnly;
  final bool emotesOnly;

  bool get anyRestriction =>
      slow || followersOnly || subscribersOnly || emotesOnly;

  factory RoomState.fromIrcTags(Map<String, String> tags) {
    bool enabled(String key) {
      final raw = tags[key];
      if (raw == null || raw.isEmpty) return false;
      final value = int.tryParse(raw) ?? 0;
      return value > 0;
    }

    final followRaw = tags['followers-only'];
    return RoomState(
      slow: enabled('slow'),
      followersOnly: enabled('followers-only'),
      followerOnlyMinutes: (int.tryParse(followRaw ?? '') ?? 0).clamp(
        0,
        1 << 31,
      ),
      subscribersOnly: enabled('subs-only'),
      emotesOnly: enabled('emote-only'),
    );
  }
}

/// Removes non-system messages whose [ChatMessage.login] is in [blocked].
List<ChatMessage> filterBlocked(
  List<ChatMessage> messages,
  Set<String> blocked,
) {
  if (blocked.isEmpty) return messages;
  return messages.where((m) => m.system || !blocked.contains(m.login)).toList();
}

final RegExp _urlRegex = RegExp(r'https?://\S+');

/// Replaces every URL in [text] with the masked placeholder `[link]`.
/// Used by link-protection / spoiler mode so raw URLs are not displayed.
String maskLinksInText(String text) {
  if (text.isEmpty) return text;
  return text.replaceAllMapped(_urlRegex, (_) => '[link]');
}

/// Formats a chat message timestamp as `HH:mm` (24-hour, zero-padded).
String formatChatTimestamp(DateTime timestamp) {
  final h = timestamp.hour.toString().padLeft(2, '0');
  final m = timestamp.minute.toString().padLeft(2, '0');
  return '$h:$m';
}
