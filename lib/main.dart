import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'providers/app_state.dart';
import 'services/notification_service.dart';
import 'services/openweather_service.dart';
import 'ui/screens/home_screen.dart';
import 'models/weather_models.dart';

// ── Workmanager background callback ──────────────────────────────────────────
// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await NotificationService.init();

      final params = await NotificationService.loadBackgroundParams();
      if (params == null) return true;

      final apiKey = params['apiKey'] as String;
      final lat    = params['lat']    as double;
      final lon    = params['lon']    as double;
      final city   = params['city']   as String;

      // Fetch current conditions
      final curRes = await http.get(
        Uri.parse('https://api.openweathermap.org/data/2.5/weather')
            .replace(queryParameters: {
          'lat': '$lat', 'lon': '$lon',
          'appid': apiKey, 'units': 'metric',
        }),
      );
      if (curRes.statusCode != 200) return true;
      final curData = json.decode(curRes.body) as Map<String, dynamic>;

      // Fetch hourly forecast
      final oneRes = await http.get(
        Uri.parse('https://api.openweathermap.org/data/3.0/onecall')
            .replace(queryParameters: {
          'lat': '$lat', 'lon': '$lon',
          'appid': apiKey, 'units': 'metric',
          'exclude': 'minutely,daily',
        }),
      );
      if (oneRes.statusCode != 200) return true;
      final oneData = json.decode(oneRes.body) as Map<String, dynamic>;

      final tempC   = (curData['main']?['temp']  ?? 0).toDouble();
      final windMs  = (curData['wind']?['speed'] ?? 0).toDouble();

      final hourlyList = (oneData['hourly'] as List<dynamic>? ?? []).take(12).toList();
      final icons = hourlyList.map<String>((e) {
        final w = e['weather'] as List?;
        return (w != null && w.isNotEmpty) ? (w[0]['icon'] as String? ?? '01d') : '01d';
      }).toList();
      final pops = hourlyList
          .map<double>((e) => (e['pop'] ?? 0.0).toDouble())
          .toList();

      // Parse alerts
      final now      = DateTime.now();
      final rawAlerts = oneData['alerts'] as List<dynamic>?;
      final alerts = rawAlerts == null
          ? <WeatherAlert>[]
          : rawAlerts
              .map((j) => WeatherAlert.fromJson(j as Map<String, dynamic>))
              .where((a) => a.end.isAfter(now))
              .toList();

      await NotificationService.checkAndNotify(
        city: city,
        tempC: tempC,
        windSpeedMs: windMs,
        hourlyIcons: icons,
        hourlyPops: pops,
        alerts: alerts,
      );
    } catch (_) {
      // Silently ignore background errors — don't crash the task
    }
    return true;
  });
}

// ── App entry point ───────────────────────────────────────────────────────────
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env', isOptional: true);
  final apiKey = dotenv.env['OWM_API_KEY'] ?? '';

  // Initialise local notifications
  await NotificationService.init();

  // Register workmanager periodic background task (Android only).
  // iOS uses scheduled local notifications instead.
  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
    await Workmanager().registerPeriodicTask(
      'allweather_bg_check',
      'allweather_weather_check',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );
  }

  runApp(MyApp(apiKey: apiKey));
}

class MyApp extends StatelessWidget {
  final String apiKey;
  const MyApp({super.key, required this.apiKey});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(OpenWeatherService(apiKey)),
      child: Consumer<AppState>(
        builder: (context, app, _) {
          // Map our custom AppTheme to MaterialApp's ThemeMode
          final ThemeMode materialMode;
          switch (app.appTheme) {
            case AppTheme.light:   materialMode = ThemeMode.light;
            case AppTheme.dark:    materialMode = ThemeMode.dark;
            case AppTheme.weather: materialMode = ThemeMode.dark; // weather uses dark system UI
          }
          return MaterialApp(
            title: 'Weather',
            debugShowCheckedModeBanner: false,
            themeMode: materialMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blue,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: Colors.blue,
              brightness: Brightness.dark,
            ),
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
