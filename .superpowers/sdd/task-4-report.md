feat: add theater mode toggle to watch screen

- Add `theaterMode` (bool, default false) to StreamerLayoutProfile with copyWith/toJson/fromJson support (persisted per-channel like chatPlacement/playerBackend)
- Update layout_profile_test.dart round-trip + add default test (61 tests pass)
- Add theater mode toggle button (Icons.theaters) in WatchScreen AppBar header; taps save updated profile (reactive via ref.watch)
- Theater layout variant: when active, chat is hidden and the player fills the screen via Column(Expanded(child: player))
- Run flutter analyze: No issues; dart format clean; flutter test: All 61 tests pass
