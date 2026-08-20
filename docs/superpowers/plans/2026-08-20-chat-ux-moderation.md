# Chat UX & Moderation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user cards, in-room chat search, block/ignore users, moderation actions, room-state badges, and persistent chat history to the Nice TV chat feature.

**Architecture:** Extend the existing `chat` feature (`lib/features/chat/`) following the established `data/` + `presentation/` split. Pure logic (search filtering, blocked-user filtering, room-state parsing, history serialization) lives in `data/` and is unit-tested; UI (bottom sheets, badges, search field) lives in `presentation/`. Chat state stays in `ChatController` (`lib/features/chat/data/chat_client.dart`); new persisted stores follow the existing `SearchHistoryStore`/`HistoryStore` SharedPreferences pattern.

**Tech Stack:** Flutter/Dart, Riverpod (`Notifier`/`NotifierProvider.autoDispose`), `shared_preferences`, existing `IrcMessageParser`, `CachedNetworkImage`, `go_router`.

## Global Constraints

- Flutter SDK `^3.13.0-282.1.beta`, Dart latest stable.
- Use `bun` only for non-Flutter tasks; this is a Flutter repo so use `flutter pub get`, `flutter test`, `flutter analyze`, `dart format .`.
- No new third-party dependencies; all stores use `shared_preferences` (already a dep).
- Follow existing naming: files `snake_case.dart`, classes `PascalCase`, private members `_`-prefixed.
- Follow the feature-based architecture: logic in `data/`, UI in `presentation/`.
- Use Riverpod `Notifier`/`NotifierProvider`, never `ChangeNotifier`.
- Keep chat buffer cap at 400 messages (existing `ChatController` logic).
- Chat history persistence stores at most 200 messages per channel.
- Do not add comments to code unless a doc comment is genuinely needed (matching existing style).
- Commit after every task with conventional-commit messages (`feat:`).

---

## File Structure

- Modify: `lib/features/chat/data/irc_message.dart` — room-state parsing, `ChatMessage.toJson/fromJson`, blocked-user filter helper.
- Modify: `lib/features/chat/data/chat_client.dart` — room-state in `ChatConnectionState`, moderation send, history load/persist in `ChatController`.
- Create: `lib/features/chat/data/blocked_users_store.dart` — blocked-user persistence + controller.
- Create: `lib/features/chat/data/chat_history_store.dart` — chat history persistence.
- Create: `lib/features/chat/data/chat_search.dart` — pure search/filter helpers.
- Create: `lib/features/chat/presentation/user_card_sheet.dart` — tap-username bottom sheet.
- Modify: `lib/features/chat/presentation/chat_panel.dart` — wire search UI, blocked filter, user cards, moderation actions, room-state badges, history replay.
- Modify: `lib/features/settings/presentation/settings_screen.dart` — blocked-users management section.
- Test: `test/unit/chat_ux_moderation_test.dart` — unit tests for all pure logic.
- Test: `test/unit/chat_history_store_test.dart` — persistence round-trip tests.

---

### Task 1: Room-state parsing + message serialization in `irc_message.dart`

**Files:**
- Modify: `lib/features/chat/data/irc_message.dart`
- Test: `test/unit/chat_ux_moderation_test.dart`

**Interfaces:**
- Consumes: existing `IrcMessageParser.parseLine` (already returns `tags`, `command`, `params`).
- Produces: `enum RoomMode { slow, followersOnly, subscribersOnly, emotesOnly }`; `class RoomState { final bool slow; final bool followersOnly; final int followerOnlyMinutes; final bool subscribersOnly; final bool emotesOnly; }`; `RoomState.fromIrcTags(Map<String, String> tags)`; `ChatMessage.toJson()` / `ChatMessage.fromJson(Map<String, dynamic>)`.

- [ ] **Step 1: Write the failing tests**

