
import 'package:flutter/material.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';
import 'package:provider/provider.dart';

class WeatherDetailsGrid extends StatelessWidget {
  final CurrentWeather weather;
  const WeatherDetailsGrid({super.key, required this.weather});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.0,
      children: [
        _tile('Feels like', '${app.displayTemp(weather.feelsLike).toStringAsFixed(1)}${app.tempUnit()}'),
        _tile('Humidity', '${weather.humidity}%'),
        _tile('Pressure', '${weather.pressure} hPa'),
        _tile('Wind', '${weather.windSpeed.toStringAsFixed(1)} m/s'),
        _tile('Clouds', '${weather.clouds}%'),
        _tile('Visibility', '${(weather.visibility/1000).toStringAsFixed(1)} km'),
        _tile('Sunrise', _fmtTime(weather.sunrise)),
        _tile('Sunset', _fmtTime(weather.sunset)),
      ],
    );
  }

  Widget _tile(String title, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12,)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmtTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
