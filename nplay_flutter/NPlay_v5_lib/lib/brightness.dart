import 'package:flutter/services.dart';

/// Real screen brightness for this app's window (0.0 - 1.0).
/// Goes all the way to 100% even if the phone setting is lower.
class Bright {
  static const MethodChannel _c = MethodChannel('nplay/brightness');

  static Future<double> current() async {
    try {
      final v = await _c.invokeMethod<double>('get');
      return (v ?? 0.5).clamp(0.02, 1.0).toDouble();
    } catch (_) {
      return 0.5;
    }
  }

  static Future<void> set(double v) async {
    try {
      await _c.invokeMethod('set', {'v': v});
    } catch (_) {}
  }

  static Future<void> reset() async {
    try {
      await _c.invokeMethod('reset');
    } catch (_) {}
  }
}
