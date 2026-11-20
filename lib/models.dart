import 'dart:math' as math;

// Eine Wetterstation von GeoSphere Austria (TAWES-Messnetz).
class Station {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final int altitude;

  const Station({required this.id, required this.name, required this.lat, required this.lon, required this.altitude});

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: j['id'].toString(),
        name: prettyName(j['name'] as String),
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        altitude: (j['altitude'] as num).round(),
      );
}

// Aktuelle Messwerte. Ein Wert kann fehlen (null), wenn der Sensor nichts meldet.
class Measurement {
  final double? temperature; // °C
  final double? humidity; // %
  final double? wind; // m/s
  final double? rain10min; // mm in den letzten 10 Minuten
  final double? sunshine10min; // Sekunden Sonne in den letzten 10 Minuten

  const Measurement({this.temperature, this.humidity, this.wind, this.rain10min, this.sunshine10min});

  // Wind in km/h ist für Menschen leichter zu lesen.
  double? get windKmh => wind == null ? null : wind! * 3.6;

  // Ein einfaches Symbol für die Liste.
  String get icon {
    if ((rain10min ?? 0) > 0) return '🌧️';
    if ((sunshine10min ?? 0) >= 300) return '☀️';
    if ((sunshine10min ?? 0) > 0) return '⛅';
    if ((temperature ?? 99) <= 0) return '❄️';
    return '☁️';
  }
}

class StationWeather {
  final Station station;
  final Measurement measurement;
  final double distanceKm; // Entfernung zu FH Hagenberg

  const StationWeather(this.station, this.measurement, this.distanceKm);
}

// FH OÖ Campus Hagenberg (ungefähr).
const hagenbergLat = 48.3681;
const hagenbergLon = 14.5150;

// Haversine-Formel: Entfernung auf der Erdkugel in Kilometern.
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLon = rad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * r * math.asin(math.sqrt(a));
}

// "LINZ-STADT" -> "Linz-Stadt", "ST.WOLFGANG" -> "St.Wolfgang"
String prettyName(String raw) {
  final lower = raw.toLowerCase();
  final buf = StringBuffer();
  var upperNext = true;
  for (final ch in lower.split('')) {
    buf.write(upperNext ? ch.toUpperCase() : ch);
    upperNext = ch == ' ' || ch == '-' || ch == '/' || ch == '.' || ch == '(';
  }
  return buf.toString();
}

enum SortMode { distance, name, temperatureDesc, temperatureAsc }

// Sortieren ohne die Original-Liste zu ändern. Fehlende Werte kommen ans Ende.
List<StationWeather> sortWeather(List<StationWeather> list, SortMode mode) {
  final copy = [...list];
  int byTemp(StationWeather a, StationWeather b, {required bool desc}) {
    final ta = a.measurement.temperature, tb = b.measurement.temperature;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return desc ? tb.compareTo(ta) : ta.compareTo(tb);
  }

  switch (mode) {
    case SortMode.distance:
      copy.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    case SortMode.name:
      copy.sort((a, b) => a.station.name.compareTo(b.station.name));
    case SortMode.temperatureDesc:
      copy.sort((a, b) => byTemp(a, b, desc: true));
    case SortMode.temperatureAsc:
      copy.sort((a, b) => byTemp(a, b, desc: false));
  }
  return copy;
}
