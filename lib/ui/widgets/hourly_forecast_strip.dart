import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';
import '../screens/home_screen.dart' show weatherIcon, weatherIconColor;

class HourlyForecastStrip extends StatelessWidget {
  final List<HourlyForecastEntry> items;
  const HourlyForecastStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isLight = app.appTheme == AppTheme.light;
    final textColor = isLight ? const Color(0xFF1A1A2E) : Colors.white;
    final subColor = isLight ? const Color(0xFF4A4A68) : Colors.white60;
    final dimColor = isLight ? const Color(0xFF8A8AA0) : Colors.white38;
    final cardBg = isLight ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.07);
    final cardBgNow = isLight ? Colors.black.withOpacity(0.08) : Colors.white.withOpacity(0.18);
    final borderNow = isLight ? Colors.black.withOpacity(0.15) : Colors.white.withOpacity(0.45);
    final borderNorm = isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.12);
    return SizedBox(
      height: 130,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final e = items[i];
          final isNow = i == 0;
          final hour = e.time.hour;
          final ampm = hour < 12 ? 'AM' : 'PM';
          final h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
          final timeLabel = isNow ? 'Now' : '$h $ampm';
          final icolor = weatherIconColor(e.icon);

          return Container(
            width: 76,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: isNow ? cardBgNow : cardBg,
              border: Border.all(color: isNow ? borderNow : borderNorm),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(timeLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: isNow ? FontWeight.w700 : FontWeight.w400,
                        color: isNow ? textColor : subColor)),
                Icon(weatherIcon(e.icon), size: 24, color: icolor),
                Text('${app.displayTemp(e.temp).toStringAsFixed(0)}${app.tempUnit()}',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600,
                        color: textColor)),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.water_drop_rounded, size: 10,
                      color: e.pop > 0.3
                          ? const Color(0xFF64B5F6)
                          : dimColor),
                  const SizedBox(width: 2),
                  Text('${(e.pop * 100).round()}%',
                      style: TextStyle(
                          fontSize: 10,
                          color: e.pop > 0.3
                              ? const Color(0xFF64B5F6)
                              : dimColor)),
                ]),
              ],
            ),
          );
        },
      ),
    );
  }
}
