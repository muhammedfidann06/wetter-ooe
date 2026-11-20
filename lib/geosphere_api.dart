import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Client für die offene Daten-API von GeoSphere Austria (früher ZAMG).
/// Doku: https://dataset.api.hub.geosphere.at/v1/docs/
/// Kein API-Key nötig.
class GeoSphereApi {
  static const _base = 'https://dataset.api.hub.geosphere.at/v1/station/current/tawes-v1-10min';
  static const _history = 'https://dataset.api.hub.geosphere.at/v1/station/historical/tawes-v1-10min';
  static const parameters = ['TL', 'RF', 'FF', 'RR', 'SO'];

  final http.Client _http;
  GeoSphereApi({http.Client? client}) : _http = client ?? http.Client();

  Future<Map<String, dynamic>> _get(Uri uri) async {
    final res = await _http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('GeoSphere API Fehler ${res.statusCode}');
    }
    // utf8.decode: Damit Umlaute (ä, ö, ü) richtig sind.
    return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
  }

  /// Alle aktiven Stationen in Oberösterreich.
  Future<List<Station>> stationsOberoesterreich() async {
    final meta = await _get(Uri.parse('$_base/metadata'));
    return parseStations(meta);
  }

  static List<Station> parseStations(Map<String, dynamic> meta) {
    return (meta['stations'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .where((s) => (s['state'] as String? ?? '').toLowerCase().startsWith('ober'))
        .where((s) => s['is_active'] != false)
        .map(Station.fromJson)
        .toList();
  }

  /// Aktuelle Werte für viele Stationen in EINEM Request.
  /// Wir laden die letzte Stunde: Der neueste 10-Minuten-Wert ist oft noch leer (null).
  /// Dann nehmen wir den letzten Wert, der da ist. Wenn das nicht geht, nehmen wir "current".
  Future<({DateTime? time, Map<String, Measurement> values})> current(List<Station> stations, {DateTime? now}) async {
    final ids = stations.map((s) => s.id).join(',');
    final end = (now ?? DateTime.now()).toUtc();
    String iso(DateTime d) => d.toIso8601String().substring(0, 16);
    try {
      final uri = Uri.parse(_history).replace(queryParameters: {
        'parameters': parameters.join(','),
        'station_ids': ids,
        'start': iso(end.subtract(const Duration(hours: 1))),
        'end': iso(end),
      });
      return parseCurrent(await _get(uri));
    } catch (_) {
      final uri = Uri.parse(_base).replace(queryParameters: {'parameters': parameters.join(','), 'station_ids': ids});
      return parseCurrent(await _get(uri));
    }
  }

  static ({DateTime? time, Map<String, Measurement> values}) parseCurrent(Map<String, dynamic> json) {
    final times = (json['timestamps'] as List<dynamic>? ?? []).cast<String>();
    var newest = -1; // Index der neuesten Zeit mit einer Temperatur

    // Hilfsfunktion: den letzten Wert, der NICHT null ist.
    double? last(Map<String, dynamic> params, String key) {
      final data = (params[key] as Map<String, dynamic>?)?['data'] as List<dynamic>?;
      if (data == null) return null;
      for (var i = data.length - 1; i >= 0; i--) {
        final v = data.elementAt(i);
        if (v != null) {
          if (key == 'TL' && i > newest) newest = i;
          return (v as num).toDouble();
        }
      }
      return null;
    }

    final values = <String, Measurement>{};
    for (final f in (json['features'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      final props = f['properties'] as Map<String, dynamic>;
      final p = props['parameters'] as Map<String, dynamic>;
      values[props['station'].toString()] = Measurement(
        temperature: last(p, 'TL'),
        humidity: last(p, 'RF'),
        wind: last(p, 'FF'),
        rain10min: last(p, 'RR'),
        sunshine10min: last(p, 'SO'),
      );
    }
    final idx = newest >= 0 ? newest : times.length - 1;
    final time = idx < 0 || idx >= times.length ? null : DateTime.tryParse(times.elementAt(idx))?.toLocal();
    return (time: time, values: values);
  }
}
