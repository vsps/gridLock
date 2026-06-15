import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Dart wrapper over the Android kiosk platform channel.
///
/// All calls fail soft: on a non-Android target or an unimplemented method they
/// no-op rather than throw, so the app still runs (e.g. in a desktop preview).
///
/// Exposes [isLocked] so the UI can react when screen pinning is exited
/// (e.g. Back + Recents held by a parent).
class KioskService extends ChangeNotifier {
  KioskService() {
    _channel.setMethodCallHandler(_onPlatformCall);
  }

  static const MethodChannel _channel =
      MethodChannel('com.example.gridlock/kiosk');

  bool _locked = false;
  bool get isLocked => _locked;

  Future<void> startLock() async {
    await _invoke('startLock');
    _locked = true;
    notifyListeners();
  }

  Future<void> stopLock() async {
    await _invoke('stopLock');
    _locked = false;
    notifyListeners();
  }

  Future<void> enableImmersiveMode() => _invoke('enableImmersive');

  Future<void> keepScreenOn(bool on) => _invoke('keepScreenOn', {'on': on});

  // ---- platform → Dart -------------------------------------------------------

  Future<void> _onPlatformCall(MethodCall call) async {
    switch (call.method) {
      case 'onLockExited':
        _locked = false;
        notifyListeners();
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