Append to a new file `test/unit/chat_ux_moderation_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';

void main() {
  group('RoomState', () {
    test('parses ROOMSTATE tags', () {
      final state = RoomState.fromIrcTags({
        'slow': '30',
        'followers-only': '5',
        'subs-only': '1',
        'emote-only': '1',
      });
      expect(state.slow, isTrue);
      expect(state.followersOnly, isTrue);
      expect(state.followerOnlyMinutes, 5);
      expect(state.subscribersOnly, isTrue);
      expect(state.emotesOnly, isTrue);
    });

    test('parses disabled flags', () {
      final state = RoomState.fromIrcTags({
        'slow': '0',
        'followers-only': '-1',
        'subs-only': '0',
        'emote-only': '0',
      });
      expect(state.slow, isFalse);
      expect(state.followersOnly, isFalse);
      expect(state.followerOnlyMinutes, 0);
      expect(state.subscribersOnly, isFalse);
      expect(state.emotesOnly, isFalse);
    });

    test('handles empty tags', () {
      final state = RoomState.fromIrcTags({});
      expect(state.slow, isFalse);
      expect(state.followersOnly, isFalse);
      expect(state.subscribersOnly, isFalse);
      expect(state.emotesOnly, isFalse);
    });
  });

  group('ChatMessage serialization', () {
    test('round-trips a chat message', () {
      final message = ChatMessage(
        id: 'm1',
        channel: 'chan',
        login: 'viewer',
        displayName: 'Viewer',
        message: 'Hello world',
        color: '#FF0000',
        isAction: false,
        timestamp: DateTime.utc(2026, 8, 20),
        badges: const [ChatBadgeRef(setId: 'vip', version: '1')],
        bits: 5,
        replyParent: const ChatReplyParent(
          messageId: 'p1',
          userLogin: 'host',
          displayName: 'Host',
          body: 'orig',
        ),
      );
      final restored = ChatMessage.fromJson(message.toJson());
      expect(restored.id, 'm1');
      expect(restored.channel, 'chan');
      expect(restored.login, 'viewer');
      expect(restored.displayName, 'Viewer');
      expect(restored.message, 'Hello world');
      expect(restored.color, '#FF0000');
      expect(restored.timestamp, DateTime.utc(2026, 8, 20));
      expect(restored.badges.single.setId, 'vip');
      expect(restored.bits, 5);
      expect(restored.replyParent?.messageId, 'p1');
      expect(restored.system, isFalse);
    });

    test('round-trips a system message', () {
      final message = ChatMessage.system('Hello');
      final restored = ChatMessage.fromJson(message.toJson());
      expect(restored.system, isTrue);
      expect(restored.message, 'Hello');
    });
  });

  group('filterBlocked', () {
    test('removes messages from blocked users', () {
      final messages = [
        ChatMessage(
          id: '1',
          channel: 'c',
          login: 'blocked',
          displayName: 'Blocked',
          message: 'x',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
        ChatMessage(
          id: '2',
          channel: 'c',
          login: 'ok',
          displayName: 'Ok',
          message: 'y',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
      ];
      final filtered = filterBlocked(messages, {'blocked'});
      expect(filtered.single.id, '2');
    });

    test('keeps system messages', () {
      final messages = [
        ChatMessage.system('Joined #chan'),
        ChatMessage(
          id: '2',
          channel: 'c',
          login: 'blocked',
          displayName: 'Blocked',
          message: 'x',
          color: null,
          isAction: false,
          timestamp: DateTime.now(),
        ),
      ];
      final filtered = filterBlocked(messages, {'blocked'});
      expect(filtered.single.system, isTrue);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/chat_ux_moderation_test.dart`
Expected: FAIL — `RoomState` and `filterBlocked` not defined; `toJson`/`fromJson` missing on `ChatMessage`.

- [ ] **Step 3: Implement room-state model + serialization**

Add to `lib/features/chat/data/irc_message.dart` (append near the end, after `ChatMessage`):

```dart
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

    final slowRaw = tags['slow'];
    final followRaw = tags['followers-only'];
    return RoomState(
      slow: enabled('slow'),
      followersOnly: enabled('followers-only'),
      followerOnlyMinutes: (int.tryParse(followRaw ?? '') ?? 0).clamp(0, 1 << 31),
      subscribersOnly: enabled('subs-only'),
      emotesOnly: enabled('emote-only'),
    );
  }
}
```

Add `toJson`/`fromJson` and `copyWith` helpers to `ChatMessage` in the same file:

```dart
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
    'badges': badges.map((b) => {'set': b.setId, 'version': b.version}).toList(),
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
```

Add the pure blocked-filter helper (top-level function, same file):

```dart
/// Removes non-system messages whose [ChatMessage.login] is in [blocked].
List<ChatMessage> filterBlocked(List<ChatMessage> messages, Set<String> blocked) {
  if (blocked.isEmpty) return messages;
  return messages
      .where((m) => m.system || !blocked.contains(m.login))
      .toList();
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/chat_ux_moderation_test.dart`
Expected: PASS (all 7 tests).

