import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';

/// Parent settings, reachable only after the unlock gesture. Popping this
/// screen returns to play mode and re-locks (handled by [PlayScreen]).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool? _deviceOwner;

  @override
  void initState() {
    super.initState();
    context.read<KioskService>().isDeviceOwner().then((value) {
      if (mounted) setState(() => _deviceOwner = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_deviceOwner == false)
            Card(
              color: Colors.orange.shade100,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Not provisioned as Device Owner — the kiosk lock is '
                  'escapable (hold Back + Recents). See the README for the '
                  'one-time ADB setup to make it unescapable.',
                  style: TextStyle(color: Colors.black87),
                ),
              ),
            ),
          const SizedBox(height: 8),
          _DimensionSlider(
            label: 'Rows',
            value: settings.rows,
            onChanged: settings.setRows,
          ),
          _DimensionSlider(
            label: 'Columns',
            value: settings.cols,
            onChanged: settings.setCols,
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
              await context.read<KioskService>().stopLock();
              await SystemNavigator.pop();
            },
          ),
        ],
      ),
    );
  }
}

class _DimensionSlider extends StatelessWidget {
  const _DimensionSlider({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$label: $value'),
        Slider(
          value: value.toDouble(),
          min: GridSettings.minDim.toDouble(),
          max: GridSettings.maxDim.toDouble(),
          divisions: GridSettings.maxDim - GridSettings.minDim,
          label: '$value',
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
