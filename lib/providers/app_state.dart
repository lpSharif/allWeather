import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_models.dart';
import '../services/openweather_service.dart';
import '../services/notification_service.dart';

/// Three appearance modes: follows weather palette, always dark, always light.
enum AppTheme { weather, dark, light }

class AppState extends ChangeNotifier {
  final OpenWeatherService api;
  bool isCelsius = true;
  ThemeMode themeMode = ThemeMode.dark;
  AppTheme appTheme = AppTheme.weather;

  CurrentWeather? current;
  List<HourlyForecastEntry> hourly = [];
  List<DailyForecastEntry> daily = [];

  String? activeCity;
  double? lat;
  double? lon;
  bool loading = false;
  String? error;
  List<String> favorites = [];
  int selectedIndex = 0;
  int pageIndex = 0;
  List<WeatherAlert> alerts = [];

  AppState(this.api);

  static const _kFavKey = 'fav_cities_v1';

  Future<void> _loadFavorites() async {
    try {
      final sp = await SharedPreferences.getInstance();
      favorites = sp.getStringList(_kFavKey) ?? [];
      if (favorites.isEmpty && activeCity != null) {
        favorites = [activeCity!];
      }
    } catch (_) {
      favorites = activeCity != null ? [activeCity!] : [];
    }
    notifyListeners();
  }

