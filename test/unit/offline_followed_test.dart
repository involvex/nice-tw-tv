import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/features/home/data/offline_followed.dart';

void main() {
  group('offlineFollowed', () {
    test('keeps channels not currently live', () {
      final all = [
        (id: '1', login: 'a', displayName: 'A'),
        (id: '2', login: 'b', displayName: 'B'),
        (id: '3', login: 'c', displayName: 'C'),
      ];
      final offline = offlineFollowed(all, {'2'});
      expect(offline.map((c) => c.login), ['a', 'c']);
    });

    test('returns all when nothing is live', () {
      final all = [
        (id: '1', login: 'a', displayName: 'A'),
        (id: '2', login: 'b', displayName: 'B'),
      ];
      expect(offlineFollowed(all, {}).length, 2);
    });

    test('returns empty when everything is live', () {
      final all = [(id: '1', login: 'a', displayName: 'A')];
      expect(offlineFollowed(all, {'1'}), isEmpty);
    });
  });
}
