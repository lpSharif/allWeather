import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state.dart';
import 'home_screen.dart' show weatherIcon, weatherIconColor;

// ── Weather overlay layers ────────────────────────────────────────────────────
enum WeatherLayer {
  precipitation('precipitation_new', 'Rain',     Icons.water_drop_rounded,   Color(0xFF4FC3F7)),
  temperature  ('temp_new',          'Temp',     Icons.thermostat_rounded,   Color(0xFFFF7043)),
  wind         ('wind_new',          'Wind',     Icons.air_rounded,          Color(0xFF80CBC4)),
  clouds       ('clouds_new',        'Clouds',   Icons.cloud_rounded,        Color(0xFFB0BEC5)),
  pressure     ('pressure_new',      'Pressure', Icons.compress_rounded,     Color(0xFFCE93D8));

  const WeatherLayer(this.id, this.label, this.icon, this.color);
  final String id;
  final String label;
  final IconData icon;
  final Color color;
}

// ── Base map tile styles (all free) ──────────────────────────────────────────
enum _BaseStyle {
  dark  ('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',  'Dark',   Icons.nights_stay_rounded),
  light ('https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png', 'Light',  Icons.wb_sunny_rounded),
  street('https://tile.openstreetmap.org/{z}/{x}/{y}.png',                 'Street', Icons.map_outlined);

  const _BaseStyle(this.url, this.label, this.icon);
  final String url;
  final String label;
  final IconData icon;
}

// ── AQI result model ──────────────────────────────────────────────────────────
class _AqiResult {
  final int    aqi;   // 1 Good … 5 Very Poor
  final double co, no2, o3, pm25, pm10, so2, nh3;

  const _AqiResult({
    required this.aqi, required this.co, required this.no2,
    required this.o3,  required this.pm25, required this.pm10,
    required this.so2, required this.nh3,
  });

  factory _AqiResult.fromJson(Map<String, dynamic> j) {
    final item       = (j['list'] as List).first as Map<String, dynamic>;
    final c          = item['components'] as Map<String, dynamic>;
    return _AqiResult(
      aqi:  (item['main']['aqi'] as int),
      co:   (c['co']   as num).toDouble(),
      no2:  (c['no2']  as num).toDouble(),
      o3:   (c['o3']   as num).toDouble(),
      pm25: (c['pm2_5'] as num).toDouble(),
      pm10: (c['pm10'] as num).toDouble(),
      so2:  (c['so2']  as num).toDouble(),
      nh3:  (c['nh3']  as num).toDouble(),
    );
  }

  String get label => const ['', 'Good', 'Fair', 'Moderate', 'Poor', 'Very Poor'][aqi.clamp(1,5)];

  Color get color => [
    const Color(0xFF4CAF50), // 1 Good
    const Color(0xFF8BC34A), // 2 Fair
    const Color(0xFFFFEB3B), // 3 Moderate
    const Color(0xFFFF9800), // 4 Poor
    const Color(0xFFF44336), // 5 Very Poor
  ][aqi.clamp(1,5) - 1];
}

// ── Tapped-point weather ──────────────────────────────────────────────────────
class _TapWeather {
  final String city, country, description, icon;
  final double temp, feelsLike, humidity, windSpeed;
  _TapWeather({required this.city, required this.country,
    required this.description, required this.icon,
    required this.temp, required this.feelsLike,
    required this.humidity, required this.windSpeed});

