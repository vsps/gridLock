import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../clock/clock_service.dart';
import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';
import '../widgets/hex_grid_widget.dart';
import '../widgets/kiosk_listener.dart';
import 'settings_screen.dart';

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
    final clock = context.read<ClockService>();
    final settings = context.read<GridSettings>();

    // Compute initial grid dimensions from screen size and zoom.
    final size = MediaQuery.of(context).size;
    final hexR = settings.hexRadius;
    final cellW = hexR * 2;
    final rowH = hexR * 1.732; // sqrt(3)
    var cols = (size.width / cellW).ceil() + 2;
    var rows = (size.height / rowH).ceil() + 2;
    if (cols.isEven) cols++;
    if (rows.isEven) rows++;

    await audio.preloadSynth(
      rows: rows,
      cols: cols,
      centerRow: rows ~/ 2,
      centerCol: cols ~/ 2,
    );

    clock.setBpm(settings.bpm);
    clock.start();

    await kiosk.keepScreenOn(true);
    await kiosk.enableImmersiveMode();
    await kiosk.startLock();

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _openSettings() async {
    final kiosk = context.read<KioskService>();
    final clock = context.read<ClockService>();
    clock.stop();
    await kiosk.stopLock();
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

    if (!mounted) return;
    final settings = context.read<GridSettings>();
    clock.setBpm(settings.bpm);
    clock.start();
    await kiosk.startLock();
    await kiosk.enableImmersiveMode();
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = context.select<KioskService, bool>((k) => k.isLocked);

    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: SafeArea(
        child: _ready
            ? Stack(
                children: [
                  KioskListener(
                    onUnlock: _openSettings,
                    child: const HexGridWidget(),
                  ),
                  if (!isLocked) _buildSetupButton(),
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
