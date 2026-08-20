import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/history/data/history_entry.dart';
import 'package:nice_tv/features/history/data/history_search_controller.dart';

void main() {
  test('filters history by user name', () {
    final entries = [
      HistoryEntry(
        userLogin: 'test_user',
        userName: 'Test User',
        title: 'Test Stream',
        thumbnailUrl: 'https://example.com/thumbs/test.jpg',
        watchedAt: DateTime.now(),
      ),
      HistoryEntry(
        userLogin: 'other_user',
        userName: 'Other User',
        title: 'Other Stream',
        thumbnailUrl: 'https://example.com/thumbs/other.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, 'Test');
    expect(results.length, 1);
    expect(results.first.userName, 'Test User');
  });

  test('filters history by title', () {
    final entries = [
      HistoryEntry(
        userLogin: 'user1',
        userName: 'User One',
        title: 'Minecraft Survival',
        thumbnailUrl: 'https://example.com/1.jpg',
        watchedAt: DateTime.now(),
      ),
      HistoryEntry(
        userLogin: 'user2',
        userName: 'User Two',
        title: 'Just Chatting',
        thumbnailUrl: 'https://example.com/2.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, 'Minecraft');
    expect(results.length, 1);
    expect(results.first.title, 'Minecraft Survival');
  });

  test('filters history by game name', () {
    final entries = [
      HistoryEntry(
        userLogin: 'user1',
        userName: 'User One',
        title: 'Long Title',
        gameName: 'Valorant',
        thumbnailUrl: 'https://example.com/1.jpg',
        watchedAt: DateTime.now(),
      ),
      HistoryEntry(
        userLogin: 'user2',
        userName: 'User Two',
        title: 'Long Title',
        gameName: 'League of Legends',
        thumbnailUrl: 'https://example.com/2.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, 'Valorant');
    expect(results.length, 1);
    expect(results.first.gameName, 'Valorant');
  });

  test('case insensitive search', () {
    final entries = [
      HistoryEntry(
        userLogin: 'user1',
        userName: 'User One',
        title: 'Test Stream',
        thumbnailUrl: 'https://example.com/1.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, 'TEST');
    expect(results.length, 1);
  });

  test('no results when query does not match', () {
    final entries = [
      HistoryEntry(
        userLogin: 'user1',
        userName: 'User One',
        title: 'Test Stream',
        thumbnailUrl: 'https://example.com/1.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, 'Nonexistent');
    expect(results.length, 0);
  });

  test('empty query returns all entries sorted by recency', () {
    final entries = [
      HistoryEntry(
        userLogin: 'user1',
        userName: 'User One',
        title: 'Test Stream',
        thumbnailUrl: 'https://example.com/1.jpg',
        watchedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      HistoryEntry(
        userLogin: 'user2',
        userName: 'User Two',
        title: 'Other Stream',
        thumbnailUrl: 'https://example.com/2.jpg',
        watchedAt: DateTime.now(),
      ),
    ];

    final results = filterHistory(entries, '');
    expect(results.length, 2);
    expect(results.first.title, 'Other Stream');
    expect(results.last.title, 'Test Stream');
  });
}