  factory _TapWeather.fromJson(Map<String, dynamic> j) => _TapWeather(
    city:        j['name'] as String? ?? '',
    country:     (j['sys']?['country'] as String?) ?? '',
    description: ((j['weather'] as List).first['description'] as String),
    icon:        ((j['weather'] as List).first['icon'] as String),
    temp:        (j['main']['temp'] as num).toDouble(),
    feelsLike:   (j['main']['feels_like'] as num).toDouble(),
    humidity:    (j['main']['humidity'] as num).toDouble(),
    windSpeed:   (j['wind']['speed'] as num).toDouble(),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  WeatherLayer _activeLayer = WeatherLayer.precipitation;
  _BaseStyle   _baseStyle   = _BaseStyle.dark;
  final MapController _mapController = MapController();

  _AqiResult? _aqi;
  bool        _loadingAqi = false;
  bool        _tapping    = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _fetchAqi());
  }

  // ── Fetch AQI for current location ────────────────────────────────────────
  Future<void> _fetchAqi() async {
    final app = context.read<AppState>();
    final lat = app.lat;
    final lon = app.lon;
    if (lat == null || lon == null) return;
    setState(() => _loadingAqi = true);
    try {
      final j = await app.api.getAirPollution(lat, lon);
      setState(() => _aqi = _AqiResult.fromJson(j));
    } catch (_) {}
    finally { setState(() => _loadingAqi = false); }
  }

  // ── Tap anywhere → fetch weather ──────────────────────────────────────────
  Future<void> _onMapTap(TapPosition _, LatLng point) async {
    final app = context.read<AppState>();
    setState(() => _tapping = true);
    try {
      final j = await app.api.getWeatherAtPoint(
          point.latitude, point.longitude);
      if (!mounted) return;
      _showTapSheet(_TapWeather.fromJson(j), point, app);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load weather: $e')));
      }
    } finally {
      if (mounted) setState(() => _tapping = false);
    }
  }

  // ── Bottom sheet for tapped-point weather ─────────────────────────────────
  void _showTapSheet(_TapWeather w, LatLng point, AppState app) {
    final icolor = weatherIconColor(w.icon);
    final desc   = w.description.isEmpty ? '' :
        '${w.description[0].toUpperCase()}${w.description.substring(1)}';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // drag handle
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: icolor.withOpacity(0.15), shape: BoxShape.circle,
                border: Border.all(color: icolor.withOpacity(0.40)),
              ),
              child: Icon(weatherIcon(w.icon), color: icolor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(w.city.isNotEmpty ? '${w.city}, ${w.country}' :
                  '${point.latitude.toStringAsFixed(3)}, ${point.longitude.toStringAsFixed(3)}',
                  style: const TextStyle(color: Colors.white,
                      fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(color: icolor, fontSize: 13)),
            ])),
            Text('${app.displayTemp(w.temp).toStringAsFixed(0)}${app.tempUnit()}',
                style: const TextStyle(color: Colors.white,
                    fontSize: 36, fontWeight: FontWeight.w200)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            _InfoPill(Icons.thermostat_rounded,
                'Feels ${app.displayTemp(w.feelsLike).toStringAsFixed(0)}${app.tempUnit()}',
                icolor),
            const SizedBox(width: 8),
            _InfoPill(Icons.water_drop_rounded,
                '${w.humidity.toStringAsFixed(0)}%', const Color(0xFF4FC3F7)),
            const SizedBox(width: 8),
            _InfoPill(Icons.air_rounded,
                '${(w.windSpeed * 3.6).toStringAsFixed(0)} km/h',
                const Color(0xFF80CBC4)),
          ]),
        ]),
      ),
    );
  }

  // ── AQI detail sheet ──────────────────────────────────────────────────────
  void _showAqiSheet(_AqiResult aqi) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 36),
        decoration: const BoxDecoration(
          color: Color(0xFF0F1E2E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.white24,
                  borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: aqi.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: aqi.color.withOpacity(0.45)),
              ),
              child: Text('AQI ${aqi.aqi} · ${aqi.label}',
                  style: TextStyle(color: aqi.color,
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 4),
          Align(alignment: Alignment.centerLeft,
            child: Text('Air Quality at current location',
                style: TextStyle(color: Colors.white.withOpacity(0.45),
                    fontSize: 11))),
          const SizedBox(height: 16),
          // AQI scale bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(height: 10, decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFF4CAF50), Color(0xFF8BC34A), Color(0xFFFFEB3B),
                Color(0xFFFF9800), Color(0xFFF44336),
              ]),
            )),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: ['Good','Fair','Moderate','Poor','Very Poor']
                  .map((l) => Text(l, style: TextStyle(
                      color: Colors.white.withOpacity(0.45), fontSize: 8)))
                  .toList()),
          const SizedBox(height: 16),
          // Pollutant grid
          GridView.count(
            crossAxisCount: 3, shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8, crossAxisSpacing: 8,
            childAspectRatio: 2.4,
            children: [
              _PollutantTile('PM2.5',  '${aqi.pm25.toStringAsFixed(1)} µg/m³'),
              _PollutantTile('PM10',   '${aqi.pm10.toStringAsFixed(1)} µg/m³'),
              _PollutantTile('NO₂',    '${aqi.no2.toStringAsFixed(1)} µg/m³'),
              _PollutantTile('O₃',     '${aqi.o3.toStringAsFixed(1)} µg/m³'),
              _PollutantTile('SO₂',    '${aqi.so2.toStringAsFixed(1)} µg/m³'),
              _PollutantTile('CO',     '${aqi.co.toStringAsFixed(0)} µg/m³'),
            ],
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppState>();
    final lat    = app.lat ?? 45.5;
    final lon    = app.lon ?? -73.5;
    final apiKey = app.api.apiKey;
    final cw     = app.current;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      body: Stack(children: [

        // ── Map ──────────────────────────────────────────────────────────
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: LatLng(lat, lon),
            initialZoom: 6.0,
            maxZoom: 12.0,
            minZoom: 2.0,
            onTap: _onMapTap,
          ),
          children: [
            // Base tiles (switchable)
            TileLayer(
              urlTemplate: _baseStyle.url,
              subdomains: _baseStyle == _BaseStyle.street
                  ? const [] : const ['a', 'b', 'c', 'd'],
              retinaMode: _baseStyle != _BaseStyle.street
                  ? RetinaMode.isHighDensity(context) : false,
              userAgentPackageName: 'com.codemorsh.allweather',
              maxZoom: 20,
            ),
            // OWM weather overlay
            Opacity(
              opacity: 0.92,
              child: TileLayer(
                urlTemplate:
                    'https://tile.openweathermap.org/map/${_activeLayer.id}/{z}/{x}/{y}.png?appid=$apiKey',
                userAgentPackageName: 'com.codemorsh.allweather',
                maxZoom: 12,
                errorTileCallback: (tile, error, stackTrace) {},
              ),
            ),
            // Current location marker
            if (cw != null)
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(lat, lon),
                  width: 72, height: 72,
                  child: _LocationMarker(
                    icon: cw.icon,
                    temp: app.displayTemp(cw.temp),
                    unit: app.tempUnit(),
                  ),
                ),
              ]),
          ],
        ),

        // ── Top bar ───────────────────────────────────────────────────────
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              _GlassButton(icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context)),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.12)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 10)
                    ],
                  ),
                  child: Row(children: [
                    const Icon(Icons.map_rounded,
                        color: Colors.white70, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        cw != null
                            ? '${cw.city} · ${cw.country}'
                            : 'Weather Map',
                        style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w600,
                          shadows: [Shadow(
                              color: Colors.black54, blurRadius: 4)],
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // AQI badge
                    if (_loadingAqi)
                      const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5, color: Colors.white38))
                    else if (_aqi != null)
                      GestureDetector(
                        onTap: () => _showAqiSheet(_aqi!),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _aqi!.color.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: _aqi!.color.withOpacity(0.50)),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min,
                              children: [
                            Icon(Icons.air_rounded,
                                color: _aqi!.color, size: 12),
                            const SizedBox(width: 3),
                            Text('AQI ${_aqi!.aqi}',
                                style: TextStyle(
                                    color: _aqi!.color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700)),
                          ]),
                        ),
                      ),
                    const SizedBox(width: 8),
                    Icon(_activeLayer.icon,
                        color: _activeLayer.color, size: 15),
                    const SizedBox(width: 4),
                    Text(_activeLayer.label,
                        style: TextStyle(
                            color: _activeLayer.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ]),
          ),
        ),

        // ── Tap spinner ───────────────────────────────────────────────────
        if (_tapping)
          const Center(child: SizedBox(
            width: 48, height: 48,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white70))),

        // ── Tap hint ──────────────────────────────────────────────────────
        if (!_tapping)
          Positioned(
            top: 120, left: 0, right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.45),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Tap anywhere to check weather',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
                        fontSize: 11)),
              ),
            ),
          ),

        // ── Right-side buttons: style + zoom + re-center ──────────────────
        Positioned(
          right: 14, bottom: 230,
          child: Column(children: [
            // Base map style toggle
            _StyleToggle(
              current: _baseStyle,
              onChanged: (s) => setState(() => _baseStyle = s),
            ),
            const SizedBox(height: 10),
            _GlassButton(
              icon: Icons.add_rounded,
              onTap: () {
                final z = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, z + 1);
              },
            ),
            const SizedBox(height: 8),
            _GlassButton(
              icon: Icons.remove_rounded,
              onTap: () {
                final z = _mapController.camera.zoom;
                _mapController.move(_mapController.camera.center, z - 1);
              },
            ),
            const SizedBox(height: 8),
            _GlassButton(
              icon: Icons.my_location_rounded,
              onTap: () => _mapController.move(LatLng(lat, lon), 6.0),
            ),
          ]),
        ),

        // ── Layer switcher panel ──────────────────────────────────────────
        Positioned(
          left: 0, right: 0, bottom: 0,
          child: SafeArea(
            top: false,
            child: _LayerSwitcher(
              active: _activeLayer,
              onChanged: (l) => setState(() => _activeLayer = l),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── Style toggle button ───────────────────────────────────────────────────────
class _StyleToggle extends StatelessWidget {
  final _BaseStyle current;
  final ValueChanged<_BaseStyle> onChanged;
  const _StyleToggle({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.60),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
      ),
      child: Column(
        children: _BaseStyle.values.map((s) {
          final isActive = s == current;
          return GestureDetector(
            onTap: () => onChanged(s),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.white.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Tooltip(
                message: '${s.label} map',
                child: Icon(s.icon,
                    color: isActive ? Colors.white : Colors.white38,
                    size: 18),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Location marker ───────────────────────────────────────────────────────────
class _LocationMarker extends StatelessWidget {
  final String icon;
  final double temp;
  final String unit;
  const _LocationMarker(
      {required this.icon, required this.temp, required this.unit});

  @override
  Widget build(BuildContext context) {
    final color = weatherIconColor(icon);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withOpacity(0.18), shape: BoxShape.circle,
          border: Border.all(color: color.withOpacity(0.75), width: 2),
          boxShadow: [BoxShadow(color: color.withOpacity(0.40),
              blurRadius: 14, spreadRadius: 2)],
        ),
        child: Icon(weatherIcon(icon), color: color, size: 22),
      ),
      const SizedBox(height: 3),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.72),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 6)],
        ),
        child: Text('${temp.toStringAsFixed(0)}$unit',
            style: const TextStyle(color: Colors.white,
                fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    ]);
  }
}

// ── Glass button ──────────────────────────────────────────────────────────────
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.60),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Small info pill ───────────────────────────────────────────────────────────
class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: color.withOpacity(0.30)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: color),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(
          color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ── Pollutant tile ────────────────────────────────────────────────────────────
class _PollutantTile extends StatelessWidget {
  final String name, value;
  const _PollutantTile(this.name, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.05),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(name, style: TextStyle(
          color: Colors.white.withOpacity(0.50),
          fontSize: 9, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(
          color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis),
    ]),
  );
}

// ── Legend data ───────────────────────────────────────────────────────────────
class _LegendEntry {
  final List<Color> colors;
  final List<String> ticks;
  final String unit;
  const _LegendEntry({required this.colors, required this.ticks, required this.unit});
}

const _legends = <WeatherLayer, _LegendEntry>{
  WeatherLayer.precipitation: _LegendEntry(
    colors: [Color(0x00FFFFFF), Color(0xFFADD8E6), Color(0xFF1E90FF),
             Color(0xFF00C800), Color(0xFFFFFF00), Color(0xFFFF8C00), Color(0xFFFF0000)],
    ticks: ['0', '0.1', '0.5', '1', '5', '10', '50+'], unit: 'mm/h',
  ),
  WeatherLayer.temperature: _LegendEntry(
    colors: [Color(0xFF6A0DAD), Color(0xFF0000FF), Color(0xFF00BFFF),
             Color(0xFF00C800), Color(0xFFFFFF00), Color(0xFFFF8C00),
             Color(0xFFFF0000), Color(0xFF8B0000)],
    ticks: ['−40°', '−20°', '−5°', '0°', '15°', '25°', '35°', '45°+'], unit: '°C',
  ),
  WeatherLayer.wind: _LegendEntry(
    colors: [Color(0xFFADD8E6), Color(0xFF00BFFF), Color(0xFF00C800),
             Color(0xFFFFFF00), Color(0xFFFF8C00), Color(0xFFFF0000)],
    ticks: ['0', '5', '10', '15', '20', '30+'], unit: 'm/s',
  ),
  WeatherLayer.clouds: _LegendEntry(
    colors: [Color(0x00FFFFFF), Color(0x33B0C8E0), Color(0x66778899),
             Color(0x99607D8B), Color(0xBB455A64), Color(0xFF263238)],
    ticks: ['0%', '10%', '25%', '50%', '75%', '100%'], unit: 'cloud cover',
  ),
  WeatherLayer.pressure: _LegendEntry(
    colors: [Color(0xFF0000CD), Color(0xFF1E90FF), Color(0xFF00BFFF),
             Color(0xFF00C800), Color(0xFFFFFF00), Color(0xFFFF8C00), Color(0xFFFF0000)],
    ticks: ['950', '980', '995', '1010', '1025', '1040', '1050+'], unit: 'hPa',
  ),
};

// ── Gradient legend bar ───────────────────────────────────────────────────────
class _LegendBar extends StatelessWidget {
  final _LegendEntry data;
  final Color accentColor;
  const _LegendBar({super.key, required this.data, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Label row: unit on left, ticks spaced evenly
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(data.unit.toUpperCase(),
                style: TextStyle(color: accentColor, fontSize: 9,
                    fontWeight: FontWeight.w700, letterSpacing: 0.8)),
            Text('← less     more →',
                style: TextStyle(color: Colors.white.withOpacity(0.28),
                    fontSize: 8, letterSpacing: 0.3)),
          ],
        ),
      ),
      // Gradient bar
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(height: 10,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: data.colors))),
      ),
      const SizedBox(height: 5),
      // Tick labels
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: data.ticks.map((t) => Text(t,
            style: TextStyle(color: Colors.white.withOpacity(0.55),
                fontSize: 8, fontWeight: FontWeight.w500))).toList(),
      ),
    ]);
  }
}

