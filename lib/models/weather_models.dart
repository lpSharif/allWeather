
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
  final String description;
  final String icon;
  final double windSpeed;
  final double pop;

  HourlyForecastEntry({
    required this.time,
    required this.temp,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.pop,
  });

  factory HourlyForecastEntry.fromOneCall(Map<String, dynamic> json) {
    return HourlyForecastEntry(
      time: DateTime.fromMillisecondsSinceEpoch((json['dt'] ?? 0) * 1000),
      temp: (json['temp'] ?? 0).toDouble(),
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
