import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/auth/data/auth_repository.dart';
import 'package:nice_tv/features/chat/data/badge_catalog.dart';
import 'package:nice_tv/features/chat/data/chat_client.dart';
import 'package:nice_tv/features/chat/data/chat_search.dart';
import 'package:nice_tv/features/chat/data/irc_message.dart';
import 'package:nice_tv/features/emotes/data/emote.dart';
import 'package:nice_tv/features/emotes/data/seventv_events.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({
    super.key,
    required this.channelLogin,
    required this.broadcasterId,
    this.densityOverride,
  });

  final String channelLogin;
  final String? broadcasterId;

  /// When set, overrides global chat density for this panel.
  final int? densityOverride;

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  var _suggestions = <Emote>[];
  ChatMessage? _replyingTo;
  final _searchController = TextEditingController();
  var _searchQuery = '';
  var _searching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatControllerProvider.notifier).connect(widget.channelLogin);
    });
    _input.addListener(_onInputChanged);
  }

  @override
  void dispose() {
    _input
      ..removeListener(_onInputChanged)
      ..dispose();
    _scroll.dispose();
    _focus.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onInputChanged() {
    final catalog = ref
        .read(channelEmotesControllerProvider(widget.broadcasterId ?? ''))
        .value;
    if (catalog == null) {
      setState(() => _suggestions = []);
      return;
    }
    final text = _input.text;
    final match = RegExp(r'(?:^|\s)(:?\w+)$').firstMatch(text);
    if (match == null) {
      setState(() => _suggestions = []);
      return;
    }
    final token = match.group(1)!.replaceFirst(':', '');
    setState(() => _suggestions = catalog.suggest(token));
  }

  void _applySuggestion(Emote emote) {
    final text = _input.text;
    final match = RegExp(r'(?:^|\s)(:?\w+)$').firstMatch(text);
    if (match == null) return;
    final start = match.start == 0 ? 0 : match.start + 1;
    final next = '${text.substring(0, start)}${emote.name} ';
    _input
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
    setState(() => _suggestions = []);
    _focus.requestFocus();
  }

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final parent = _replyingTo;
    ref
        .read(chatControllerProvider.notifier)
        .send(
          text,
          replyParentMsgId: parent?.id,
          replyEcho: parent == null
              ? null
              : ChatReplyParent(
                  messageId: parent.id,
                  userLogin: parent.login,
                  displayName: parent.displayName,
                  body: parent.message,
                ),
        );
    _input.clear();
    setState(() {
      _suggestions = [];
      _replyingTo = null;
    });
  }

  void _startReply(ChatMessage message) {
    if (message.system) return;
    setState(() => _replyingTo = message);
    _focus.requestFocus();
  }

  String _statusLabel(ChatLinkStatus status) {
    return switch (status) {
      ChatLinkStatus.connected => 'Connected',
      ChatLinkStatus.connecting => 'Connecting…',
      ChatLinkStatus.reconnecting => 'Reconnecting…',
      ChatLinkStatus.disconnected => 'Disconnected',
    };
  }

  Color _statusColor(ChatLinkStatus status, ColorScheme scheme) {
    return switch (status) {
      ChatLinkStatus.connected => scheme.primary,
      ChatLinkStatus.connecting ||
      ChatLinkStatus.reconnecting => scheme.tertiary,
      ChatLinkStatus.disconnected => scheme.error,
    };
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatControllerProvider);
    final auth = ref.watch(authControllerProvider).value;
    final emotesAsync = ref.watch(
      channelEmotesControllerProvider(widget.broadcasterId ?? ''),
    );
    final badgesAsync = ref.watch(
      channelBadgesControllerProvider(widget.broadcasterId ?? ''),
    );
    final density =
        widget.densityOverride ??
        ref.watch(settingsControllerProvider.select((s) => s.chatDensity));
    final pad = switch (density) {
      0 => 4.0,
      2 => 10.0,
      _ => 6.0,
    };
    final fontSize = switch (density) {
      0 => 12.0,
      2 => 16.0,
      _ => 14.0,
    };

    ref.listen(chatControllerProvider, (prev, next) {
      if (_scroll.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scroll.hasClients) {
            _scroll.jumpTo(_scroll.position.maxScrollExtent);
          }
        });
      }
    });

    final catalog = emotesAsync.value ?? EmoteCatalog();
    final badges = badgesAsync.value ?? BadgeCatalog();
    final loggedIn = auth?.isLoggedIn == true;
    final canSend = chat.canSend;
    final hint = !loggedIn
        ? 'Sign in to chat'
        : !chat.connected
        ? 'Waiting for connection…'
        : _replyingTo != null
        ? 'Reply to ${_replyingTo!.displayName}'
        : 'Send a message';

    final visibleMessages = _searching
        ? searchMessages(chat.messages, _searchQuery)
        : chat.messages;

    return Column(
      children: [
        if (chat.status != ChatLinkStatus.connected)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 10,
                    color: _statusColor(
                      chat.status,
                      Theme.of(context).colorScheme,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusLabel(chat.status),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ),
                  if (chat.status == ChatLinkStatus.disconnected ||
                      chat.status == ChatLinkStatus.reconnecting)
                    TextButton(
                      onPressed: () =>
                          ref.read(chatControllerProvider.notifier).retryNow(),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ),
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
                if (chat.roomState.slow) _RoomBadge(label: 'Slow mode'),
                if (chat.roomState.followersOnly)
                  _RoomBadge(label: 'Followers-only'),
                if (chat.roomState.subscribersOnly)
                  _RoomBadge(label: 'Subs-only'),
                if (chat.roomState.emotesOnly) _RoomBadge(label: 'Emote-only'),
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
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: pad),
            itemCount: visibleMessages.length,
            itemBuilder: (context, index) {
              final msg = visibleMessages[index];
              return Padding(
                padding: EdgeInsets.symmetric(vertical: pad / 2),
                child: ChatMessageTile(
                  message: msg,
                  catalog: catalog,
                  badges: badges,
                  fontSize: fontSize,
                  onReply: canSend ? () => _startReply(msg) : null,
                ),
              );
            },
          ),
        ),
        if (_replyingTo != null)
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.reply, size: 18),
              title: Text(
                'Replying to ${_replyingTo!.displayName}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              subtitle: Text(
                _replyingTo!.message,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _replyingTo = null),
              ),
            ),
          ),
        if (_suggestions.isNotEmpty)
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final emote = _suggestions[index];
                return ActionChip(
                  avatar: CachedNetworkImage(
                    imageUrl: emote.url,
                    width: 20,
                    height: 20,
                  ),
                  label: Text(emote.name),
                  onPressed: () => _applySuggestion(emote),
                );
              },
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
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
                Expanded(
                  child: TextField(
                    controller: _input,
                    focusNode: _focus,
                    enabled: canSend,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) {
                      if (canSend) _send();
                    },
                    decoration: InputDecoration(hintText: hint, isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                if (!loggedIn)
                  FilledButton.tonal(
                    onPressed: () => context.push('/login'),
                    child: const Text('Sign in'),
                  )
                else
                  IconButton.filled(
                    onPressed: canSend ? _send : null,
                    icon: const Icon(Icons.send),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openEmotePicker(EmoteCatalog catalog) async {
    final selected = await showModalBottomSheet<Emote>(
      context: context,
      isScrollControlled: true,
      builder: (context) => EmotePickerSheet(catalog: catalog),
    );
    if (selected == null) return;
    final next = '${_input.text}${selected.name} ';
    _input
      ..text = next
      ..selection = TextSelection.collapsed(offset: next.length);
  }
}

class EmotePickerSheet extends StatefulWidget {
  const EmotePickerSheet({super.key, required this.catalog});

  final EmoteCatalog catalog;

  @override
  State<EmotePickerSheet> createState() => _EmotePickerSheetState();
}

class _EmotePickerSheetState extends State<EmotePickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();

  static const _providers = <(EmoteProvider?, String)>[
    (null, 'All'),
    (EmoteProvider.twitch, 'Twitch'),
    (EmoteProvider.bttv, 'BTTV'),
    (EmoteProvider.ffz, 'FFZ'),
    (EmoteProvider.sevenTv, '7TV'),
  ];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: _providers.length, vsync: this);
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Emotes'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search emotes',
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabs: [for (final entry in _providers) Tab(text: entry.$2)],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  for (final entry in _providers)
                    _EmoteGrid(
                      emotes: widget.catalog.filter(
                        provider: entry.$1,
                        query: _search.text,
                      ),
                      controller: scrollController,
                      onSelect: (emote) => Navigator.pop(context, emote),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _EmoteGrid extends StatelessWidget {
  const _EmoteGrid({
    required this.emotes,
    required this.controller,
    required this.onSelect,
  });

  final List<Emote> emotes;
  final ScrollController controller;
  final ValueChanged<Emote> onSelect;

  @override
  Widget build(BuildContext context) {
    if (emotes.isEmpty) {
      return const Center(child: Text('No emotes'));
    }
    return GridView.builder(
      controller: controller,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: emotes.length,
      itemBuilder: (context, index) {
        final emote = emotes[index];
        return InkWell(
          onTap: () => onSelect(emote),
          child: Tooltip(
            message: emote.name,
            child: CachedNetworkImage(imageUrl: emote.url),
          ),
        );
      },
    );
  }
}

class ChatMessageTile extends StatelessWidget {
  const ChatMessageTile({
    super.key,
    required this.message,
    required this.catalog,
    required this.badges,
    required this.fontSize,
    this.onReply,
  });

  final ChatMessage message;
  final EmoteCatalog catalog;
  final BadgeCatalog badges;
  final double fontSize;
  final VoidCallback? onReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (message.system) {
      return Text(
        message.message,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontStyle: FontStyle.italic,
          fontSize: fontSize - 1,
        ),
      );
    }

    final color = _parseColor(message.color) ?? theme.colorScheme.primary;
    final segments = tokenizeMessage(message.message, catalog);
    final resolvedBadges = badges.resolveAll(message.badges);
    final cheerColor = theme.colorScheme.tertiary;

    return InkWell(
      onLongPress: onReply,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.replyParent case final parent?)
            Padding(
              padding: const EdgeInsets.only(bottom: 2, left: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.subdirectory_arrow_right,
                    size: fontSize,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${parent.displayName}: ${parent.body}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Text.rich(
            TextSpan(
              children: [
                for (final badge in resolvedBadges)
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: CachedNetworkImage(
                        imageUrl: badge.imageUrl,
                        height: fontSize + 2,
                        width: fontSize + 2,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                if (message.isCheer)
                  TextSpan(
                    text: 'Cheer ${message.bits} ',
                    style: TextStyle(
                      color: cheerColor,
                      fontWeight: FontWeight.w800,
                      fontSize: fontSize - 1,
                    ),
                  ),
                TextSpan(
                  text: '${message.displayName}: ',
                  style: TextStyle(
                    color: message.isCheer ? cheerColor : color,
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                  ),
                ),
                for (final segment in segments)
                  switch (segment) {
                    TextSegment(:final value) => TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: fontSize,
                        color: message.isCheer ? cheerColor : null,
                        fontWeight: message.isCheer ? FontWeight.w600 : null,
                      ),
                    ),
                    EmoteSegment(:final emote) => WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 1),
                        child: CachedNetworkImage(
                          imageUrl: emote.url,
                          height: fontSize + 8,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  },
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    if (cleaned.length != 6) return null;
    return Color(int.parse('FF$cleaned', radix: 16));
  }
}

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
