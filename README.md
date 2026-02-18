# 📍 GPS Camera

> Was getting too many ads on other apps, so I decided to make my own.

A **free, open-source GPS Map Camera** app built with Flutter. Captures photos stamped with your GPS location, satellite map, address, and real-time telemetry data — no ads, no tracking, no nonsense.

## 📥 Download

<!-- Replace with your actual download link once available -->
| Platform | Download |
|---|---|
| Android | [Download APK](https://github.com/rajatsinghten/GPS_Camera/releases/latest) |
| iOS | Coming Soon |

##  Features

-  **GPS-stamped photos** — Every photo includes location, address, coordinates, and timestamp
-  **Satellite map cutout** — Mini satellite map embedded in the photo watermark
-  **Live telemetry** — Wind speed, humidity, altitude, and magnetic field data
-  **Auto-save to gallery** — Photos saved instantly with the watermark overlay
-  **Pinch-to-zoom** — Zoom slider + pinch gesture on the camera viewfinder
-  **4:3 aspect ratio** — Classic photo ratio for better composition
-  **In-app gallery** — Browse and manage your GPS photos
-  **Privacy-first** — No ads, no analytics, no data collection

## 📱 Screenshots

<!-- Add screenshots here -->
<!-- ![Camera View](screenshots/camera.png) -->
<!-- ![Saved Photo](screenshots/saved.png) -->

## 🏗️ Tech Stack

| Component | Technology |
|---|---|
| Framework | Flutter 3.x |
| Camera | `camera` plugin |
| Location | `geolocator` + `geocoding` |
| Maps | `flutter_map` (OpenStreetMap / Esri Satellite) |
| Weather | [Open-Meteo API](https://open-meteo.com/) (free, no key) |
| Magnetometer | `sensors_plus` |
| Gallery Save | `image_gallery_saver_plus` |
| State | `provider` |

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.11+ installed
- Android Studio / Xcode
- A physical device (camera doesn't work on simulators)

### Build & Run

```bash
# Clone the repo
git clone https://github.com/rajatsinghten/GPS_Camera.git
cd GPS

# Install dependencies
flutter pub get

# Run on connected device
flutter run

# Build release APK (arm64, ~18MB)
flutter build apk --release --split-per-abi

# Build iOS
flutter build ios --release
```

The release APK will be at:
```
build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

## 📁 Project Structure

```
lib/
├── main.dart                    # App entry + permission gate
├── models/
│   └── gps_photo.dart           # Photo data model
├── providers/
│   └── photo_provider.dart      # State management
├── screens/
│   ├── camera_screen.dart       # Camera + auto-save + viewfinder overlay
│   └── gallery_screen.dart      # Photo gallery + detail view
├── services/
│   ├── location_service.dart    # GPS + geocoding
│   └── telemetry_service.dart   # Weather API + magnetometer
├── utils/
│   └── theme.dart               # Dark theme + styling
└── widgets/
    ├── gps_watermark.dart       # Map + data watermark overlay
    ├── map_snippet.dart         # Interactive map widget
    └── photo_card.dart          # Gallery thumbnail card
```

## 🤝 Contributing

Contributions are welcome! Feel free to:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is open source and available under the [MIT License](LICENSE).

##  Acknowledgments

- [Open-Meteo](https://open-meteo.com/) — Free weather API
- [OpenStreetMap](https://www.openstreetmap.org/) — Map data
- [Esri](https://www.esri.com/) — Satellite imagery tiles
