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
    final isLight = app.appTheme == AppTheme.light;
    final labelColor = isLight ? const Color(0xFF8A8AA0) : Colors.white.withOpacity(0.45);
    final tiles = [
      _TileData(Icons.thermostat_rounded,    'Feels like',
          '${app.displayTemp(weather.feelsLike).toStringAsFixed(0)}${app.tempUnit()}',
          const Color(0xFFEF9A9A)),
      _TileData(Icons.water_drop_rounded,    'Humidity',
          '${weather.humidity}%',
          const Color(0xFF64B5F6)),
      _TileData(Icons.speed_rounded,         'Pressure',
          '${weather.pressure} hPa',
          const Color(0xFFFFCC80)),
      _TileData(Icons.air_rounded,           'Wind',
          '${(weather.windSpeed * 3.6).toStringAsFixed(0)} km/h',
          const Color(0xFF80CBC4)),
      _TileData(Icons.cloud_rounded,         'Clouds',
          '${weather.clouds}%',
          const Color(0xFFB0BEC5)),
      _TileData(Icons.visibility_rounded,    'Visibility',
          '${(weather.visibility / 1000).toStringAsFixed(1)} km',
          const Color(0xFFCE93D8)),
      _TileData(Icons.wb_twilight_rounded,   'Sunrise',
          _fmtTime(weather.sunrise),
          const Color(0xFFFFD54F)),
      _TileData(Icons.nights_stay_rounded,   'Sunset',
          _fmtTime(weather.sunset),
          const Color(0xFFFFAB40)),
    ];

    return GridView.count(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: tiles.map((t) => _tile(t, isLight, labelColor)).toList(),
    );
  }

  Widget _tile(_TileData t, bool isLight, Color labelColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isLight
            ? t.color.withOpacity(0.08)
            : t.color.withOpacity(0.10),
        border: Border.all(color: t.color.withOpacity(isLight ? 0.18 : 0.28)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: t.color.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(t.icon, size: 16, color: t.color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(t.label,
                    style: TextStyle(
                        fontSize: 11,
                        color: labelColor,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 3),
                Text(t.value,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: t.color)),
              ],
            ),
          ),
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

class _TileData {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _TileData(this.icon, this.label, this.value, this.color);
}
