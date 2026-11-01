import 'package:flutter/material.dart';

/// Maps raw exceptions to short, user-facing copy.
String friendlyErrorMessage(
  Object? error, {
  String fallback = 'Something went wrong',
}) {
  if (error == null) return fallback;
  final text = error.toString().toLowerCase();
  if (text.contains('socketexception') ||
      text.contains('failed host lookup') ||
      text.contains('network is unreachable') ||
      text.contains('connection refused') ||
      text.contains('connection reset')) {
    return 'You’re offline or the network is unavailable.';
  }
  if (text.contains('timeout') || text.contains('timed out')) {
    return 'Twitch took too long to respond. Try again.';
  }
  if (text.contains('401') || text.contains('unauthorized')) {
    return 'Session expired. Sign in again and retry.';
  }
  if (text.contains('403') || text.contains('forbidden')) {
    return 'Twitch denied this request. Try again later.';
  }
  if (text.contains('429') || text.contains('rate limit')) {
    return 'Too many requests. Wait a moment and retry.';
  }
  if (text.contains('500') ||
      text.contains('502') ||
      text.contains('503') ||
      text.contains('twitch')) {
    return 'Twitch is having trouble right now. Try again.';
  }
  return fallback;
}

/// Standard error pane with Retry, matching home feed chrome.
class NiceErrorPane extends StatelessWidget {
  const NiceErrorPane({
    super.key,
    required this.message,
    required this.onRetry,
    this.icon = Icons.error_outline,
  });

  final String message;
  final VoidCallback onRetry;
  final IconData icon;

  factory NiceErrorPane.fromError({
    Key? key,
    required Object error,
    required VoidCallback onRetry,
    String fallback = 'Something went wrong',
  }) {
    return NiceErrorPane(
      key: key,
      message: friendlyErrorMessage(error, fallback: fallback),
      onRetry: onRetry,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.error),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
