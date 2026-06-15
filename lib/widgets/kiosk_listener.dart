import 'dart:async';

import 'package:flutter/widgets.dart';

import '../gestures/unlock_gesture_fsm.dart';

/// Wraps [child] in an opaque [Listener] and feeds raw pointer events to an
/// [UnlockGestureFsm]. Calls [onUnlock] once the secret gesture completes.
///
/// A monotonic [Stopwatch] supplies time (so the FSM never depends on wall
/// clock), and a periodic timer ticks the FSM so a perfectly still hold still
/// advances past the hold threshold.
class KioskListener extends StatefulWidget {
  const KioskListener({
    super.key,
    required this.child,
    required this.onUnlock,
  });

  final Widget child;
  final VoidCallback onUnlock;

  @override
  State<KioskListener> createState() => _KioskListenerState();
}

class _KioskListenerState extends State<KioskListener> {
  late final UnlockGestureFsm _fsm;
  final Stopwatch _clock = Stopwatch()..start();
  Timer? _ticker;

  int get _now => _clock.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _fsm = UnlockGestureFsm(screenWidth: 1, screenHeight: 1)..addListener(_onFsm);
    _ticker = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) => _fsm.tick(_now),
    );
  }

  void _onFsm() {
    if (_fsm.isUnlocked) {
      _fsm.reset();
      widget.onUnlock();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _fsm.removeListener(_onFsm);
    _fsm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _fsm.updateScreenSize(constraints.maxWidth, constraints.maxHeight);
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) => _fsm.pointerDown(
              e.pointer, e.localPosition.dx, e.localPosition.dy, _now),
          onPointerMove: (e) => _fsm.pointerMove(
              e.pointer, e.localPosition.dx, e.localPosition.dy, _now),
          onPointerUp: (e) => _fsm.pointerUp(e.pointer, _now),
          onPointerCancel: (e) => _fsm.pointerUp(e.pointer, _now),
          child: widget.child,
        );
      },
    );
  }
}
