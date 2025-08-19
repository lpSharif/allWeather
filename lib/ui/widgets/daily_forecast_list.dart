
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';

class DailyForecastList extends StatelessWidget {
  final List<DailyForecastEntry> items;
  const DailyForecastList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final df = DateFormat('EEE, MMM d');
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final e = items[i];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Expanded(child: Text(df.format(e.date))),
              Text('${app.displayTemp(e.minTemp).toStringAsFixed(0)}/${app.displayTemp(e.maxTemp).toStringAsFixed(0)}${app.tempUnit()}'),
            ],
          ),
        );
      },
    );
  }
}
