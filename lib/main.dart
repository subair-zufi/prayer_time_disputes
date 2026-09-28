import 'package:flutter/material.dart';

import 'services/app_settings.dart';
import 'ui/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = AppSettings();
  await settings.load();
  runApp(PrayerApp(settings: settings));
}

class PrayerApp extends StatelessWidget {
  const PrayerApp({super.key, required this.settings});

  final AppSettings settings;

  static const _seed = Color(0xFF00796B);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunni Prayer Times',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: _seed, useMaterial3: true),
      darkTheme: ThemeData(
        colorSchemeSeed: _seed,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: HomePage(settings: settings),
    );
  }
}
