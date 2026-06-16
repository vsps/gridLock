import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'audio/audio_service.dart';
import 'clock/clock_service.dart';
import 'grid/grid_state.dart';
import 'models/grid_settings.dart';
import 'screens/play_screen.dart';
import 'services/kiosk_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const GridLockApp());
}

class GridLockApp extends StatelessWidget {
  const GridLockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GridSettings()),
        ChangeNotifierProvider(create: (_) => GridState()),
        ChangeNotifierProvider(create: (_) => KioskService()),
        ChangeNotifierProvider(create: (_) => ClockService()),
        Provider(
          create: (_) => AudioService(),
          dispose: (_, service) => service.dispose(),
        ),
      ],
      child: MaterialApp(
        title: 'gridLock',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: const PlayScreen(),
      ),
    );
  }
}
