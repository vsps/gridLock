import 'dart:async';

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
  bool _showSetup = false;
  int? _gesturePointer;
  Timer? _setupTimer;
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
    _setupTimer?.cancel();
    super.dispose();
  }

  void _onKioskChange() {
    if (mounted) setState(() {});
  }

  // ---- gesture: hold top-left corner, slide to right corner ----------------

  void _onPointerDown(PointerDownEvent e) {
    final w = MediaQuery.of(context).size.width;
    final h = MediaQuery.of(context).size.height;
    if (e.localPosition.dx < w * 0.25 && e.localPosition.dy < h * 0.25) {
      _gesturePointer = e.pointer;
    }
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (_gesturePointer != e.pointer) return;
    final w = MediaQuery.of(context).size.width;
    if (e.localPosition.dx > w * 0.75) {
      _gesturePointer = null;
      _revealSetup();
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    if (_gesturePointer == e.pointer) _gesturePointer = null;
  }

  void _revealSetup() {
    _setupTimer?.cancel();
    setState(() => _showSetup = true);
    _setupTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _showSetup = false);
    });
  }

  // ---- boot ------------------------------------------------------------------

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
    await settings.load();
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
    _setupTimer?.cancel();
    setState(() => _showSetup = false);

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
    final isLocked = _kiosk?.isLocked ?? true;

    return Scaffold(
      backgroundColor: const Color(0xFF101018),
      body: SafeArea(
        child: _ready
            ? Listener(
                onPointerDown: _onPointerDown,
                onPointerMove: _onPointerMove,
                onPointerUp: _onPointerUp,
                child: Stack(
                  children: [
                    const HexGridWidget(),
                    if (_showSetup || !isLocked) _buildSetupButton(),
                  ],
                ),
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
          onTap: () => _enterSettings(alreadyUnpinned: true),
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
