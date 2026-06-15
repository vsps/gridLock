import 'package:flutter_test/flutter_test.dart';
import 'package:gridlock/gestures/unlock_gesture_fsm.dart';

void main() {
  // 1000x1000 screen: TL zone <= (250,250), BR zone >= (750,750),
  // hold = 1500ms, min swipe = 400px.
  UnlockGestureFsm makeFsm() =>
      UnlockGestureFsm(screenWidth: 1000, screenHeight: 1000);

  group('UnlockGestureFsm', () {
    test('full gesture unlocks', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0); // top-left
      fsm.pointerDown(2, 990, 990, 0); // bottom-right
      expect(fsm.state, UnlockState.bothHeld);

      fsm.tick(1500); // hold satisfied
      expect(fsm.state, UnlockState.awaitingSwipes);

      fsm.pointerMove(1, 410, 10, 1600); // TL slides right 400px
      expect(fsm.isUnlocked, isFalse, reason: 'BR has not slid yet');

      fsm.pointerMove(2, 590, 990, 1700); // BR slides left 400px
      expect(fsm.isUnlocked, isTrue);
    });

    test('drift during the hold does NOT count toward swipe distance', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0);
      fsm.pointerDown(2, 990, 990, 0);

      // Finger drifts during the hold from x=10 to x=200.
      fsm.pointerMove(1, 200, 10, 500);
      expect(fsm.state, UnlockState.bothHeld);

      fsm.tick(1500); // origin captured here = 200 (drifted), not 10
      expect(fsm.state, UnlockState.awaitingSwipes);

      // A swipe to x=410 is 400px from the original down (10) but only 210px
      // from the post-hold origin (200) — must NOT unlock.
      fsm.pointerMove(1, 410, 10, 1600);
      fsm.pointerMove(2, 590, 990, 1700);
      expect(fsm.isUnlocked, isFalse);

      // Completing the swipe from the true origin does unlock.
      fsm.pointerMove(1, 600, 10, 1800); // 600 - 200 = 400
      expect(fsm.isUnlocked, isTrue);
    });

    test('releasing a finger before unlock fails', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0);
      fsm.pointerDown(2, 990, 990, 0);
      fsm.pointerUp(1, 100);
      expect(fsm.state, UnlockState.failed);
    });

    test('swiping before the hold completes is ignored', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0);
      fsm.pointerDown(2, 990, 990, 0);

      // Only 1000ms elapsed — still holding.
      fsm.pointerMove(1, 410, 10, 1000);
      fsm.pointerMove(2, 590, 990, 1000);
      expect(fsm.state, UnlockState.bothHeld);
      expect(fsm.isUnlocked, isFalse);
    });

    test('wrong swipe direction does not unlock', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0);
      fsm.pointerDown(2, 990, 990, 0);
      fsm.tick(1500);

      // TL slides LEFT (wrong) and BR slides RIGHT (wrong).
      fsm.pointerMove(1, 10, 10, 1600);
      fsm.pointerMove(2, 990, 990, 1700);
      expect(fsm.isUnlocked, isFalse);
    });

    test('reset returns to idle', () {
      final fsm = makeFsm();
      fsm.pointerDown(1, 10, 10, 0);
      fsm.reset();
      expect(fsm.state, UnlockState.idle);
    });
  });
}
