import 'package:flutter/material.dart';

import 'models.dart';

// Zahl mit Komma (deutsch) und Einheit. Fehlt der Wert, zeigen wir "–".
String fmt(double? v, String unit, {int digits = 1}) =>
    v == null ? '–' : '${v.toStringAsFixed(digits).replaceAll('.', ',')} $unit';

String fmtTime(DateTime? t) =>
    t == null ? '' : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} Uhr';

// Material-Icons statt Emojis: Emojis fehlen im Flutter-Web-Font.
class WeatherIcon extends StatelessWidget {
  final WeatherKind kind;
  final double size;
  const WeatherIcon(this.kind, {super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (kind) {
      WeatherKind.rain => (Icons.water_drop, Colors.lightBlue),
      WeatherKind.sunny => (Icons.wb_sunny, Colors.amber),
      WeatherKind.partlySunny => (Icons.wb_cloudy, Colors.orangeAccent),
      WeatherKind.frost => (Icons.ac_unit, Colors.cyan),
      WeatherKind.cloudy => (Icons.cloud, Colors.blueGrey),
    };
    return Icon(icon, size: size, color: color);
  }
}

// Kleine Überschrift mit Icon.
class IconLabel extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color? color;
  const IconLabel(this.icon, this.text, {super.key, this.color});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(child: Text(text, style: Theme.of(context).textTheme.labelLarge)),
        ],
      );
}

// Große Karte: die Station am nächsten zur FH Hagenberg.
class HighlightCard extends StatelessWidget {
  final StationWeather weather;
  final DateTime? time;
  const HighlightCard({super.key, required this.weather, this.time});

  @override
  Widget build(BuildContext context) {
    final m = weather.measurement;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const IconLabel(Icons.school, 'Nächste Station zur FH Hagenberg'),
            const SizedBox(height: 4),
            Text(
              '${weather.station.name} · ${weather.distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                WeatherIcon(m.kind, size: 48),
                const SizedBox(width: 16),
                Text(fmt(m.temperature, '°C'), style: Theme.of(context).textTheme.displaySmall),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                ValueChip(icon: Icons.water_drop, text: fmt(m.humidity, '%', digits: 0)),
                ValueChip(icon: Icons.air, text: fmt(m.windKmh, 'km/h', digits: 0)),
                ValueChip(icon: Icons.umbrella, text: fmt(m.rain10min, 'mm')),
              ],
            ),
            if (time != null) ...[
              const SizedBox(height: 8),
              Text('Messung: ${fmtTime(time)}', style: Theme.of(context).textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class ValueChip extends StatelessWidget {
  final IconData icon;
  final String text;
  const ValueChip({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 18), const SizedBox(width: 4), Text(text)],
      );
}

// Wärmste und kälteste Station nebeneinander.
class ExtremesRow extends StatelessWidget {
  final StationWeather warmest;
  final StationWeather coldest;
  const ExtremesRow({super.key, required this.warmest, required this.coldest});

  Widget _card(BuildContext context, IconData icon, String label, StationWeather w, Color color) => Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconLabel(icon, label, color: color),
                Text(fmt(w.measurement.temperature, '°C'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color)),
                Text(w.station.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Row(children: [
        _card(context, Icons.local_fire_department, 'Am wärmsten', warmest, Colors.deepOrange),
        _card(context, Icons.ac_unit, 'Am kältesten', coldest, Colors.blue),
      ]);
}

// Eine Zeile pro Station. Tippen öffnet die Details.
class StationTile extends StatelessWidget {
  final StationWeather weather;
  const StationTile({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final m = weather.measurement;
    final s = weather.station;
    return Card(
      child: ListTile(
        leading: WeatherIcon(m.kind),
        title: Text(s.name),
        subtitle: Text('${s.altitude} m · ${weather.distanceKm.round()} km von Hagenberg'),
        trailing: Text(fmt(m.temperature, '°C'), style: Theme.of(context).textTheme.titleMedium),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          showDragHandle: true,
          builder: (_) => StationDetails(weather: weather),
        ),
      ),
    );
  }
}

class StationDetails extends StatelessWidget {
  final StationWeather weather;
  const StationDetails({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final m = weather.measurement;
    final s = weather.station;
    final rows = <(IconData, String, String)>[
      (Icons.thermostat, 'Temperatur', fmt(m.temperature, '°C')),
      (Icons.water_drop, 'Luftfeuchte', fmt(m.humidity, '%', digits: 0)),
      (Icons.air, 'Wind', fmt(m.windKmh, 'km/h', digits: 0)),
      (Icons.umbrella, 'Niederschlag (10 min)', fmt(m.rain10min, 'mm')),
      (Icons.wb_sunny, 'Sonne (10 min)', m.sunshine10min == null ? '–' : '${(m.sunshine10min! / 60).round()} min'),
      (Icons.terrain, 'Seehöhe', '${s.altitude} m'),
      (Icons.place, 'Koordinaten', '${s.lat.toStringAsFixed(3)}, ${s.lon.toStringAsFixed(3)}'),
    ];
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              WeatherIcon(m.kind, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Text(s.name, style: Theme.of(context).textTheme.headlineSmall)),
            ]),
            const SizedBox(height: 8),
            for (final (icon, label, value) in rows)
              ListTile(dense: true, leading: Icon(icon), title: Text(label), trailing: Text(value)),
          ],
        ),
      ),
    );
  }
}

class ErrorCard extends StatelessWidget {
  final String message;
  const ErrorCard({super.key, required this.message});

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: ListTile(leading: const Icon(Icons.cloud_off), title: Text(message)),
      );
}

class SourceFooter extends StatelessWidget {
  const SourceFooter({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Datenquelle: GeoSphere Austria (CC BY 4.0) – TAWES-Messnetz, Werte der letzten 10 Minuten.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
}
