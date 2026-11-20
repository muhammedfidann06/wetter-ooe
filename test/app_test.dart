import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:wetter_ooe/geosphere_api.dart';
import 'package:wetter_ooe/main.dart';
import 'package:wetter_ooe/models.dart';

// Beispiel-Antworten im Format der echten API.
final _metadata = {
  'stations': [
    {'id': '11060', 'name': 'LINZ-STADT', 'state': 'Oberösterreich', 'lat': 48.2964, 'lon': 14.2856, 'altitude': 262, 'is_active': true},
    {'id': '11068', 'name': 'FREISTADT', 'state': 'Oberösterreich', 'lat': 48.4947, 'lon': 14.5064, 'altitude': 539, 'is_active': true},
    {'id': '11035', 'name': 'WIEN-HOHE WARTE', 'state': 'Wien', 'lat': 48.2486, 'lon': 16.3564, 'altitude': 198, 'is_active': true},
    {'id': '11999', 'name': 'ALT', 'state': 'Oberösterreich', 'lat': 48.0, 'lon': 14.0, 'altitude': 300, 'is_active': false},
  ],
};

Map<String, dynamic> _feature(String id, double? tl, double rr) => {
      'type': 'Feature',
      'properties': {
        'station': id,
        'parameters': {
          'TL': {'data': [tl]},
          'RF': {'data': [80.0]},
          'FF': {'data': [2.5]},
          'RR': {'data': [rr]},
          'SO': {'data': [0.0]},
        },
      },
    };

final _current = {
  'timestamps': ['2026-11-20T22:30+00:00'],
  'features': [_feature('11060', 8.9, 0.0), _feature('11068', null, 0.2)],
};

void main() {
  test('Nur aktive Stationen in Oberösterreich', () {
    final stations = GeoSphereApi.parseStations(_metadata);
    expect(stations.map((s) => s.id), ['11060', '11068']);
    expect(stations.first.name, 'Linz-Stadt');
  });

  test('Messwerte werden gelesen, fehlende Werte sind null', () {
    final r = GeoSphereApi.parseCurrent(_current);
    expect(r.values['11060']!.temperature, 8.9);
    expect(r.values['11068']!.temperature, isNull);
    expect(r.values['11068']!.kind, WeatherKind.rain);
    expect(r.time, isNotNull);
  });

  test('Neuester Wert leer (null) -> der letzte vorhandene Wert wird genommen', () {
    final r = GeoSphereApi.parseCurrent({
      'timestamps': ['2026-11-20T22:30+00:00', '2026-11-20T22:40+00:00', '2026-11-20T22:50+00:00'],
      'features': [
        {
          'properties': {
            'station': '11057',
            'parameters': {
              'TL': {'data': [7.7, 7.4, null]},
              'RR': {'data': [0.0, null, null]},
            },
          },
        },
      ],
    });
    expect(r.values['11057']!.temperature, 7.4);
    expect(r.values['11057']!.rain10min, 0.0);
    expect(r.time, DateTime.parse('2026-11-20T22:40+00:00').toLocal());
  });

  test('Haversine: Linz-Stadt ist ca. 19 km von Hagenberg entfernt', () {
    final d = distanceKm(hagenbergLat, hagenbergLon, 48.2964, 14.2856);
    expect(d, inInclusiveRange(17, 21));
  });

  test('prettyName', () {
    expect(prettyName('LINZ/HOERSCHING-FLUGHAFEN'), 'Linz/Hoersching-Flughafen');
    expect(prettyName('BAD ISCHL'), 'Bad Ischl');
  });

  test('Sortieren nach Temperatur: fehlende Werte am Ende', () {
    const s = Station(id: '1', name: 'A', lat: 0, lon: 0, altitude: 0);
    final list = [
      const StationWeather(s, Measurement(temperature: null), 1),
      const StationWeather(s, Measurement(temperature: 5), 2),
      const StationWeather(s, Measurement(temperature: 9), 3),
    ];
    final sorted = sortWeather(list, SortMode.temperatureDesc);
    expect(sorted.map((w) => w.measurement.temperature), [9, 5, null]);
  });

  testWidgets('App zeigt die nächste Station zu Hagenberg', (tester) async {
    final client = MockClient((req) async {
      final body = req.url.path.endsWith('/metadata') ? _metadata : _current;
      return http.Response.bytes(utf8.encode(jsonEncode(body)), 200);
    });

    await tester.pumpWidget(MaterialApp(home: HomePage(api: GeoSphereApi(client: client))));
    await tester.pumpAndSettle();

    expect(find.text('Nächste Station zur FH Hagenberg'), findsOneWidget);
    // Freistadt ist näher an Hagenberg als Linz.
    expect(find.textContaining('Freistadt ·'), findsOneWidget);
    // Linz hat als einzige Station eine Temperatur -> wärmste UND kälteste.
    expect(find.text('Linz-Stadt'), findsWidgets);
    expect(find.text('8,9 °C'), findsWidgets);
  });
}