  Future<void> _saveFavorites() async {
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setStringList(_kFavKey, favorites);
    } catch (_) {}
  }

  Future<void> addFavorite(String city, {bool select = false}) async {
    if (!favorites.contains(city)) {
      favorites.add(city);
      await _saveFavorites();
      // if requested, select the newly added favorite page (to the right)
      if (select) {
        selectedIndex = favorites.length - 1;
        pageIndex = selectedIndex + 1;
        activeCity = favorites[selectedIndex];
        lat = null;
        lon = null;
        await refresh();
      }
      notifyListeners();
    } else if (select) {
      // already exists -> find its index and select
      selectedIndex = favorites.indexOf(city);
      pageIndex = selectedIndex + 1;
      activeCity = favorites[selectedIndex];
      lat = null;
      lon = null;
      await refresh();
      notifyListeners();
    }
  }

  Future<void> removeFavorite(String city) async {
    final idx = favorites.indexOf(city);
    if (idx == -1) return;
    favorites.removeAt(idx);
    // adjust selectedIndex
    if (favorites.isEmpty) {
      selectedIndex = 0;
      pageIndex = 0;
      activeCity = null;
      lat = null;
      lon = null;
      await refresh();
    } else {
      if (selectedIndex >= favorites.length) {
        selectedIndex = favorites.length - 1;
      } else if (idx < selectedIndex) {
        selectedIndex = selectedIndex - 1;
      }
      pageIndex = selectedIndex + 1;
      activeCity = favorites[selectedIndex];
      lat = null;
      lon = null;
      await refresh();
    }
    await _saveFavorites();
    notifyListeners();
  }

  void reorderFavorites(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    final city = favorites.removeAt(oldIndex);
    favorites.insert(newIndex, city);
    if (selectedIndex == oldIndex) {
      selectedIndex = newIndex;
    } else if (oldIndex < selectedIndex && newIndex >= selectedIndex) {
      selectedIndex--;
    } else if (oldIndex > selectedIndex && newIndex <= selectedIndex) {
      selectedIndex++;
    }
    _saveFavorites();
    notifyListeners();
  }

  /// Select a page in the PageView. page==0 => current location; page>=1 => favorites[page-1]
  Future<void> selectPage(int page) async {
    pageIndex = page;
    if (page <= 0) {
      // Always fetch device location when returning to current location page
      selectedIndex = -1; // No favorite selected
      activeCity = null;
      lat = null;
      lon = null;
      await useCurrentLocation();
    } else {
      final idx = page - 1;
      if (idx < 0 || idx >= favorites.length) return;
      selectedIndex = idx;
      activeCity = favorites[idx];
      lat = null;
      lon = null;
      await refresh();
    }
    notifyListeners();
  }

  /// Request the device location and refresh weather for current coords.
  Future<void> useCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        error = 'Location services are disabled.';
        notifyListeners();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = 'Location permission denied.';
        notifyListeners();
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lon = pos.longitude;
      activeCity = null;
      await refresh();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void toggleUnits() {
    isCelsius = !isCelsius;
    notifyListeners();
  }

  /// Cycle through Weather → Dark → Light
  void cycleTheme() async {
    switch (appTheme) {
      case AppTheme.weather: appTheme = AppTheme.dark; break;
      case AppTheme.dark:    appTheme = AppTheme.light; break;
      case AppTheme.light:   appTheme = AppTheme.weather; break;
    }
    final sp = await SharedPreferences.getInstance();
    await sp.setString('app_theme', appTheme.name);
    notifyListeners();
  }

  Future<void> _loadTheme() async {
    final sp = await SharedPreferences.getInstance();
    final name = sp.getString('app_theme') ?? 'weather';
    appTheme = AppTheme.values.firstWhere((e) => e.name == name,
        orElse: () => AppTheme.weather);
  }

  Future<void> init() async {
    await _loadTheme();
    await _ensureLocationOrFallback();
    await _loadFavorites();
    // start on current location page by default
    pageIndex = 0;
    activeCity = null;
    await refresh();
  }

  Future<void> _ensureLocationOrFallback() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        activeCity = 'Montreal';
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        activeCity = 'Montreal';
        return;
      }
      final pos = await Geolocator.getCurrentPosition();
      lat = pos.latitude;
      lon = pos.longitude;
    } catch (_) {
      activeCity = 'Montreal';
    }
  }

  /// Search for a city by name. Returns true if found and data refreshed.
  /// On failure, sets an error message and falls back to current location.
  Future<bool> searchCity(String city) async {
    try {
      // validate city via API
      final cur = await api.getCurrentByCity(city);
      // set coords from response and refresh
      activeCity = city;
      lat = cur['coord']['lat'];
      lon = cur['coord']['lon'];
      await refresh();
      return true;
    } catch (e) {
      error = 'City not found';
      notifyListeners();
      // fallback to current location
      await useCurrentLocation();
      return false;
    }
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      Map<String, dynamic> cur;
      if (lat != null && lon != null) {
        // If we have coordinates, fetch by coordinates (current location or after city search)
        cur = await api.getCurrentByCoords(lat!, lon!);
      } else if (activeCity != null) {
        // If a city is selected (favorites), fetch by city name
        cur = await api.getCurrentByCity(activeCity!);
        lat = cur['coord']['lat'];
        lon = cur['coord']['lon'];
      } else {
        // Fallback to Montreal if all else fails
        cur = await api.getCurrentByCity('Montreal');
        lat = cur['coord']['lat'];
        lon = cur['coord']['lon'];
      }
      current = CurrentWeather.fromJson(cur);

      final one = await api.getOneCall(lat!, lon!);

      final hourlyList = (one['hourly'] as List<dynamic>).take(24).toList();
      hourly =
          hourlyList.map((j) => HourlyForecastEntry.fromOneCall(j)).toList();

      final dailyList = (one['daily'] as List<dynamic>).take(7).toList();
      daily = dailyList.map((j) => DailyForecastEntry.fromOneCall(j)).toList();

      // Parse alerts (only if they are still active)
      final now = DateTime.now();
      final rawAlerts = one['alerts'] as List<dynamic>?;
      alerts = rawAlerts == null
          ? []
          : rawAlerts
              .map((j) => WeatherAlert.fromJson(j as Map<String, dynamic>))
              .where((a) => a.end.isAfter(now))
              .toList();

      // ── Fire weather notifications ──────────────────────────────────────
      // Run in background so it doesn't block the UI refresh
      NotificationService.checkAndNotify(
        city: current!.city,
        tempC: current!.temp,
        windSpeedMs: current!.windSpeed,
        hourlyIcons: hourly.map((e) => e.icon).toList(),
        hourlyPops: hourly.map((e) => e.pop).toList(),
        alerts: alerts,
      ).ignore();

      // Persist params for workmanager background task
      NotificationService.saveBackgroundParams(
        apiKey: api.apiKey,
        lat: lat!,
        lon: lon!,
        city: current!.city,
      ).ignore();

    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  double displayTemp(double c) => isCelsius ? c : (c * 9 / 5) + 32;
  String tempUnit() => isCelsius ? '°C' : '°F';
}