- [ ] **Step 5: Format and commit**

Run: `dart format lib/features/chat/data/irc_message.dart test/unit/chat_ux_moderation_test.dart`
Run: `git add lib/features/chat/data/irc_message.dart test/unit/chat_ux_moderation_test.dart`
Run: `git commit -m "feat: parse room state and serialize chat messages"`

---

### Task 2: Blocked-users store

**Files:**
- Create: `lib/features/chat/data/blocked_users_store.dart`
- Test: `test/unit/chat_history_store_test.dart` (add a group)

**Interfaces:**
- Consumes: `sharedPreferencesProvider` from `lib/features/settings/data/settings_controller.dart`.
- Produces: `class BlockedUsersStore { BlockedUsersStore(SharedPreferences prefs); Set<String> read(); Future<void> add(String login); Future<void> remove(String login); }`; `class BlockedUsersController extends Notifier<Set<String>> { Future<void> block(String login); Future<void> unblock(String login); }`; `final blockedUsersControllerProvider = NotifierProvider<BlockedUsersController, Set<String>>(...)`.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/chat_history_store_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('BlockedUsersStore', () {
    test('round-trips blocked users through preferences', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BlockedUsersStore(prefs);
      expect(store.read(), isEmpty);

      await store.add('troll1');
      await store.add('troll2');
      expect(store.read(), {'troll1', 'troll2'});

      await store.remove('troll1');
      expect(store.read(), {'troll2'});
    });

    test('stores logins lowercased', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = BlockedUsersStore(prefs);
      await store.add('Troll');
      expect(store.read(), {'troll'});
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/chat_history_store_test.dart`
Expected: FAIL — `BlockedUsersStore` not defined.

- [ ] **Step 3: Implement the store + controller**

Create `lib/features/chat/data/blocked_users_store.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BlockedUsersStore {
  BlockedUsersStore(this._prefs);

  static const _key = 'blocked_users';

  final SharedPreferences _prefs;

  Set<String> read() {
    final raw = _prefs.getStringList(_key) ?? const [];
    return raw.map((e) => e.toLowerCase()).toSet();
  }

  Future<void> add(String login) async {
    final next = {...read(), login.toLowerCase()};
    await _prefs.setStringList(_key, next.toList());
  }

  Future<void> remove(String login) async {
    final next = {...read()}..remove(login.toLowerCase());
    await _prefs.setStringList(_key, next.toList());
  }
}

class BlockedUsersController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    return store.read();
  }

  Future<void> block(String login) async {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    await store.add(login);
    state = store.read();
  }

  Future<void> unblock(String login) async {
    final store = BlockedUsersStore(ref.watch(sharedPreferencesProvider));
    await store.remove(login);
    state = store.read();
  }
}

final blockedUsersControllerProvider =
    NotifierProvider<BlockedUsersController, Set<String>>(
      BlockedUsersController.new,
    );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/chat_history_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

Run: `dart format lib/features/chat/data/blocked_users_store.dart test/unit/chat_history_store_test.dart`
Run: `git add lib/features/chat/data/blocked_users_store.dart test/unit/chat_history_store_test.dart`
Run: `git commit -m "feat: add blocked-users store"`

---

### Task 3: Chat history persistence

**Files:**
- Create: `lib/features/chat/data/chat_history_store.dart`
- Test: `test/unit/chat_history_store_test.dart` (add group)

**Interfaces:**
- Consumes: `ChatMessage.toJson/fromJson` (Task 1).
- Produces: `class ChatHistoryStore { ChatHistoryStore(SharedPreferences prefs); List<ChatMessage> read(String channel); Future<void> write(String channel, List<ChatMessage> messages); }` (capped at 200 per channel, key `chat_history_<channel>`).

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/chat_history_store_test.dart`:

```dart
import 'package:nice_tv/features/chat/data/chat_history_store.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';

