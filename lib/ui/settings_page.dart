import 'package:flutter/material.dart';

import '../services/app_settings.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Worked-example location.
  static const _testLat = '11.723456514344237';
  static const _testLon = '75.63203559650596';
  static const _testElevation = '57';

  final _formKey = GlobalKey<FormState>();
  late bool _manualLocation = widget.settings.manualLocation;
  late bool _manualElevation = widget.settings.manualElevation;
  late bool _applyElevation = widget.settings.applyElevation;
  late final _lat = TextEditingController(
    text: widget.settings.latitude?.toString() ?? '',
  );
  late final _lon = TextEditingController(
    text: widget.settings.longitude?.toString() ?? '',
  );
  late final _elevation = TextEditingController(
    text: _trim(widget.settings.elevation),
  );

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _lat.dispose();
    _lon.dispose();
    _elevation.dispose();
    super.dispose();
  }

  String? Function(String?) _range(double min, double max) => (value) {
    final v = double.tryParse(value?.trim() ?? '');
    if (v == null) return 'Enter a number';
    if (v < min || v > max) return 'Must be between $min and $max';
    return null;
  };

  void _useTestLocation() => setState(() {
    _manualLocation = true;
    _lat.text = _testLat;
    _lon.text = _testLon;
    _manualElevation = true;
    _elevation.text = _testElevation;
  });

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.settings.save(
      manualLocation: _manualLocation,
      latitude: double.tryParse(_lat.text.trim()),
      longitude: double.tryParse(_lon.text.trim()),
      manualElevation: _manualElevation,
      elevation: double.tryParse(_elevation.text.trim()) ?? 0,
      applyElevation: _applyElevation,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const number = TextInputType.numberWithOptions(decimal: true, signed: true);

    Widget section(String title) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
        ),
      ),
    );

    Widget field(
      TextEditingController c,
      String label,
      String? Function(String?) validator,
    ) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextFormField(
        controller: c,
        keyboardType: number,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                section('Location'),
                SwitchListTile(
                  title: const Text('Enter location manually'),
                  subtitle: const Text(
                    'Off: use this device\'s location (asks permission)',
                  ),
                  value: _manualLocation,
                  onChanged: (v) => setState(() => _manualLocation = v),
                ),
                if (_manualLocation) ...[
                  field(_lat, 'Latitude (°, north +)', _range(-90, 90)),
                  field(_lon, 'Longitude (°, east +)', _range(-180, 180)),
                ],
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _useTestLocation,
                      icon: const Icon(Icons.science_outlined, size: 18),
                      label: const Text(
                        'Use test location (11.7235, 75.6320, 57 m)',
                      ),
                    ),
                  ),
                ),
                const Divider(),
                section('Elevation'),
                SwitchListTile(
                  title: const Text('Enter elevation manually'),
                  subtitle: const Text(
                    'Off: look it up online from the coordinates',
                  ),
                  value: _manualElevation,
                  onChanged: (v) => setState(() => _manualElevation = v),
                ),
                if (_manualElevation)
                  field(
                    _elevation,
                    'Elevation (m above sea level)',
                    _range(-500, 9000),
                  )
                else
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Open-Meteo Elevation API'),
                    subtitle: Text(
                      'Free, no API key, works on web. It uses a 90 m terrain '
                      'model, so it can be off by some metres. A surveyed or '
                      'map value is better if you have one.',
                    ),
                  ),
                SwitchListTile(
                  title: const Text('Apply elevation to Sunni times'),
                  subtitle: const Text(
                    'Sunrise earlier and Maghrib later by the horizon dip '
                    '(0.0347 × √h degrees). Karachi never uses elevation.',
                  ),
                  value: _applyElevation,
                  onChanged: (v) => setState(() => _applyElevation = v),
                ),
                const Divider(),
                section('Methods'),
                const ListTile(
                  title: Text('Sunni (Samastha calendars)'),
                  subtitle: Text(
                    'Fajr 20° · Maghrib = geometric sunset + 4 min '
                    '· Isha 18° · Asr Shafi\'i · elevation applied\n'
                    'Source: Dr. Musthafa Darimi, Suprabhaatham',
                  ),
                ),
                const ListTile(
                  title: Text('Karachi'),
                  subtitle: Text(
                    'Fajr 18° · Maghrib = sunset (0.833°) '
                    '· Isha 18° · Asr Shafi\'i · elevation ignored',
                  ),
                ),
                const ListTile(
                  title: Text('Mujahid'),
                  subtitle: Text(
                    'Fajr 18° · Maghrib = sunset (90°50′ = 0.833°) '
                    '· Isha 18° · Asr: shadow = length + noon shadow · '
                    'elevation ignored\n'
                    'Sources: T.P.M. Rafi, Shabab Weekly; Darimi\'s account. '
                    'The log also shows Rafi\'s preferred Fajr at 16.5°.',
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
