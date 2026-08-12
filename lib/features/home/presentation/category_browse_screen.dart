import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/home/presentation/home_screen.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class CategoryBrowseScreen extends ConsumerStatefulWidget {
  const CategoryBrowseScreen({
    super.key,
    required this.gameId,
    required this.name,
  });

  final String gameId;
  final String name;

  @override
  ConsumerState<CategoryBrowseScreen> createState() =>
      _CategoryBrowseScreenState();
}

class _CategoryBrowseScreenState extends ConsumerState<CategoryBrowseScreen> {
  var _streams = <TwitchStream>[];
  String? _cursor;
  var _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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
      final settings = ref.read(settingsControllerProvider);
      final page = await ref
          .read(helixRepositoryProvider)
          .getStreamsByGame(
            gameId: widget.gameId,
            cursor: more ? _cursor : null,
            language: settings.discoveryLanguage,
            type: 'live',
          );
      final filtered = HelixRepository.applyDiscoveryFilters(
        streams: page.streams,
        language: settings.discoveryLanguage,
        hideMature: settings.discoveryHideMature,
        sortOrder: settings.discoverySortOrder,
      );
      setState(() {
        _streams = more ? [..._streams, ...filtered] : filtered;
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

  Future<void> _onRefresh() async {
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.name),
        actions: [
          IconButton(
            tooltip: 'Autoplay feed',
            onPressed: () => context.push(
              '/category/${widget.gameId}/autoplay?name=${Uri.encodeComponent(widget.name)}',
            ),
            icon: const Icon(Icons.swipe_vertical),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        child: _loading && _streams.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              )
            : _error != null && _streams.isEmpty
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _onRefresh,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : _streams.isEmpty
            ? ListView(
                children: [
                  SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'No live streams in ${widget.name}.',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                itemCount: _streams.length + (_cursor != null ? 1 : 0),
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  if (index >= _streams.length) {
                    _load(more: true);
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  return StreamCard(stream: _streams[index]);
                },
              ),
      ),
    );
  }
}
