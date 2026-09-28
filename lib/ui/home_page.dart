import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../calc/prayer_calculator.dart';
import '../services/app_settings.dart';
import '../services/elevation_service.dart';
import '../services/location_service.dart';
import 'log_view.dart';
import 'prayer_table.dart';
import 'settings_page.dart';

enum _Phase { starting, askPermission, loading, error, ready }

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  _Phase _phase = _Phase.starting;
  String? _error;
  bool _canOpenSettings = false;

  double? _lat, _lon;
  String _locationSource = '';
  double? _gpsAltitude;
  double _elevation = 0;
  String _elevationSource = '';
  String? _elevationWarning;

  DateTime _date = _today();

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  AppSettings get _settings => widget.settings;

  bool get _useManualLocation =>
      _settings.manualLocation &&
      _settings.latitude != null &&
      _settings.longitude != null;

  @override
  void initState() {
    super.initState();
    _start();
  }

  /// Ask for permission first unless it is already granted or not needed.
  Future<void> _start() async {
    if (_useManualLocation || await LocationService.hasPermission()) {
      return _resolve();
    }
    if (mounted) setState(() => _phase = _Phase.askPermission);
  }

  Future<void> _resolve() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });

    if (_useManualLocation) {
      _lat = _settings.latitude;
      _lon = _settings.longitude;
      _locationSource = 'manual';
      _gpsAltitude = null;
    } else {
      try {
        final pos = await LocationService.current();
        _lat = pos.latitude;
        _lon = pos.longitude;
        _locationSource = 'GPS ±${pos.accuracy.round()} m';
        // Web usually reports 0 when altitude is unknown.
        _gpsAltitude = pos.altitude == 0 ? null : pos.altitude;
      } on LocationFailure catch (e) {
        if (!mounted) return;
        setState(() {
          _phase = _Phase.error;
          _error = e.message;
          _canOpenSettings = e.canOpenSettings;
        });
        return;
      }
    }

    _elevationWarning = null;
    if (_settings.manualElevation) {
      _elevation = _settings.elevation;
      _elevationSource = 'manual';
    } else {
      try {
        _elevation = await ElevationService.lookup(_lat!, _lon!);
        _elevationSource = ElevationService.sourceLabel;
      } catch (e) {
        _elevation = 0;
        _elevationSource = 'lookup failed, using 0 m';
        _elevationWarning =
            'Could not look up elevation ($e). You can enter it in Settings.';
      }
    }

    if (mounted) setState(() => _phase = _Phase.ready);
  }

  Future<void> _openSettings() async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SettingsPage(settings: _settings)),
    );
    if (saved == true) _start();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1950),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked != null) setState(() => _date = picked);
  }

  void _shiftDate(int days) => setState(
    () => _date = DateTime(_date.year, _date.month, _date.day + days),
  );

  CalcResult _calculate() {
    final noon = DateTime(_date.year, _date.month, _date.day, 12);
    return calculatePrayerTimes(
      CalcInput(
        date: _date,
        latitude: _lat!,
        longitude: _lon!,
        timezone: noon.timeZoneOffset.inMinutes / 60,
        elevation: _elevation,
        applyElevation: _settings.applyElevation,
        locationSource: _locationSource,
        elevationSource: _elevationSource,
        timezoneSource: 'device, ${noon.timeZoneName}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sunni Prayer Times'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: SafeArea(
        child: switch (_phase) {
          _Phase.starting ||
          _Phase.loading => const Center(child: CircularProgressIndicator()),
          _Phase.askPermission => _Message(
            icon: Icons.location_on_outlined,
            title: 'Allow location',
            text:
                'Prayer times depend on where you are. The app uses your '
                'location to calculate Sunni, Karachi and Mujahid times for your '
                'exact position.\n\nElevation is then looked up online from '
                'your coordinates (Open-Meteo, free, no API key).',
            actions: [
              FilledButton.icon(
                onPressed: _resolve,
                icon: const Icon(Icons.my_location),
                label: const Text('Allow location'),
              ),
              TextButton(
                onPressed: _openSettings,
                child: const Text('Enter location manually'),
              ),
            ],
          ),
          _Phase.error => _Message(
            icon: Icons.location_off_outlined,
            title: 'No location',
            text: _error ?? 'Something went wrong.',
            actions: [
              FilledButton(onPressed: _resolve, child: const Text('Try again')),
              if (_canOpenSettings)
                OutlinedButton(
                  onPressed: Geolocator.openAppSettings,
                  child: const Text('Open app settings'),
                ),
              TextButton(
                onPressed: _openSettings,
                child: const Text('Enter location manually'),
              ),
            ],
          ),
          _Phase.ready => _buildResult(context, _calculate()),
        },
      ),
    );
  }

  Widget _buildResult(BuildContext context, CalcResult result) {
    final input = result.input;
    final tz = input.timezone;
    final theme = Theme.of(context);
    final isToday = _date == _today();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoRow(
                      icon: Icons.place_outlined,
                      text:
                          '${input.latitude.toStringAsFixed(6)}, '
                          '${input.longitude.toStringAsFixed(6)}',
                      detail: _locationSource,
                    ),
                    _InfoRow(
                      icon: Icons.terrain_outlined,
                      text: 'Elevation ${input.elevation.toStringAsFixed(0)} m',
                      detail:
                          _settings.applyElevation
                              ? _elevationSource
                              : '$_elevationSource · not applied',
                    ),
                    _InfoRow(
                      icon: Icons.schedule,
                      text:
                          'Time zone ${tz < 0 ? '−' : '+'}'
                          '${tz.abs().toStringAsFixed(2)} h',
                      detail: input.timezoneSource,
                    ),
                    if (_gpsAltitude != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Text(
                          'Device GPS altitude ${_gpsAltitude!.round()} m '
                          '(not used: on Android it is height above the '
                          'ellipsoid, not sea level).',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (_elevationWarning != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Text(
                          _elevationWarning!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _resolve,
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Refresh'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous day',
                  onPressed: () => _shiftDate(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_formatDate(_date)),
                  ),
                ),
                if (!isToday)
                  TextButton(
                    onPressed: () => setState(() => _date = _today()),
                    child: const Text('Today'),
                  ),
                IconButton(
                  tooltip: 'Next day',
                  onPressed: () => _shiftDate(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            const SizedBox(height: 8),
            PrayerTable(rows: result.rows),
            const SizedBox(height: 16),
            LogView(result: result),
          ],
        ),
      ),
    );
  }
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _formatDate(DateTime d) =>
    '${_weekdays[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]} ${d.year}';

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.text,
    required this.detail,
  });

  final IconData icon;
  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: text, style: theme.textTheme.bodyMedium),
                  TextSpan(
                    text: '  $detail',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.text,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(text, textAlign: TextAlign.center),
              const SizedBox(height: 24),
              for (final a in actions)
                Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
            ],
          ),
        ),
      ),
    );
  }
}
