import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';

class WeatherData {
  final double? windSpeed;
  final double? humidity;

  WeatherData({this.windSpeed, this.humidity});
}

class TelemetryService {
  /// Fetch weather data from Open-Meteo (free, no API key)
  static Future<WeatherData> getWeatherData(double lat, double lng) async {
    try {
      final url = Uri.parse(
        'https://api.open-meteo.com/v1/forecast'
        '?latitude=$lat&longitude=$lng'
        '&current=relative_humidity_2m,wind_speed_10m',
      );
      final response = await http.get(url).timeout(
        const Duration(seconds: 5),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final current = data['current'];
        return WeatherData(
          windSpeed: (current['wind_speed_10m'] as num?)?.toDouble(),
          humidity: (current['relative_humidity_2m'] as num?)?.toDouble(),
        );
      }
    } catch (e) {
      debugPrint('Weather fetch error: $e');
    }
    return WeatherData();
  }

  /// Get magnetic field strength from device magnetometer
  static Future<double?> getMagneticField() async {
    try {
      final event = await magnetometerEventStream()
          .first
          .timeout(const Duration(seconds: 3));
      // Calculate total magnetic field magnitude
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      return magnitude;
    } catch (e) {
      debugPrint('Magnetometer error: $e');
      return null;
    }
  }
}
