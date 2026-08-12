import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nice_tv/features/home/data/helix_repository.dart';
import 'package:nice_tv/features/home/data/twitch_stream.dart';
import 'package:nice_tv/features/home/presentation/autoplay_feed.dart';
import 'package:nice_tv/features/settings/data/settings_controller.dart';

class CategoryAutoplayFeedScreen extends ConsumerStatefulWidget {
  const CategoryAutoplayFeedScreen({
    super.key,
    required this.gameId,
    required this.name,
  });

  final String gameId;
  final String name;

  @override
  ConsumerState<CategoryAutoplayFeedScreen> createState() =>
      _CategoryAutoplayFeedScreenState();
}

class _CategoryAutoplayFeedScreenState
    extends ConsumerState<CategoryAutoplayFeedScreen> {
  final List<TwitchStream> _streams = [];
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
        _streams.addAll(filtered);
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black45,
        title: Text(widget.name),
        titleTextStyle: Theme.of(context).textTheme.titleMedium
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Card feed',
            onPressed: () => context.pop(),
            icon: const Icon(Icons.view_agenda_outlined),
          ),
        ],
      ),
      body: _loading && _streams.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _streams.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : AutoplayFeed(
              streams: _streams,
              onNearEnd: _cursor != null ? () => _load(more: true) : () {},
            ),
    );
  }
}
