import 'package:flutter/services.dart';

class ScreenProtectionService {
  static const MethodChannel _channel = MethodChannel('com.ankith.mymail/security');

  /// Dynamically enables or disables Android FLAG_SECURE window flag.
  static Future<void> setProtection(bool enabled) async {
    try {
      await _channel.invokeMethod('setScreenCaptureProtection', {'enabled': enabled});
    } catch (_) {
      // Ignored if running on non-Android platform or in unit tests
    }
  }
}
