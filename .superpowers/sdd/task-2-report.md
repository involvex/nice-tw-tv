feat: add VOD chapters data layer

- Implement VodChapter and VodChapters models with JSON parsing (seek_seconds / seekSeconds support)
- Add getVodChapters(String vodId) method to HelixRepository calling /helix/videos/chapters
- Create unit test for VodChapters.fromJson parsing (3 chapters with mixed title formats)
- Run flutter analyze: No issues
- Run flutter test: All 53 unit tests pass