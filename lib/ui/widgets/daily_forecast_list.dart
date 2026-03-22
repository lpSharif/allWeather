import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';
import '../screens/home_screen.dart' show weatherIcon, weatherIconColor;

class DailyForecastList extends StatelessWidget {
  final List<DailyForecastEntry> items;
  const DailyForecastList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final isLight = app.appTheme == AppTheme.light;
    final textColor = isLight ? const Color(0xFF1A1A2E) : Colors.white;
    final dimColor = isLight ? const Color(0xFF8A8AA0) : Colors.white.withOpacity(0.45);
    final cardBg = isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.06);
    final cardBgToday = isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.12);
    final borderNorm = isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.10);
    final borderToday = isLight ? Colors.black.withOpacity(0.12) : Colors.white.withOpacity(0.3);
    final barTrack = isLight ? Colors.black.withOpacity(0.07) : Colors.white.withOpacity(0.12);
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = items[i];
        final dayLabel = i == 0 ? 'Today' : DateFormat('EEEE').format(e.date);
        final dateLabel = DateFormat('MMM d').format(e.date);
        final icolor = weatherIconColor(e.icon);
        final isToday = i == 0;

        // Temperature range bar
        final allMax = items.map((x) => x.maxTemp).reduce((a, b) => a > b ? a : b);
        final allMin = items.map((x) => x.minTemp).reduce((a, b) => a < b ? a : b);
        final range = (allMax - allMin).clamp(1.0, double.infinity);
        final barStart = (e.minTemp - allMin) / range;
        final barWidth = (e.maxTemp - e.minTemp) / range;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: isToday ? cardBgToday : cardBg,
            border: Border.all(color: isToday ? borderToday : borderNorm),
          ),
          child: Row(
            children: [
              // Weather icon
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: icolor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(weatherIcon(e.icon), size: 20, color: icolor),
              ),
              const SizedBox(width: 12),
              // Day + description
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayLabel,
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: textColor)),
                    Text(dateLabel,
                        style: TextStyle(
                            fontSize: 11, color: dimColor)),
                  ],
                ),
              ),
              // Temp range bar
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${app.displayTemp(e.minTemp).toStringAsFixed(0)}°',
                          style: TextStyle(
                              fontSize: 12,
                              color: dimColor),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 60,
                          height: 5,
                          child: LayoutBuilder(builder: (ctx, constraints) {
                            return Stack(children: [
                              Container(
                                decoration: BoxDecoration(
                                  color: barTrack,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              Positioned(
                                left: constraints.maxWidth * barStart,
                                width: constraints.maxWidth * barWidth,
                                top: 0,
                                bottom: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(colors: [
                                      Color(0xFF64B5F6),
                                      Color(0xFFFFB74D),
                                    ]),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              ),
                            ]);
                          }),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${app.displayTemp(e.maxTemp).toStringAsFixed(0)}°',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: icolor),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      e.description.isNotEmpty
                          ? '${e.description[0].toUpperCase()}${e.description.substring(1)}'
                          : '',
                      style: TextStyle(
                          fontSize: 11, color: dimColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
