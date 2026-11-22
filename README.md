# 🌦️ Wetter OÖ – Live Weather for Upper Austria

[![ci](https://github.com/muhammedfidann06/wetter-ooe/actions/workflows/ci.yml/badge.svg)](https://github.com/muhammedfidann06/wetter-ooe/actions/workflows/ci.yml)
**▶ Live demo:** https://muhammedfidann06.github.io/wetter-ooe/

A Flutter app (Android · iOS · Web) that shows **live measurements from all weather stations in
Upper Austria (Oberösterreich)** using the official open data API of **GeoSphere Austria**
(the Austrian national weather service, formerly ZAMG).

> 🇩🇪 **Kurzbeschreibung:** Eine Flutter-App mit Live-Wetterdaten von allen Messstationen in Oberösterreich.
> Die Daten kommen von der offenen API von GeoSphere Austria. Die App zeigt die nächste Station zur
> FH Hagenberg, die wärmste und die kälteste Station und Details zu jeder Station. Die Web-Version wird
> bei jedem Push automatisch getestet, gebaut und auf GitHub Pages veröffentlicht.

## Features
- ~34 active **TAWES** stations in Upper Austria, loaded dynamically from the API metadata
- Temperature, humidity, wind, precipitation and sunshine (10-minute values), auto-refresh every 10 min
- **Nearest station to FH Hagenberg** (Haversine distance), warmest / coldest station
- Search, sorting (distance, name, temperature), detail sheet per station
- Material 3, light & dark mode, German UI
- All stations in **one** HTTP request (batched `station_ids`)

## Architecture
```
lib/
├── geosphere_api.dart   # HTTP client + JSON parsing (static, unit-testable)
├── models.dart          # Station, Measurement, Haversine, sorting
├── widgets.dart         # UI components
└── main.dart            # App + state (StatefulWidget, Timer refresh)
test/app_test.dart       # parsing, distance, sorting + widget test with MockClient
```

## Run
```bash
flutter create . --platforms=android,ios,web   # generates platform folders once
flutter run -d chrome
flutter test
```

## Data
Source: [GeoSphere Austria Data Hub](https://data.hub.geosphere.at/) – dataset `tawes-v1-10min`, licence CC BY 4.0.

## Skills
Flutter · Dart · REST APIs · open government data · geospatial math · testing · CI/CD · GitHub Pages

## How this was built
This project was created with the help of an AI coding assistant (Claude). I'm learning to program and use it to understand
how the code works – the tests and the CI pipeline show that it runs correctly.
*Dieses Projekt ist mit Hilfe eines KI-Assistenten entstanden; ich nutze es, um Programmieren zu lernen.*
