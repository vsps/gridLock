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
                'Screen pinning hides Home/Recents. Unpin to return here.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ---- BPM -----------------------------------------------------------
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

          // ---- Cell size -----------------------------------------------------
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
          const SizedBox(height: 16),

          // ---- Quantisation -------------------------------------------------
          Text('Quantisation',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<Quantisation>(
            showSelectedIcon: false,
            segments: Quantisation.values
                .map((q) => ButtonSegment(value: q, label: Text(q.label)))
                .toList(),
            selected: {settings.quantisation},
            onSelectionChanged: (sel) => settings.setQuantisation(sel.first),
          ),
          const SizedBox(height: 16),

          // ---- Retrigger interval --------------------------------------------
          Text('Retrigger', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<RetriggerInterval>(
            showSelectedIcon: false,
            segments: RetriggerInterval.values
                .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                .toList(),
            selected: {settings.retrigger},
            onSelectionChanged: (sel) => settings.setRetrigger(sel.first),
          ),
          const SizedBox(height: 16),

          // ---- Arpeggiator ---------------------------------------------------
          SwitchListTile(
            title: const Text('Arpeggiator'),
            subtitle: Text('Pattern: ${settings.arpPattern.label}'),
            value: settings.arpEnabled,
            onChanged: settings.setArpEnabled,
            contentPadding: EdgeInsets.zero,
          ),
          if (settings.arpEnabled) ...[
            const SizedBox(height: 4),
            SegmentedButton<ArpPattern>(
              showSelectedIcon: false,
              segments: ArpPattern.values
                  .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                  .toList(),
              selected: {settings.arpPattern},
              onSelectionChanged: (sel) => settings.setArpPattern(sel.first),
            ),
          ],
          const SizedBox(height: 24),

          // ---- Echo ---------------------------------------------------------
          SwitchListTile(
            title: const Text('Echo'),
            subtitle: const Text('Notes grow richer the longer they are held'),
            value: settings.echoEnabled,
            onChanged: settings.setEchoEnabled,
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 24),

          // ---- Actions -------------------------------------------------------
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
