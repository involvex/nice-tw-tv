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

  static Future<bool> isSupported() async {
    try {
      return await _channel.invokeMethod<bool>('isPipSupported') ?? false;
    } on Object {
      return false;
    }
  }
}
