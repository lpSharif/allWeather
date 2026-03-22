import 'package:flutter/material.dart';

class CurrentWeather {
  final String city;
  final String country;
  final double temp;
  final double feelsLike;
  final int humidity;
  final int pressure;
  final double windSpeed;
  final int windDeg;
  final int clouds;
  final int visibility;
  final DateTime sunrise;
  final DateTime sunset;
  final String description;
  final String icon;

  CurrentWeather({
    required this.city,
    required this.country,
    required this.temp,
    required this.feelsLike,
    required this.humidity,
    required this.pressure,
    required this.windSpeed,
    required this.windDeg,
    required this.clouds,
    required this.visibility,
    required this.sunrise,
    required this.sunset,
    required this.description,
    required this.icon,
  });

  factory CurrentWeather.fromJson(Map<String, dynamic> json) {
    return CurrentWeather(
      city: json['name'] ?? '',
      country: json['sys']?['country'] ?? '',
      temp: (json['main']?['temp'] ?? 0).toDouble(),
      feelsLike: (json['main']?['feels_like'] ?? 0).toDouble(),
      humidity: (json['main']?['humidity'] ?? 0).toInt(),
      pressure: (json['main']?['pressure'] ?? 0).toInt(),
      windSpeed: (json['wind']?['speed'] ?? 0).toDouble(),
      windDeg: (json['wind']?['deg'] ?? 0).toInt(),
      clouds: (json['clouds']?['all'] ?? 0).toInt(),
      visibility: (json['visibility'] ?? 0).toInt(),
      sunrise: DateTime.fromMillisecondsSinceEpoch(((json['sys']?['sunrise'] ?? 0) * 1000)),
      sunset: DateTime.fromMillisecondsSinceEpoch(((json['sys']?['sunset'] ?? 0) * 1000)),
      description: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['description'] : '',
      icon: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['icon'] : '01d',
    );
  }
}

class HourlyForecastEntry {
  final DateTime time;
  final double temp;
  final double feelsLike;
  final String description;
  final String icon;
  final double windSpeed;
  final double pop;

  HourlyForecastEntry({
    required this.time,
    required this.temp,
    required this.feelsLike,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.pop,
  });

  factory HourlyForecastEntry.fromOneCall(Map<String, dynamic> json) {
    return HourlyForecastEntry(
      time: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      temp: (json['temp'] ?? 0).toDouble(),
      feelsLike: (json['feels_like'] ?? json['temp'] ?? 0).toDouble(),
      description: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['description'] : '',
      icon: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['icon'] : '01d',
      windSpeed: (json['wind_speed'] ?? 0).toDouble(),
      pop: (json['pop'] ?? 0.0).toDouble(),
    );
  }
}

class DailyForecastEntry {
  final DateTime date;
  final double minTemp;
  final double maxTemp;
  final String icon;
  final String description;

  DailyForecastEntry({
    required this.date,
    required this.minTemp,
    required this.maxTemp,
    required this.icon,
    required this.description,
  });

  factory DailyForecastEntry.fromOneCall(Map<String, dynamic> json) {
    return DailyForecastEntry(
      date: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      minTemp: (json['temp']?['min'] ?? 0).toDouble(),
      maxTemp: (json['temp']?['max'] ?? 0).toDouble(),
      icon: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['icon'] : '01d',
      description: (json['weather'] != null && json['weather'].isNotEmpty) ? json['weather'][0]['description'] : '',
    );
  }
}

double cToF(double c) => (c * 9 / 5) + 32;

class WeatherAlert {
  final String event;
  final String senderName;
  final String description;
  final DateTime start;
  final DateTime end;

  WeatherAlert({
    required this.event,
    required this.senderName,
    required this.description,
    required this.start,
    required this.end,
  });

  factory WeatherAlert.fromJson(Map<String, dynamic> json) {
    return WeatherAlert(
      event: json['event'] ?? 'Weather Alert',
      senderName: json['sender_name'] ?? '',
      description: json['description'] ?? '',
      start: DateTime.fromMillisecondsSinceEpoch((json['start'] ?? 0) * 1000),
      end: DateTime.fromMillisecondsSinceEpoch((json['end'] ?? 0) * 1000),
    );
  }

  /// Returns a suitable icon + colour for the alert based on the event name.
  static AlertStyle styleFor(String event) {
    final e = event.toLowerCase();
    if (e.contains('tornado')) {
      return const AlertStyle(Icons.tornado, Color(0xFFB71C1C));
    }
    if (e.contains('hurricane') || e.contains('typhoon')) {
      return const AlertStyle(Icons.cyclone, Color(0xFFB71C1C));
    }
    if (e.contains('thunder') || e.contains('lightning')) {
      return const AlertStyle(Icons.thunderstorm, Color(0xFF6A1B9A));
    }
    if (e.contains('snow') || e.contains('blizzard') ||
        e.contains('ice') || e.contains('freeze') || e.contains('frost')) {
      return const AlertStyle(Icons.ac_unit, Color(0xFF0277BD));
    }
    if (e.contains('heat') || e.contains('hot')) {
      return const AlertStyle(Icons.local_fire_department, Color(0xFFE65100));
    }
    if (e.contains('flood') || e.contains('rain')) {
      return const AlertStyle(Icons.water, Color(0xFF01579B));
    }
    if (e.contains('wind') || e.contains('storm')) {
      return const AlertStyle(Icons.air, Color(0xFF4E342E));
    }
    if (e.contains('fog') || e.contains('smoke') ||
        e.contains('dust') || e.contains('haze')) {
      return const AlertStyle(Icons.cloud, Color(0xFF37474F));
    }
    return const AlertStyle(Icons.warning_amber_rounded, Color(0xFFF57F17));
  }
}

class AlertStyle {
  final IconData icon;
  final Color color;
  const AlertStyle(this.icon, this.color);
}
