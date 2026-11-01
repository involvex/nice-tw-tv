import 'package:flutter_test/flutter_test.dart';
import 'package:nice_tv/core/widgets/nice_error_pane.dart';

void main() {
  group('friendlyErrorMessage', () {
    test('detects offline / network failures', () {
      expect(
        friendlyErrorMessage(Exception('SocketException: Failed host lookup')),
        contains('offline'),
      );
    });

    test('detects timeouts', () {
      expect(
        friendlyErrorMessage('TimeoutException after 0:00:15.000000'),
        contains('too long'),
      );
    });

    test('falls back for unknown errors', () {
      expect(friendlyErrorMessage('weird'), 'Something went wrong');
    });
  });
}
