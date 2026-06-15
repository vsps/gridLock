import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';
import '../widgets/grid_view.dart';
import '../widgets/kiosk_listener.dart';
import 'settings_screen.dart';

/// The locked play surface. Boots audio + kiosk lock, shows the pad grid.
///
/// A setup button is always visible when screen pinning is exited OR when
/// the current mode is [SoundSource.record], giving persistent access to
/// settings in those states.
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

  // ---- boot ------------------------------------------------------------------

  Future<void> _boot() async {
    final audio = context.read<AudioService>();
    final kiosk = context.read<KioskService>();
    final settings = context.read<GridSettings>();

    await audio.preloadSynth();
    audio.setMode(_modeString(settings.soundSource));
    await kiosk.keepScreenOn(true);
    await kiosk.enableImmersiveMode();
    await kiosk.startLock();

    if (mounted) setState(() => _ready = true);
  }

  // ---- navigation ------------------------------------------------------------

  Future<void> _openSettings() async {
    final kiosk = context.read<KioskService>();
    await kiosk.stopLock();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

    if (!mounted) return;
    final audio = context.read<AudioService>();
    final settings = context.read<GridSettings>();
    audio.setMode(_modeString(settings.soundSource));

    await kiosk.startLock();
    await kiosk.enableImmersiveMode();
  }

  // ---- helpers ---------------------------------------------------------------

  static String _modeString(SoundSource s) => s.name;

  // ---- build -----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isLocked =
        context.select<KioskService, bool>((k) => k.isLocked);
    final mode =
        context.select<GridSettings, SoundSource>((s) => s.soundSource);
    final showSetup = !isLocked || mode == SoundSource.record;

    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: SafeArea(
        child: _ready
            ? Stack(
                children: [
                  KioskListener(
                    onUnlock: _openSettings,
                    child: const GridViewWidget(),
                  ),
                  if (showSetup) _buildSetupButton(),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildSetupButton() {
    return Positioned(
      top: 12,
      right: 12,
      child: Material(
        color: Colors.white.withAlpha(230),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _openSettings,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.settings, color: Colors.black87, size: 20),
                SizedBox(width: 6),
                Text(
                  'Setup',
                  style: TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
