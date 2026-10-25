import 'package:flutter/services.dart';

/// Android Picture-in-Picture helper via platform channel.
class PipService {
  static const _channel = MethodChannel('tv.nice.nice_tv/pip');

  static Future<bool> enter({int width = 16, int height = 9}) async {
    try {
      final result = await _channel.invokeMethod<bool>('enterPip', {
        'width': width,
        'height': height,
      });
      return result ?? false;
    } on Object {
      return false;
    }
  }

  /// Enables or disables automatic PiP when the user leaves the app
  /// (Home / overview). Live Watch screens should enable this; clear on
  /// dispose. On API 31+ this also sets [setAutoEnterEnabled].
  static Future<void> setAutoEnter(
    bool enabled, {
    int width = 16,
    int height = 9,
  }) async {
    try {
      await _channel.invokeMethod<void>('setAutoEnter', {
        'enabled': enabled,
        'width': width,
        'height': height,
      });
    } on Object {
      // Unsupported host / tests.
    }
  }

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } on Object {
      return false;
    }
  }

  /// Returns `true` when the app is currently in Picture-in-Picture mode.
  /// Falls back to `false` on platforms/channels that don't implement it.
  static Future<bool> isInPipMode() async {
    try {
      return await _channel.invokeMethod<bool>('isInPipMode') ?? false;
    } on Object {
      return false;
    }
  }
}
