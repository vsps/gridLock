import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../clock/clock_service.dart';
import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';
import '../widgets/hex_grid_widget.dart';
import 'settings_screen.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen({super.key});

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _PlayScreenState extends State<PlayScreen> {
  bool _ready = false;
  bool _inSettings = false;
  KioskService? _kiosk;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final kiosk = context.read<KioskService>();
    if (kiosk != _kiosk) {
      _kiosk?.removeListener(_onKioskChange);
      _kiosk = kiosk;
      _kiosk!.addListener(_onKioskChange);
    }
  }

  @override
  void dispose() {
    _kiosk?.removeListener(_onKioskChange);
    super.dispose();
  }

  // Auto-open settings whenever the system unpin fires.
  void _onKioskChange() {
    if (!mounted || !_ready || _inSettings) return;
    if (!(_kiosk?.isLocked ?? true)) {
      _enterSettings(alreadyUnpinned: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final audio = context.read<AudioService>();
    final clock = context.read<ClockService>();
    final settings = context.read<GridSettings>();

    await audio.preloadSynth();
    clock.setBpm(settings.bpm);
    clock.start();

    await _kiosk!.keepScreenOn(true);
    await _kiosk!.enableImmersiveMode();
    await _kiosk!.startLock();

    if (mounted) setState(() => _ready = true);
  }

  Future<void> _enterSettings({bool alreadyUnpinned = false}) async {
    if (_inSettings) return;
    _inSettings = true;

    final clock = context.read<ClockService>();
    clock.stop();

    if (!alreadyUnpinned) {
      await _kiosk!.stopLock();
    }
    if (!mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );

    if (!mounted) return;
    _inSettings = false;
    final settings = context.read<GridSettings>();
    clock.setBpm(settings.bpm);
    clock.start();
    await _kiosk!.startLock();
    await _kiosk!.enableImmersiveMode();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: SafeArea(
        child: _ready
            ? const HexGridWidget()
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
