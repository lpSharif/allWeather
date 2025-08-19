
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';

class HourlyForecastStrip extends StatelessWidget {
  final List<HourlyForecastEntry> items;
  const HourlyForecastStrip({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    return SizedBox(
      height: 120,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final e = items[i];
          final time = TimeOfDay.fromDateTime(e.time);
          final hh = time.hourOfPeriod.toString().padLeft(2, '0');
          final ampm = time.period == DayPeriod.am ? 'AM' : 'PM';
          return Container(
            width: 90,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('$hh:00 $ampm', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 6),
                Text('${app.displayTemp(e.temp).toStringAsFixed(0)}${app.tempUnit()}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(e.description, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('POP ${(e.pop * 100).round()}%', style: const TextStyle(fontSize: 11)),
              ],
            ),
          );
        },
      ),
    );
  }
}
