import 'package:flutter/services.dart';

/// Dart wrapper over the Android kiosk platform channel.
///
/// All calls fail soft: on a non-Android target or an unimplemented method they
/// no-op rather than throw, so the app still runs (e.g. in a desktop preview).
class KioskService {
  static const MethodChannel _channel =
      MethodChannel('com.example.gridlock/kiosk');

  Future<void> startLock() => _invoke('startLock');

  Future<void> stopLock() => _invoke('stopLock');

  Future<void> enableImmersiveMode() => _invoke('enableImmersive');

  Future<void> keepScreenOn(bool on) => _invoke('keepScreenOn', {'on': on});

  Future<bool> isDeviceOwner() async {
    try {
      final result = await _channel.invokeMethod<bool>('isDeviceOwner');
      return result ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> _invoke(String method, [dynamic args]) async {
    try {
      await _channel.invokeMethod<void>(method, args);
    } on PlatformException {
      // Channel reachable but the platform side rejected the call — ignore.
    } on MissingPluginException {
      // Not running on Android (no channel handler) — ignore.
    }
  }
}
