import 'dart:async';

import 'package:flutter/material.dart';

import 'geosphere_api.dart';
import 'models.dart';
import 'widgets.dart';

void main() => runApp(const WetterApp());

class WetterApp extends StatelessWidget {
  const WetterApp({super.key});

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF0B6E4F); // Grün wie die Landschaft im Mühlviertel
    return MaterialApp(
      title: 'Wetter OÖ',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed, useMaterial3: true),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark, useMaterial3: true),
      home: HomePage(api: GeoSphereApi()),
    );
  }
}

class HomePage extends StatefulWidget {
  final GeoSphereApi api;
  const HomePage({super.key, required this.api});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Station> _stations = [];
  List<StationWeather> _weather = [];
  DateTime? _time;
  bool _loading = true;
  String? _error;
  String _query = '';
  SortMode _sort = SortMode.distance;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    // Die Daten kommen alle 10 Minuten neu. Wir laden automatisch nach.
    _timer = Timer.periodic(const Duration(minutes: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      // Die Stationsliste laden wir nur einmal.
      if (_stations.isEmpty) _stations = await widget.api.stationsOberoesterreich();
      final result = await widget.api.current(_stations);
      setState(() {
        _time = result.time;
        _weather = [
          for (final s in _stations)
            StationWeather(
              s,
              result.values[s.id] ?? const Measurement(),
              distanceKm(hagenbergLat, hagenbergLon, s.lat, s.lon),
            ),
        ];
      });
    } catch (e) {
      setState(() => _error = 'Daten konnten nicht geladen werden. ($e)');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = sortWeather(
      _weather.where((w) => w.station.name.toLowerCase().contains(_query.toLowerCase())).toList(),
      _sort,
    );
    final nearest = _weather.isEmpty ? null : sortWeather(_weather, SortMode.distance).first;
    final withTemp = _weather.where((w) => w.measurement.temperature != null).toList();
    final warmest = withTemp.isEmpty ? null : sortWeather(withTemp, SortMode.temperatureDesc).first;
    final coldest = withTemp.isEmpty ? null : sortWeather(withTemp, SortMode.temperatureAsc).first;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wetter Oberösterreich'),
        actions: [
          PopupMenuButton<SortMode>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sortieren',
            initialValue: _sort,
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (_) => const [
              PopupMenuItem(value: SortMode.distance, child: Text('Entfernung zu Hagenberg')),
              PopupMenuItem(value: SortMode.name, child: Text('Name (A–Z)')),
              PopupMenuItem(value: SortMode.temperatureDesc, child: Text('Wärmste zuerst')),
              PopupMenuItem(value: SortMode.temperatureAsc, child: Text('Kälteste zuerst')),
            ],
          ),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: 'Aktualisieren'),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (_error != null) ErrorCard(message: _error!),
                  if (nearest != null) HighlightCard(weather: nearest, time: _time),
                  if (warmest != null && coldest != null) ExtremesRow(warmest: warmest, coldest: coldest),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Station suchen, z.B. Linz',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                  for (final w in filtered) StationTile(weather: w),
                  const SourceFooter(),
                ],
              ),
            ),
    );
  }
}
