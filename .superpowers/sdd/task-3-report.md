feat: search within watch history

- Extract `filterHistory(List<HistoryEntry> items, String query)` in data layer (matches
  plan interface; case-insensitive match on userLogin/userName/title/gameName; sorts
  by watchedAt descending)
- Replace HistorySearchController controller with Riverpod 3 idioms:
  `historySearchQueryProvider` (NotifierProvider<String>) + `filteredHistoryProvider`
  (derived Provider) — derived filtering avoids controller/_initial sync drift
- Wire search bar into HistoryScreen (IconButton toggles; TextField.onChanged updates
  query; AppBar shows "No results for ..." empty state)
- Fix history_search_test.dart: removed duplicated local _filterHistory, now tests the
  real `filterHistory`; corrected recency test expectations ('Other Stream' vs 'Test Stream')
- Run flutter analyze: No issues; flutter test: All 53 tests pass -> 60 total pass
