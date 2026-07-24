import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/watch/presentation/twitch_embed_player.dart';

/// Full-screen vertical swipe feed with autoplay for the focused page.
class AutoplayFeed extends ConsumerStatefulWidget {
  const AutoplayFeed({
    super.key,
    required this.streams,
    required this.onNearEnd,
  });

  final List<TwitchStream> streams;
  final VoidCallback onNearEnd;

  @override
  ConsumerState<AutoplayFeed> createState() => _AutoplayFeedState();
}

class _AutoplayFeedState extends ConsumerState<AutoplayFeed> {
  late final PageController _controller;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.streams.isEmpty) {
      return const Center(child: Text('No live streams'));
    }

    return PageView.builder(
      controller: _controller,
      scrollDirection: Axis.vertical,
      itemCount: widget.streams.length,
      onPageChanged: (index) {
        setState(() => _index = index);
        if (index >= widget.streams.length - 3) {
          widget.onNearEnd();
        }
      },
      itemBuilder: (context, index) {
        final stream = widget.streams[index];
        final active = index == _index;
        return _AutoplayPage(stream: stream, active: active);
      },
    );
  }
}

class _AutoplayPage extends StatelessWidget {
  const _AutoplayPage({required this.stream, required this.active});

  final TwitchStream stream;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(
          color: Colors.black,
          child: active
              ? TwitchEmbedPlayer(
                  key: ValueKey('autoplay-${stream.id}'),
                  channelLogin: stream.userLogin,
                )
              : const SizedBox.expand(),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24 + bottom,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.push(
                  '/profile/${stream.userLogin}?userId=${stream.userId}',
                ),
                child: Text(
                  stream.userName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    shadows: const [
                      Shadow(blurRadius: 8, color: Colors.black54),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stream.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: Colors.white,
                  shadows: const [
                    Shadow(blurRadius: 8, color: Colors.black54),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stream.gameName,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () {
                      final uri = Uri(
                        path: '/watch/${stream.userLogin}',
                        queryParameters: {
                          'title': stream.title,
                          'userId': stream.userId,
                        },
                      );
                      context.push(uri.toString());
                    },
                    child: const Text('Open watch'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CategoryStreamsScreen extends ConsumerStatefulWidget {
  const CategoryStreamsScreen({
    super.key,
    required this.gameId,
    required this.name,
  });

  final String gameId;
  final String name;

  @override
  ConsumerState<CategoryStreamsScreen> createState() =>
      _CategoryStreamsScreenState();
}

class _CategoryStreamsScreenState extends ConsumerState<CategoryStreamsScreen> {
  var _streams = <TwitchStream>[];
  String? _cursor;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // ignore: discarded_futures
    _load();
  }

  Future<void> _load({bool more = false}) async {
    if (!more) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final page = await ref
          .read(helixRepositoryProvider)
          .getStreamsByGame(gameId: widget.gameId, cursor: more ? _cursor : null);
      setState(() {
        _streams = more ? [..._streams, ...page.streams] : page.streams;
        _cursor = page.cursor;
        _loading = false;
      });
    } on Object catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _loading && _streams.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _streams.isEmpty
          ? Center(child: Text(_error!))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _streams.length + (_cursor != null ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= _streams.length) {
                  // ignore: discarded_futures
                  _load(more: true);
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final stream = _streams[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(stream.title, maxLines: 2),
                  subtitle: Text(stream.userName),
                  onTap: () {
                    final uri = Uri(
                      path: '/watch/${stream.userLogin}',
                      queryParameters: {
                        'title': stream.title,
                        'userId': stream.userId,
                      },
                    );
                    context.push(uri.toString());
                  },
                );
              },
            ),
    );
  }
}
