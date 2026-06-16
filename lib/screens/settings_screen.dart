import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../clock/clock_service.dart';
import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();
    final clock = context.read<ClockService>();
    final kiosk = context.read<KioskService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.blue.shade100,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Screen pinning hides Home/Recents. Use the two-finger '
                'unlock gesture to return here.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text('BPM: ${settings.bpm}',
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: settings.bpm.toDouble(),
            min: 60,
            max: 200,
            divisions: 140,
            label: '${settings.bpm}',
            onChanged: (v) {
              settings.setBpm(v.round());
              clock.setBpm(v.round());
            },
          ),
          const SizedBox(height: 8),

          Text('Cell size: ${settings.zoom}',
              style: Theme.of(context).textTheme.titleMedium),
          Slider(
            value: settings.zoom.toDouble(),
            min: 1,
            max: 9,
            divisions: 8,
            label: '${settings.zoom}',
            onChanged: (v) => settings.setZoom(v.round()),
          ),
          const SizedBox(height: 24),

          FilledButton.icon(
            icon: const Icon(Icons.lock),
            label: const Text('Re-lock (return to play)'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Exit app'),
            onPressed: () async {
              await kiosk.stopLock();
              await SystemNavigator.pop();
            },
          ),
        ],
      ),
    );
  }
}
