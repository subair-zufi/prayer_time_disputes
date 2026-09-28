import 'dart:convert';

import 'package:http/http.dart' as http;

/// Looks up ground elevation from coordinates.
///
/// Uses the Open-Meteo Elevation API: free, no API key, and it allows
/// browser requests, so it works on web too. Data is the Copernicus
/// 90 m terrain model, so it can differ from a surveyed value by some
/// metres.
class ElevationService {
  static const sourceLabel = 'Open-Meteo terrain model, 90 m grid';

  static Future<double> lookup(double latitude, double longitude) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/elevation', {
      'latitude': '$latitude',
      'longitude': '$longitude',
    });
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) {
      throw Exception('Elevation lookup failed (HTTP ${res.statusCode})');
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final values = data['elevation'] as List<dynamic>;
    return (values.first as num).toDouble();
  }
}
