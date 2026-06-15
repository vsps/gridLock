import 'package:flutter/foundation.dart';

/// States of the secret two-finger unlock gesture.
enum UnlockState {
  idle,
  tlHeld, // only top-left finger down
  brHeld, // only bottom-right finger down
  bothHeld, // both down, counting toward the hold threshold
  awaitingSwipes, // hold satisfied, watching for the opposing slides
  unlocked,
  failed,
}

/// Multi-touch unlock state machine.
///
/// Gesture: long-press the top-left corner AND bottom-right corner
/// simultaneously for [holdMs], then slide the top-left finger RIGHT and the
/// bottom-right finger LEFT, each covering at least [swipeFraction] of the
/// screen width.
///
/// Pure Dart so it can be unit tested without Flutter: it consumes a simple
/// (pointerId, x, y, timeMs) event stream and a periodic [tick]. The host
/// widget supplies positions from raw `Listener` pointer events and time from a
/// monotonic clock.
class UnlockGestureFsm extends ChangeNotifier {
  UnlockGestureFsm({
    required this.screenWidth,
    required this.screenHeight,
    this.holdMs = 1500,
    this.zoneFraction = 0.25,
    this.swipeFraction = 0.40,
  });

  double screenWidth;
  double screenHeight;
  final int holdMs;
  final double zoneFraction;
  final double swipeFraction;

  UnlockState _state = UnlockState.idle;
  UnlockState get state => _state;
  bool get isUnlocked => _state == UnlockState.unlocked;

  int? _tlPointer;
  int? _brPointer;
  int _bothStartMs = 0;

  // Latest known x for each tracked pointer.
  double _tlX = 0;
  double _brX = 0;

  // Swipe origins captured at the bothHeld -> awaitingSwipes transition, so
  // drift during the hold does NOT count toward swipe distance.
  double _tlOriginX = 0;
  double _brOriginX = 0;

  void updateScreenSize(double width, double height) {
    if (width > 0) screenWidth = width;
    if (height > 0) screenHeight = height;
  }

  bool _inTopLeft(double x, double y) =>
      x <= screenWidth * zoneFraction && y <= screenHeight * zoneFraction;

  bool _inBottomRight(double x, double y) =>
      x >= screenWidth * (1 - zoneFraction) &&
      y >= screenHeight * (1 - zoneFraction);

  void _setState(UnlockState s) {
    if (_state != s) {
      _state = s;
      notifyListeners();
    }
  }

  void pointerDown(int pointer, double x, double y, int timeMs) {
    if (_state == UnlockState.unlocked) return;
    if (_state == UnlockState.failed) _state = UnlockState.idle;

    var assigned = false;
    if (_tlPointer == null && _inTopLeft(x, y)) {
      _tlPointer = pointer;
      _tlX = x;
      assigned = true;
    } else if (_brPointer == null && _inBottomRight(x, y)) {
      _brPointer = pointer;
      _brX = x;
      assigned = true;
    }
    if (!assigned) return;

    final bothDown = _tlPointer != null && _brPointer != null;
    if (bothDown &&
        _state != UnlockState.bothHeld &&
        _state != UnlockState.awaitingSwipes) {
      _bothStartMs = timeMs;
      _setState(UnlockState.bothHeld);
    } else {
      tick(timeMs);
    }
  }

  void pointerMove(int pointer, double x, double y, int timeMs) {
    if (_state == UnlockState.unlocked) return;
    if (pointer == _tlPointer) {
      _tlX = x;
    } else if (pointer == _brPointer) {
      _brX = x;
    } else {
      return;
    }
    tick(timeMs);
    if (_state == UnlockState.awaitingSwipes) _checkSwipe();
  }

  void pointerUp(int pointer, int timeMs) {
    if (_state == UnlockState.unlocked) return;
    if (pointer == _tlPointer || pointer == _brPointer) {
      _fail();
    }
  }

  /// Re-evaluates time-based transitions. Called on pointer events and by a
  /// periodic timer so a perfectly still hold still advances.
  void tick(int timeMs) {
    if (_state == UnlockState.unlocked || _state == UnlockState.failed) return;

    final bothDown = _tlPointer != null && _brPointer != null;
    if (!bothDown) {
      if (_tlPointer != null) {
        _setState(UnlockState.tlHeld);
      } else if (_brPointer != null) {
        _setState(UnlockState.brHeld);
      } else {
        _setState(UnlockState.idle);
      }
      return;
    }

    if (_state != UnlockState.bothHeld &&
        _state != UnlockState.awaitingSwipes) {
      _bothStartMs = timeMs;
      _setState(UnlockState.bothHeld);
      return;
    }

    if (_state == UnlockState.bothHeld && timeMs - _bothStartMs >= holdMs) {
      _tlOriginX = _tlX;
      _brOriginX = _brX;
      _setState(UnlockState.awaitingSwipes);
    }
  }

  void _checkSwipe() {
    final minSwipe = screenWidth * swipeFraction;
    final tlDelta = _tlX - _tlOriginX; // expect positive (rightward)
    final brDelta = _brX - _brOriginX; // expect negative (leftward)
    if (tlDelta >= minSwipe && brDelta <= -minSwipe) {
      _setState(UnlockState.unlocked);
    }
  }

  void _fail() {
    _clearPointers();
    _setState(UnlockState.failed);
  }

  void _clearPointers() {
    _tlPointer = null;
    _brPointer = null;
    _bothStartMs = 0;
    _tlX = _brX = _tlOriginX = _brOriginX = 0;
  }

  void reset() {
    _clearPointers();
    _setState(UnlockState.idle);
  }
}
