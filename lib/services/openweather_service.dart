import 'dart:convert';
import 'package:http/http.dart' as http;

class OpenWeatherService {
  Future<Map<String, dynamic>> getCurrentByCoords(
      double lat, double lon) async {
    final uri = Uri.parse('https://api.openweathermap.org/data/2.5/weather')
        .replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'appid': apiKey,
      'units': 'metric',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception(
          'OpenWeather error [1m${res.statusCode}[0m: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  final String apiKey;
  OpenWeatherService(this.apiKey);

  static const _base = 'https://api.openweathermap.org/data/3.0';

  Future<Map<String, dynamic>> _get(
      String url, Map<String, String> params) async {
    final uri = Uri.parse(url).replace(queryParameters: {
      ...params,
      'appid': apiKey,
      'units': 'metric',
      'exclude': 'minutely',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('OpenWeather error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getCurrentByCity(String city) async {
    final uri = Uri.parse('https://api.openweathermap.org/data/2.5/weather')
        .replace(queryParameters: {
      'q': city,
      'appid': apiKey,
      'units': 'metric',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('OpenWeather error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOneCall(double lat, double lon) {
    return _get('$_base/onecall', {'lat': '$lat', 'lon': '$lon'});
  }

  /// Free-tier Air Pollution API — returns AQI + key pollutants.
  Future<Map<String, dynamic>> getAirPollution(double lat, double lon) async {
    final uri = Uri.parse(
            'https://api.openweathermap.org/data/2.5/air_pollution')
        .replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'appid': apiKey,
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('AQI error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }

  /// Fetch current weather for any arbitrary lat/lon (free tier).
  Future<Map<String, dynamic>> getWeatherAtPoint(
      double lat, double lon) async {
    final uri = Uri.parse('https://api.openweathermap.org/data/2.5/weather')
        .replace(queryParameters: {
      'lat': '$lat',
      'lon': '$lon',
      'appid': apiKey,
      'units': 'metric',
    });
    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Weather error ${res.statusCode}: ${res.body}');
    }
    return json.decode(res.body) as Map<String, dynamic>;
  }
}
