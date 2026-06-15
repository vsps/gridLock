import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../services/kiosk_service.dart';
import '../widgets/grid_view.dart';
import '../widgets/kiosk_listener.dart';
import 'settings_screen.dart';

/// The locked play surface. Boots audio + kiosk lock, shows the pad grid, and
/// hands control to the parent settings screen when the unlock gesture fires.
class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final audio = context.read<AudioService>();
    final kiosk = context.read<KioskService>();

    await audio.preload();
    await kiosk.keepScreenOn(true);
    await kiosk.enableImmersiveMode();
    await kiosk.startLock();

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _openSettings() async {
    final kiosk = context.read<KioskService>();
    await kiosk.stopLock();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

    // Returned from settings → re-lock and restore immersive play mode.
    if (!mounted) return;
    await kiosk.startLock();
    await kiosk.enableImmersiveMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: SafeArea(
        child: _ready
            ? KioskListener(
                onUnlock: _openSettings,
                child: const GridViewWidget(),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