// ── Layer switcher panel ──────────────────────────────────────────────────────
class _LayerSwitcher extends StatelessWidget {
  final WeatherLayer active;
  final ValueChanged<WeatherLayer> onChanged;
  const _LayerSwitcher({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final legend = _legends[active]!;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1E2E).withOpacity(0.94),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 20, offset: Offset(0, -4))
        ],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('WEATHER LAYER',
              style: TextStyle(color: Colors.white.withOpacity(0.45),
                  fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: WeatherLayer.values.map((layer) {
            final isActive = layer == active;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(layer),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 9),
                  decoration: BoxDecoration(
                    color: isActive ? layer.color.withOpacity(0.18)
                        : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isActive ? layer.color.withOpacity(0.55)
                          : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(layer.icon,
                        color: isActive ? layer.color : Colors.white38,
                        size: 22),
                    const SizedBox(height: 5),
                    Text(layer.label,
                        style: TextStyle(
                            color: isActive ? layer.color : Colors.white38,
                            fontSize: 10,
                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 2),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _LegendBar(
                key: ValueKey(active), data: legend, accentColor: active.color),
          ),
        ),
        const SizedBox(height: 8),
        Text('Map © CartoDB / OSM  ·  Weather tiles © OpenWeatherMap',
            style: TextStyle(
                color: Colors.white.withOpacity(0.22), fontSize: 9)),
      ]),
    );
  }
}
