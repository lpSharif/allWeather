import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import '../models/weather_models.dart';

/// Notification IDs — one per alert category so each can be updated/cancelled individually.
class _Nid {
  static const alert   = 1;
  static const rain    = 2;
  static const snow    = 3;
  static const thunder = 4;
  static const heat    = 5;
  static const cold    = 6;
  static const wind    = 7;
}

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _chId   = 'allweather_weather';
  static const _chName = 'Weather Alerts';
  static const _chDesc = 'Early warnings for rain, snow, storms, and extreme weather.';

  /// Must be called once at app startup (and in workmanager background isolate).
  static Future<void> init() async {
    if (_initialized) return;
    tzdata.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );

    // Create the high-importance Android channel
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          _chId, _chName,
          description: _chDesc,
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        ));

    _initialized = true;
  }

  /// Request OS notification permissions (call once after first app launch).
  static Future<void> requestPermissions() async {
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // ── Internal helpers ──────────────────────────────────────────────────────

  static NotificationDetails _details({bool highPriority = true}) {
    final imp = highPriority ? Importance.high : Importance.defaultImportance;
    final pri = highPriority ? Priority.high  : Priority.defaultPriority;
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _chId, _chName,
        channelDescription: _chDesc,
        importance: imp,
        priority: pri,
        icon: '@mipmap/ic_launcher',
        styleInformation: const BigTextStyleInformation(''),
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Throttle: only fire if the same notification hasn't fired in the last 30 min.
  static Future<bool> _shouldFire(int id) async {
    final sp  = await SharedPreferences.getInstance();
    final ts  = sp.getInt('notif_ts_$id');
    if (ts == null) return true;
    return DateTime.now().millisecondsSinceEpoch - ts >
        const Duration(minutes: 30).inMilliseconds;
  }

  static Future<void> _stamp(int id) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setInt('notif_ts_$id', DateTime.now().millisecondsSinceEpoch);
  }

  static Future<void> _maybeShow(
      int id, String title, String body, {bool urgent = false}) async {
    if (!_initialized) return;
    // Active alerts always break through throttle; others are throttled.
    if (urgent || await _shouldFire(id)) {
      await _plugin.show(id, title, body, _details(highPriority: urgent));
      await _stamp(id);
    }
  }

  // ── Main checker ──────────────────────────────────────────────────────────

  /// Evaluate weather data and fire the appropriate notifications.
  /// Call this after every successful weather refresh.
  static Future<void> checkAndNotify({
    required String city,
    required double tempC,
    required double windSpeedMs,
    required List<String> hourlyIcons, // 24 icon codes from hourly forecast
    required List<double> hourlyPops,  // 24 POP values [0-1]
    required List<WeatherAlert> alerts,
  }) async {
    if (!_initialized) await init();

    // ── 1. Official weather alerts (urgent, ignore throttle) ────────────
    if (alerts.isNotEmpty) {
      final a = alerts.first;
      final desc = a.description.length > 160
          ? '${a.description.substring(0, 160)}…'
          : a.description;
      await _maybeShow(
        _Nid.alert,
        '⚠️ ${a.event}',
        '$city: $desc',
        urgent: true,
      );
    } else {
      await _plugin.cancel(_Nid.alert);
    }

    // ── 2. Rain approaching in next 6 h ─────────────────────────────────
    final pops6 = hourlyPops.take(6).toList();
    final maxPop = pops6.isEmpty ? 0.0 : pops6.reduce((a, b) => a > b ? a : b);
    if (maxPop >= 0.65) {
      final firstRainH = pops6.indexWhere((p) => p >= 0.50);
      final inH = (firstRainH < 0 ? 1 : firstRainH + 1).clamp(1, 6);
      await _maybeShow(
        _Nid.rain,
        '🌧️ Rain expected in $city in ${inH}h',
        '${(maxPop * 100).round()}% chance of rainfall. Don\'t forget an umbrella!',
      );
    } else {
      await _plugin.cancel(_Nid.rain);
    }

    // ── 3. Snow approaching in next 6 h ─────────────────────────────────
    final icons6 = hourlyIcons.take(6).toList();
    final snowIdx = icons6.indexWhere((ic) => ic.startsWith('13'));
    if (snowIdx >= 0) {
      await _maybeShow(
        _Nid.snow,
        '❄️ Snow expected in $city in ${snowIdx + 1}h',
        'Snowfall is on its way. Dress warmly and drive with extra care.',
      );
    } else {
      await _plugin.cancel(_Nid.snow);
    }

    // ── 4. Thunderstorm approaching in next 6 h ──────────────────────────
    final stormIdx = icons6.indexWhere((ic) => ic.startsWith('11'));
    if (stormIdx >= 0) {
      await _maybeShow(
        _Nid.thunder,
        '⛈️ Thunderstorm approaching $city in ${stormIdx + 1}h',
        'Lightning and heavy rain expected. Seek shelter and avoid open areas.',
        urgent: true,
      );
    } else {
      await _plugin.cancel(_Nid.thunder);
    }

    // ── 5. Extreme heat ──────────────────────────────────────────────────
    if (tempC >= 37) {
      await _maybeShow(
        _Nid.heat,
        '🌡️ Extreme Heat — $city (${tempC.toStringAsFixed(0)}°C)',
        'Dangerous temperatures. Stay hydrated, stay indoors, and avoid strenuous activity.',
        urgent: true,
      );
    } else {
      await _plugin.cancel(_Nid.heat);
    }

    // ── 6. Extreme cold ──────────────────────────────────────────────────
    if (tempC <= -15) {
      await _maybeShow(
        _Nid.cold,
        '🥶 Extreme Cold — $city (${tempC.toStringAsFixed(0)}°C)',
        'Dangerous cold. Wear heavy layers and limit time outdoors.',
        urgent: true,
      );
    } else {
      await _plugin.cancel(_Nid.cold);
    }

    // ── 7. High wind warning ─────────────────────────────────────────────
    final wsKmh = windSpeedMs * 3.6;
    if (wsKmh >= 70) {
      await _maybeShow(
        _Nid.wind,
        '💨 High Wind Warning — $city (${wsKmh.toStringAsFixed(0)} km/h)',
        'Strong gusts expected. Secure loose outdoor items and take care when driving.',
      );
    } else {
      await _plugin.cancel(_Nid.wind);
    }
  }

  // ── Background task persistence ───────────────────────────────────────────

  /// Store the API key, lat, lon so the workmanager background isolate can use them.
  static Future<void> saveBackgroundParams({
    required String apiKey,
    required double lat,
    required double lon,
    required String city,
  }) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString('bg_api_key', apiKey);
    await sp.setDouble('bg_lat', lat);
    await sp.setDouble('bg_lon', lon);
    await sp.setString('bg_city', city);
  }

  /// Returns null if not yet saved.
  static Future<Map<String, dynamic>?> loadBackgroundParams() async {
    final sp     = await SharedPreferences.getInstance();
    final apiKey = sp.getString('bg_api_key');
    final lat    = sp.getDouble('bg_lat');
    final lon    = sp.getDouble('bg_lon');
    final city   = sp.getString('bg_city') ?? 'your area';
    if (apiKey == null || lat == null || lon == null) return null;
    return {'apiKey': apiKey, 'lat': lat, 'lon': lon, 'city': city};
  }
}