void main() {
  // ... existing BlockedUsersStore group ...

  group('ChatHistoryStore', () {
    ChatMessage msg(String id, {String login = 'viewer'}) {
      return ChatMessage(
        id: id,
        channel: 'chan',
        login: login,
        displayName: login,
        message: 'hello $id',
        color: null,
        isAction: false,
        timestamp: DateTime.utc(2026, 8, 20),
      );
    }

    test('round-trips messages per channel', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(prefs);

      await store.write('chan', [msg('1'), msg('2')]);
      final restored = store.read('chan');
      expect(restored.map((m) => m.id), ['1', '2']);

      expect(store.read('other'), isEmpty);
    });

    test('caps stored history at 200 messages', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = ChatHistoryStore(prefs);
      final many = [for (var i = 0; i < 250; i++) msg('m$i')];

      await store.write('chan', many);
      final restored = store.read('chan');
      expect(restored.length, 200);
      expect(restored.first.id, 'm50');
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/chat_history_store_test.dart`
Expected: FAIL — `ChatHistoryStore` not defined.

- [ ] **Step 3: Implement the store**

Create `lib/features/chat/data/chat_history_store.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/chat_history_store_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

Run: `dart format lib/features/chat/data/chat_history_store.dart test/unit/chat_history_store_test.dart`
Run: `git add lib/features/chat/data/chat_history_store.dart test/unit/chat_history_store_test.dart`
Run: `git commit -m "feat: persist chat history per channel"`

---

### Task 4: Pure chat search helpers

**Files:**
- Create: `lib/features/chat/data/chat_search.dart`
- Test: `test/unit/chat_ux_moderation_test.dart` (add group)

**Interfaces:**
- Consumes: `ChatMessage` (Task 1).
- Produces: `List<ChatMessage> searchMessages(List<ChatMessage> messages, String query)` — case-insensitive substring match on `message`, `displayName`, and `login`; empty/whitespace query returns all.

- [ ] **Step 1: Write the failing tests**

Append to `test/unit/chat_ux_moderation_test.dart`:

```dart
import 'package:nice_tv/features/chat/data/chat_search.dart';

void main() {
  // ... existing groups ...

  group('searchMessages', () {
    ChatMessage msg(String id, String text, {String? displayName}) {
      return ChatMessage(
        id: id,
        channel: 'c',
        login: 'user$id',
        displayName: displayName ?? 'User$id',
        message: text,
        color: null,
        isAction: false,
        timestamp: DateTime.now(),
      );
    }

    test('matches message text case-insensitively', () {
      final messages = [
        msg('1', 'Hello world'),
        msg('2', 'Another line'),
      ];
      final hits = searchMessages(messages, 'hello');
      expect(hits.single.id, '1');
    });

    test('matches display name', () {
      final messages = [
        msg('1', 'hi', displayName: 'Host'),
        msg('2', 'hi'),
      ];
      final hits = searchMessages(messages, 'host');
      expect(hits.single.id, '1');
    });

    test('returns all for empty query', () {
      final messages = [msg('1', 'a'), msg('2', 'b')];
      expect(searchMessages(messages, '').length, 2);
      expect(searchMessages(messages, '   ').length, 2);
    });
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/unit/chat_ux_moderation_test.dart`
Expected: FAIL — `searchMessages` not defined.

- [ ] **Step 3: Implement the helper**

Create `lib/features/chat/data/chat_search.dart`:

```dart
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
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/unit/chat_ux_moderation_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

Run: `dart format lib/features/chat/data/chat_search.dart test/unit/chat_ux_moderation_test.dart`
Run: `git add lib/features/chat/data/chat_search.dart test/unit/chat_ux_moderation_test.dart`
Run: `git commit -m "feat: add chat message search helper"`

---

### Task 5: Wire room-state, blocked filter, search UI, and history replay into `chat_client.dart` + `chat_panel.dart`

**Files:**
- Modify: `lib/features/chat/data/chat_client.dart`
- Modify: `lib/features/chat/presentation/chat_panel.dart`

**Interfaces:**
- Consumes: `RoomState` (Task 1), `filterBlocked` (Task 1), `ChatHistoryStore` (Task 3), `blockedUsersControllerProvider` (Task 2), `searchMessages` (Task 4).
- Produces: `ChatConnectionState.roomState` (`RoomState`); `ChatConnectionState.historical` (`bool`); `ChatController.sendModeration(String text)`; `ChatController.replayHistory()`; `ChatController.toggleSearch()` is NOT in the controller — search is local UI state.

- [ ] **Step 1: Extend `ChatConnectionState` and parse ROOMSTATE in `chat_client.dart`**

In `ChatConnectionState` (lines 10–42), add fields:

```dart
  const ChatConnectionState({
    this.messages = const [],
    this.status = ChatLinkStatus.disconnected,
    this.error,
    this.canSend = false,
    this.roomState = const RoomState(),
    this.historical = false,
  });

  final RoomState roomState;
  final bool historical;
```

And in `copyWith`:

```dart
    RoomState? roomState,
    bool? historical,
  }) {
    return ChatConnectionState(
      messages: messages ?? this.messages,
      status: status ?? this.status,
      error: clearError ? null : (error ?? this.error),
      canSend: canSend ?? this.canSend,
      roomState: roomState ?? this.roomState,
      historical: historical ?? this.historical,
    );
  }
```

Add an import at the top: `import 'package:nice_tv/features/chat/data/irc_message.dart';` is already present (line 5). No change needed.

- [ ] **Step 2: Handle ROOMSTATE in `TwitchIrcClient._onData`**

The IRC server sends `ROOMSTATE` lines. `IrcMessageParser.parseLine` already extracts tags. Add a public method on `TwitchIrcClient`:

```dart
  /// Latest room state; emitted before messages after JOIN.
  RoomState? lastRoomState;
```

In `_onData`, after `final message = _parser.toChatMessage(line);` (line 147), add:

```dart
      final parsed = IrcMessageParser.parseLine(line);
      if (parsed.command == 'ROOMSTATE') {
        lastRoomState = RoomState.fromIrcTags(parsed.tags);
        continue;
      }
```

(Place this before the `toChatMessage` call; `parseLine` is already called inside `toChatMessage`, so the extra call is cheap and keeps the code simple.)

- [ ] **Step 3: Update `ChatController.connect` to carry room state and replay history**

Replace the body of `connect` (lines 210–246) with:

```dart
  Future<void> connect(String channelLogin) async {
    _reconnectTimer?.cancel();
    _attempt = 0;
    _channel = channelLogin;
    final history = ChatHistoryStore(ref.read(sharedPreferencesProvider))
        .read(channelLogin);
    state = _withSend(
      state.copyWith(
        status: ChatLinkStatus.connecting,
        clearError: true,
        messages: history,
        historical: history.isNotEmpty,
        roomState: const RoomState(),
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
      if (_client!.lastRoomState != null) {
        state = state.copyWith(roomState: _client!.lastRoomState!);
      }
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
```

Add import for the history store at the top of `chat_client.dart`:

```dart
import 'package:nice_tv/features/chat/data/chat_history_store.dart';
```

- [ ] **Step 4: Persist history on each ingest and apply room state**

In `_onEvent`, the `IrcEventKind.message` branch (lines 251–264) — replace with:

```dart
      case IrcEventKind.message:
        final msg = event.message!;
        final blocked = ref.read(blockedUsersControllerProvider);
        final visible = filterBlocked([...state.messages, msg], blocked);
        final next = visible.length > 400
            ? visible.sublist(visible.length - 400)
            : visible;
        state = _withSend(
          state.copyWith(
            messages: next,
            status: ChatLinkStatus.connected,
            clearError: true,
          ),
        );
        if (_channel != null && !msg.system) {
          ChatHistoryStore(ref.read(sharedPreferencesProvider))
              .write(_channel!, next.where((m) => !m.system).toList());
        }
        _attempt = 0;
```

In `_reconnectNow` (lines 296–321), after `await _client!.connect(...)` succeeds (line 304), add:

```dart
      if (_client!.lastRoomState != null) {
        state = state.copyWith(roomState: _client!.lastRoomState!);
      }
```

Also update `_appendSystem` (lines 275–279) — leave unchanged; system messages are not persisted.

Add import for blocked-users store at the top:

```dart
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
```

- [ ] **Step 5: Add `sendModeration` to `ChatController`**

Append to `ChatController` (after `send`, line 362):

```dart
  /// Sends a raw command line like `/timeout user 600` to the channel.
  void sendModeration(String command) {
    if (!_loggedIn) {
      _appendSystem('Sign in to moderate chat.');
      return;
    }
    if (state.status != ChatLinkStatus.connected) {
      _appendSystem('Chat is disconnected.');
      return;
    }
    _client?.sendMessage(command);
  }
```

`sendMessage` already prefixes `PRIVMSG #channel :<text>`, which is how Twitch receives slash commands.

- [ ] **Step 6: Add `replayHistory` to `ChatController`**

Append to `ChatController`:

```dart
  void replayHistory() {
    if (_channel == null) return;
    final history = ChatHistoryStore(ref.read(sharedPreferencesProvider))
        .read(_channel!);
    final blocked = ref.read(blockedUsersControllerProvider);
    state = state.copyWith(
      messages: filterBlocked(history, blocked),
      historical: true,
    );
  }
```

- [ ] **Step 7: Run analyze to verify compile**

Run: `flutter analyze lib/features/chat/data/chat_client.dart`
Expected: No issues found.

- [ ] **Step 8: Format and commit**

Run: `dart format lib/features/chat/data/chat_client.dart`
Run: `git add lib/features/chat/data/chat_client.dart`
Run: `git commit -m "feat: wire room state, blocked filter, and history replay into chat controller"`

---

### Task 6: Chat panel UI — search field, blocked filter, room-state badges, history banner

**Files:**
- Modify: `lib/features/chat/presentation/chat_panel.dart`

**Interfaces:**
- Consumes: `searchMessages` (Task 4), `RoomState` (Task 1), `ChatConnectionState.roomState/historical` (Task 5), `blockedUsersControllerProvider` (Task 2).
- Produces: UI only. The `ChatMessageTile` keeps its existing `onReply` callback.

- [ ] **Step 1: Add imports and local search state to `_ChatPanelState`**

Add imports at the top:

```dart
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:nice_tv/features/chat/data/chat_search.dart';
```

In `_ChatPanelState`, add fields:

```dart
  final _searchController = TextEditingController();
  var _searchQuery = '';
  var _searching = false;
```

In `dispose()`:

```dart
    _searchController.dispose();
```

- [ ] **Step 2: Add a header row with search toggle + room-state badges**

Inside `build`, right before the `Expanded(... ListView.builder ...)` (line 218), insert:

```dart
        if (_searching)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search messages',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _searchQuery = '';
                      _searching = false;
                    });
                  },
                ),
                isDense: true,
              ),
            ),
          ),
        if (chat.roomState.anyRestriction)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (chat.roomState.slow)
                  _RoomBadge(label: 'Slow mode'),
                if (chat.roomState.followersOnly)
                  _RoomBadge(label: 'Followers-only'),
                if (chat.roomState.subscribersOnly)
                  _RoomBadge(label: 'Subs-only'),
                if (chat.roomState.emotesOnly)
                  _RoomBadge(label: 'Emote-only'),
              ],
            ),
          ),
        if (chat.historical)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.history,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Showing saved messages from your last visit',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
```

- [ ] **Step 3: Add a search toggle button to the input row**

In the input `Row` (lines 285–316), add a search icon button before the emote button:

```dart
                IconButton(
                  tooltip: 'Search chat',
                  onPressed: () => setState(() {
                    _searching = !_searching;
                    if (!_searching) {
                      _searchController.clear();
                      _searchQuery = '';
                    }
                  }),
                  icon: Icon(
                    _searching ? Icons.close_fullscreen : Icons.search,
                  ),
                ),
                IconButton(
                  tooltip: 'Emotes',
                  onPressed: canSend ? () => _openEmotePicker(catalog) : null,
                  icon: const Icon(Icons.emoji_emotions_outlined),
                ),
```

- [ ] **Step 4: Filter the message list**

Replace `chat.messages.length` (line 222) with a computed list. Add a local variable in `build`:

```dart
    final visibleMessages = _searching
        ? searchMessages(chat.messages, _searchQuery)
        : chat.messages;
```

Then change `itemCount: chat.messages.length` → `itemCount: visibleMessages.length` and `final msg = chat.messages[index];` → `final msg = visibleMessages[index];`.

- [ ] **Step 5: Add `_RoomBadge` widget**

Append to the bottom of `chat_panel.dart`:

```dart
class _RoomBadge extends StatelessWidget {
  const _RoomBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
```

- [ ] **Step 6: Run analyze and verify compile**

Run: `flutter analyze lib/features/chat/presentation/chat_panel.dart`
Expected: No issues found.

- [ ] **Step 7: Format and commit**

Run: `dart format lib/features/chat/presentation/chat_panel.dart`
Run: `git add lib/features/chat/presentation/chat_panel.dart`
Run: `git commit -m "feat: add chat search field, room-state badges, and history banner"`

---

### Task 7: User card bottom sheet (tap username)

**Files:**
- Create: `lib/features/chat/presentation/user_card_sheet.dart`
- Modify: `lib/features/chat/presentation/chat_panel.dart`

**Interfaces:**
- Consumes: `ChatMessage` (login/displayName), `helixRepositoryProvider` (for `getUserProfile`), `blockedUsersControllerProvider` (Task 2), `authControllerProvider` (to gate moderation), `ChatController.sendModeration` (Task 5).
- Produces: `class UserCardSheet extends ConsumerStatefulWidget { UserCardSheet({required this.login, required this.displayName}); }` — a `showModalBottomSheet` wrapper `Future<void> showUserCard(BuildContext context, {required String login, required String displayName})`.

- [ ] **Step 1: Create `user_card_sheet.dart`**

```dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
import 'package:nice_tv/features/chat/data/chat_client.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_models.dart';

Future<void> showUserCard(
  BuildContext context, {
  required String login,
  required String displayName,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => UserCardSheet(login: login, displayName: displayName),
  );
}

class UserCardSheet extends ConsumerStatefulWidget {
  const UserCardSheet({super.key, required this.login, required this.displayName});

  final String login;
  final String displayName;

  @override
  ConsumerState<UserCardSheet> createState() => _UserCardSheetState();
}

class _UserCardSheetState extends ConsumerState<UserCardSheet> {
  late final Future<TwitchUserProfile?> _profile;

  @override
  void initState() {
    super.initState();
    _profile = ref
        .read(helixRepositoryProvider)
        .getUserProfile(login: widget.login);
  }

  Future<void> _moderate(String command) async {
    final auth = ref.read(authControllerProvider).value;
    if (auth?.isLoggedIn != true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in to moderate chat')),
      );
      return;
    }
    ref.read(chatControllerProvider.notifier).sendModeration(command);
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _confirmModeration(
    String title,
    String message,
    String command,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _moderate(command);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final auth = ref.watch(authControllerProvider).value;
    final blocked = ref.watch(blockedUsersControllerProvider);
    final isBlocked = blocked.contains(widget.login.toLowerCase());
    final isModerator =
        auth?.isLoggedIn == true && (auth?.login == widget.login.toLowerCase());

    return SafeArea(
      child: FutureBuilder<TwitchUserProfile?>(
        future: _profile,
        builder: (context, snapshot) {
          final user = snapshot.data;
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: user == null ||
                              user.profileImageUrl.isEmpty
                          ? null
                          : CachedNetworkImageProvider(user.profileImageUrl),
                      child: user == null || user.profileImageUrl.isEmpty
                          ? Text(
                              widget.displayName.isNotEmpty
                                  ? widget.displayName[0]
                                  : '?',
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '@${widget.login}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (user != null && user.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(user.description, style: theme.textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/profile/${widget.login}?userId=${user?.id}',
                        );
                      },
                      icon: const Icon(Icons.person_outline),
                      label: const Text('View profile'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final notifier = ref
                            .read(blockedUsersControllerProvider.notifier);
                        if (isBlocked) {
                          notifier.unblock(widget.login);
                        } else {
                          notifier.block(widget.login);
                        }
                        Navigator.pop(context);
                      },
                      icon: Icon(
                        isBlocked
                            ? Icons.block
                            : Icons.remove_circle_outline,
                      ),
                      label: Text(isBlocked ? 'Unblock' : 'Block'),
                    ),
                    if (isModerator) ...[
                      OutlinedButton.icon(
                        onPressed: () => _confirmModeration(
                          'Timeout ${widget.displayName}',
                          'Remove messages and restrict chatting for 10 minutes.',
                          '/timeout ${widget.login} 600',
                        ),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Timeout'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _confirmModeration(
                          'Ban ${widget.displayName}',
                          'Permanently ban this user from the channel.',
                          '/ban ${widget.login}',
                        ),
                        icon: const Icon(Icons.gavel_outlined),
                        label: const Text('Ban'),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
```

Note: `isModerator` is intentionally conservative (only the broadcaster sees moderation actions). Full mod-badge detection is out of scope; the underlying IRC server enforces permissions.

- [ ] **Step 2: Wire username tap into `ChatMessageTile`**

In `chat_panel.dart`, add `this.onUserTap` to `ChatMessageTile`:

```dart
    this.onReply,
    this.onUserTap,
  });

  final VoidCallback? onReply;
  final VoidCallback? onUserTap;
```

Replace the `TextSpan` for the display name (lines 557–564) with a `WidgetSpan` wrapping an `InkWell`:

```dart
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: onUserTap,
                    child: Text(
                      '${message.displayName}: ',
                      style: TextStyle(
                        color: message.isCheer ? cheerColor : color,
                        fontWeight: FontWeight.w700,
                        fontSize: fontSize,
                      ),
                    ),
                  ),
                ),
```

- [ ] **Step 3: Pass `onUserTap` from `_ChatPanelState.build`**

In the `ChatMessageTile` construction (lines 227–233), add:

```dart
                  onUserTap: () => showUserCard(
                    context,
                    login: msg.login,
                    displayName: msg.displayName,
                  ),
```

Add the import at the top of `chat_panel.dart`:

```dart
import 'package:nice_tv/features/chat/presentation/user_card_sheet.dart';
```

- [ ] **Step 4: Run analyze to verify compile**

Run: `flutter analyze lib/features/chat/presentation/user_card_sheet.dart lib/features/chat/presentation/chat_panel.dart`
Expected: No issues found.

- [ ] **Step 5: Format and commit**

Run: `dart format lib/features/chat/presentation/user_card_sheet.dart lib/features/chat/presentation/chat_panel.dart`
Run: `git add lib/features/chat/presentation/user_card_sheet.dart lib/features/chat/presentation/chat_panel.dart`
Run: `git commit -m "feat: add user card sheet with profile, block, and moderation actions"`

---

### Task 8: Blocked-users management in settings

**Files:**
- Modify: `lib/features/settings/presentation/settings_screen.dart`

**Interfaces:**
- Consumes: `blockedUsersControllerProvider` (Task 2), `channelProfileProvider` not needed.

- [ ] **Step 1: Add a Blocked users section**

In `settings_screen.dart`, add the import:

```dart
import 'package:nice_tv/features/chat/data/blocked_users_store.dart';
```

Inside the `ListView` children, after the `Chat` section (after the Density `SegmentedButton`, around line 114), insert:

```dart
          const SizedBox(height: 24),
          Text('Blocked users', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Consumer(
            builder: (context, ref, _) {
              final blocked = ref.watch(blockedUsersControllerProvider);
              if (blocked.isEmpty) {
                return Text(
                  'No blocked users. Block users from chat by tapping their name.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              }
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: blocked.map((login) {
                  return InputChip(
                    label: Text(login),
                    onDeleted: () => ref
                        .read(blockedUsersControllerProvider.notifier)
                        .unblock(login),
                  );
                }).toList(),
              );
            },
          ),
```

- [ ] **Step 2: Run analyze and commit**

Run: `flutter analyze lib/features/settings/presentation/settings_screen.dart`
Expected: No issues found.
Run: `dart format lib/features/settings/presentation/settings_screen.dart`
Run: `git add lib/features/settings/presentation/settings_screen.dart`
Run: `git commit -m "feat: add blocked-users management to settings"`

---

### Task 9: Full verification

**Files:**
- All files touched above.

- [x] **Step 1: Run all tests**

Run: `flutter test`
Expected: All tests pass (existing + new).

- [x] **Step 2: Run analyzer on the whole repo**

Run: `flutter analyze`
Expected: No issues found.

- [x] **Step 3: Format**

Run: `dart format .`
Expected: No diffs (already formatted).

---

### Task 9 verification results

- `flutter test`: 35 tests passed (new chat tests + existing suite).
- `flutter analyze`: No issues found.
- `dart format .`: 68 files, 0 changed.

## Self-Review Checklist

- Spec coverage: 1.1 User Cards (Task 7), 1.2 Chat Search (Tasks 4, 6), 1.4 Block/Ignore (Tasks 2, 6, 8, 7), 11.1 Moderation (Tasks 5, 7), 11.2 Room-state badges (Tasks 1, 5, 6), 11.3 History persistence (Tasks 3, 5, 6). All covered.
- No placeholders: every task has concrete code and exact commands.
- Type consistency: `RoomState.fromIrcTags`, `filterBlocked`, `searchMessages`, `ChatMessage.toJson/fromJson`, `ChatHistoryStore.read/write`, `BlockedUsersStore.read/add/remove`, `ChatController.sendModeration/replayHistory` are all defined once and reused consistently.