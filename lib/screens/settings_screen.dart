import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../audio/audio_service.dart';
import '../models/grid_settings.dart';
import '../services/kiosk_service.dart';

/// Parent settings, reachable only after the unlock gesture or the 5-second
/// setup button. Toggle audio source modes, adjust grid dimensions, or exit.
/// Popping this screen returns to play mode and re-locks (handled by
/// [PlayScreen]).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final settings = context.watch<GridSettings>();
    final audio = context.read<AudioService>();
    final kiosk = context.read<KioskService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- info card ------------------------------------------------------
          Card(
            color: Colors.blue.shade100,
            child: const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'Screen pinning hides Home/Recents and blocks the '
                'notification shade. When unpinned, or when Record '
                'mode is active, the Setup button stays visible for '
                'quick access.',
                style: TextStyle(color: Colors.black87),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ---- sound source ---------------------------------------------------
          Text('Sound Source',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<SoundSource>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: SoundSource.synth, label: Text('Synth')),
              ButtonSegment(
                  value: SoundSource.samples, label: Text('Samples')),
              ButtonSegment(
                  value: SoundSource.record, label: Text('Record')),
              ButtonSegment(
                  value: SoundSource.playback, label: Text('Play')),
            ],
            selected: {settings.soundSource},
            onSelectionChanged: (sel) async {
              final src = sel.first;
              settings.setSoundSource(src);
              audio.setMode(src.name);

              if (src == SoundSource.samples) {
                await audio.loadSamples(settings.rows, settings.cols);
              }
            },
          ),
          const SizedBox(height: 20),

          // ---- grid dimensions ------------------------------------------------
          Text('Grid', style: Theme.of(context).textTheme.titleMedium),
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

          // ---- actions --------------------------------------------------------
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
