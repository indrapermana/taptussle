import 'package:flutter/services.dart';

/// Device-wide feedback for shared-phone matches. The platform silently handles
/// hardware that does not provide haptics.
abstract interface class HapticPlayer {
  void setEnabled(bool value);
  Future<void> preview();
  Future<void> paddleHit();
}

class HapticService implements HapticPlayer {
  HapticService({bool enabled = true}) : _enabled = enabled;

  bool _enabled;
  DateTime? _lastImpact;

  @override
  void setEnabled(bool value) => _enabled = value;

  @override
  Future<void> preview() => _impact(HapticFeedback.lightImpact);
  @override
  Future<void> paddleHit() => _impact(HapticFeedback.mediumImpact);

  Future<void> _impact(Future<void> Function() action) async {
    if (!_enabled) return;
    final now = DateTime.now();
    if (_lastImpact != null &&
        now.difference(_lastImpact!).inMilliseconds < 70) {
      return;
    }
    _lastImpact = now;
    try {
      await action();
    } catch (_) {
      // Haptics are an enhancement and must not interrupt a match.
    }
  }
}

/// Gives games a no-op haptic path in isolated model tests.
class HapticEffects {
  HapticEffects._();

  static HapticPlayer? _service;

  static void configure(HapticPlayer service) => _service = service;
  static void setEnabled(bool value) => _service?.setEnabled(value);
  static Future<void> preview() => _service?.preview() ?? Future.value();
  static Future<void> paddleHit() => _service?.paddleHit() ?? Future.value();
}
