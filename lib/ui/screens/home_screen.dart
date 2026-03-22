// removed unused import
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/app_state.dart';
import '../../models/weather_models.dart';
import '../widgets/weather_details_grid.dart';
import '../widgets/hourly_forecast_strip.dart';
import '../widgets/daily_forecast_list.dart';
import '../widgets/forecast_chart.dart' show TempChart, RainChart;
import '../widgets/ai_overview_tile.dart';
import '../../services/notification_service.dart';
import 'map_screen.dart';

// ── Shared icon + colour helpers ─────────────────────────────────────────────
IconData weatherIcon(String code) {
  final c = code.replaceAll('n', 'd');
  switch (c) {
    case '01d': return Icons.wb_sunny_rounded;
    case '02d': return Icons.cloud_queue_rounded;
    case '03d': case '04d': return Icons.cloud_rounded;
    case '09d': return Icons.grain_rounded;
    case '10d': return Icons.umbrella_rounded;
    case '11d': return Icons.thunderstorm_rounded;
    case '13d': return Icons.ac_unit_rounded;
    case '50d': return Icons.blur_on_rounded;
    default:    return Icons.wb_sunny_rounded;
  }
}

Color weatherIconColor(String code) {
  final c = code.replaceAll('n', 'd');
  switch (c) {
    case '01d': return const Color(0xFFFFD54F); // golden yellow
    case '02d': return const Color(0xFFFFCC80); // soft amber
    case '03d': case '04d': return const Color(0xFFB0BEC5); // cool grey
    case '09d': return const Color(0xFF4FC3F7); // sky blue
    case '10d': return const Color(0xFF81D4FA); // light blue
    case '11d': return const Color(0xFFCE93D8); // soft purple
    case '13d': return const Color(0xFFE0F7FA); // icy white-blue
    case '50d': return const Color(0xFF90A4AE); // foggy grey-blue
    default:    return const Color(0xFFFFD54F);
  }
}

// ── Section header helper — now handled by _sectionLabel method inside the State

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  late AnimationController _controller;
  late Animation<double> _anim;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 6000));
    _anim = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.repeat(reverse: true);
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Ask for notification permissions once (OS shows dialog only on first call)
      await NotificationService.requestPermissions();
      if (mounted) context.read<AppState>().init();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _search.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final cw = app.current;
    final theme = app.appTheme;
    final isLight = theme == AppTheme.light;

    // Determine background and text colours based on theme
    final Color bgPrimary;
    final Color bgSecondary;
    final Color textPrimary;
    final Color textSecondary;
    final Color textTertiary;
    final Color cardColor;
    final Color cardBorder;
    final Color scrimColor;

    switch (theme) {
      case AppTheme.light:
        bgPrimary   = const Color(0xFFF5F7FA);
        bgSecondary = const Color(0xFFE8ECF1);
        textPrimary   = const Color(0xFF1A1A2E);
        textSecondary = const Color(0xFF4A4A68);
        textTertiary  = const Color(0xFF8A8AA0);
        cardColor  = Colors.white.withOpacity(0.85);
        cardBorder = Colors.black.withOpacity(0.08);
        scrimColor = Colors.transparent;
      case AppTheme.dark:
        bgPrimary   = const Color(0xFF0D1117);
        bgSecondary = const Color(0xFF161B22);
        textPrimary   = const Color(0xFFE6EDF3);
        textSecondary = const Color(0xFF9EAAB8);
        textTertiary  = const Color(0xFF5A6570);
        cardColor  = Colors.white.withOpacity(0.06);
        cardBorder = Colors.white.withOpacity(0.10);
        scrimColor = Colors.transparent;
      case AppTheme.weather:
        bgPrimary   = Colors.transparent; // gradient takes over
        bgSecondary = Colors.transparent;
        textPrimary   = Colors.white;
        textSecondary = Colors.white.withOpacity(0.75);
        textTertiary  = Colors.white.withOpacity(0.50);
        cardColor  = Colors.white.withOpacity(0.09);
        cardBorder = Colors.white.withOpacity(0.15);
        scrimColor = Colors.black.withOpacity(0.20);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        final desired = app.pageIndex.clamp(0, 1 + app.favorites.length - 1);
        final cur = (_pageController.page ?? _pageController.initialPage).round();
        if (cur != desired) _pageController.jumpToPage(desired);
      }
    });

    Widget background;
    if (theme == AppTheme.weather) {
      final gradientColors = _colorsFor(cw?.icon ?? '01d');
      background = AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _anim.value;
          final c1 = Color.lerp(gradientColors[0], gradientColors[1], t)!;
          final c2 = Color.lerp(gradientColors[2], gradientColors[3], 1 - t)!;
          final c3 = Color.lerp(gradientColors[4], gradientColors[5], t)!;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [c1, c2, c3],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          );
        },
      );
    } else {
      background = Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [bgPrimary, bgSecondary],
          ),
        ),
      );
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          background,
          if (scrimColor != Colors.transparent)
            Container(color: scrimColor),
          _content(context, app,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
            textTertiary: textTertiary,
            cardColor: cardColor,
            cardBorder: cardBorder,
            isLight: isLight,
          ),
        ],
      ),
    );
  }

  // ── Apple Weather-style gradient palettes ───────────────────────────────────
  // Returns 6 colours: [topA, topB, midA, midB, bottomA, bottomB]
  // The AnimationController lerps between A/B pairs for a slow-breathing feel.
  List<Color> _colorsFor(String icon) {
    switch (icon) {
      case '01d': // clear day — bright sky blue fading to lighter horizon
        return [const Color(0xFF1B8FE6), const Color(0xFF2196F3),
                const Color(0xFF4DB6F0), const Color(0xFF5BBEF2),
                const Color(0xFF87CEEB), const Color(0xFF9AD8F0)];
      case '01n': // clear night — deep navy to near-black
        return [const Color(0xFF0A1628), const Color(0xFF0F1D35),
                const Color(0xFF12243E), const Color(0xFF162B48),
                const Color(0xFF0D1A2D), const Color(0xFF0B1522)];
      case '02d': // partly cloudy day
        return [const Color(0xFF3A8FD4), const Color(0xFF4A9ADE),
                const Color(0xFF6EA8CC), const Color(0xFF7BB3D4),
                const Color(0xFF8AACBE), const Color(0xFF92B5C5)];
      case '02n': // partly cloudy night
        return [const Color(0xFF10192C), const Color(0xFF152038),
                const Color(0xFF1A2842), const Color(0xFF1F304C),
                const Color(0xFF141E32), const Color(0xFF111A2A)];
      case '03d': case '04d': // overcast day — grey-blue
        return [const Color(0xFF5A7080), const Color(0xFF647888),
                const Color(0xFF728690), const Color(0xFF7C9098),
                const Color(0xFF687A86), const Color(0xFF5E7280)];
      case '03n': case '04n': // overcast night — dark slate
        return [const Color(0xFF1A2430), const Color(0xFF1E2A38),
                const Color(0xFF242F3C), const Color(0xFF283444),
                const Color(0xFF1C2732), const Color(0xFF182230)];
      case '09d': case '09n': // drizzle
        return [const Color(0xFF2E4A5E), const Color(0xFF385468),
                const Color(0xFF3E5870), const Color(0xFF486278),
                const Color(0xFF344E62), const Color(0xFF2C4658)];
      case '10d': case '10n': // rain — moody blue-grey
        return [const Color(0xFF24384A), const Color(0xFF2C4052),
                const Color(0xFF324858), const Color(0xFF3A5060),
                const Color(0xFF283C4E), const Color(0xFF203444)];
      case '11d': case '11n': // thunderstorm — dark ominous purple-grey
        return [const Color(0xFF14101E), const Color(0xFF1A1428),
                const Color(0xFF1E1830), const Color(0xFF241C38),
                const Color(0xFF120E1A), const Color(0xFF0E0A16)];
      case '13d': case '13n': // snow — soft grey-blue-white
        return [const Color(0xFF6E8495), const Color(0xFF788E9E),
                const Color(0xFF8EA0AC), const Color(0xFF96A8B4),
                const Color(0xFF7E929E), const Color(0xFF768A98)];
      case '50d': case '50n': // fog — muted warm grey
        return [const Color(0xFF6B7178), const Color(0xFF737980),
                const Color(0xFF7D8288), const Color(0xFF858A90),
                const Color(0xFF6F7580), const Color(0xFF676D74)];
      default:
        return [const Color(0xFF1B8FE6), const Color(0xFF2196F3),
                const Color(0xFF4DB6F0), const Color(0xFF5BBEF2),
                const Color(0xFF87CEEB), const Color(0xFF9AD8F0)];
    }
  }

  Widget _content(BuildContext context, AppState app, {
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color cardColor,
    required Color cardBorder,
    required bool isLight,
  }) {
    if (app.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.cloud_off_rounded, size: 64, color: textTertiary),
            const SizedBox(height: 16),
            Text(app.error!, textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary, fontSize: 15)),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => app.refresh(),
              icon: Icon(Icons.refresh, color: textPrimary),
              label: Text('Retry', style: TextStyle(color: textPrimary)),
            ),
          ]),
        ),
      );
    }
    if (app.current == null) {
      return Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircularProgressIndicator(color: textSecondary, strokeWidth: 2),
          const SizedBox(height: 14),
          Text('Fetching weather…',
              style: TextStyle(color: textTertiary, fontSize: 14)),
        ]),
      );
    }

    final cw = app.current!;
    final icolor = isLight ? weatherIconColor(cw.icon).withOpacity(0.85) : weatherIconColor(cw.icon);
    final shadow = isLight ? <Shadow>[] : const [Shadow(color: Colors.black54, blurRadius: 6)];

    return SafeArea(
      child: DefaultTextStyle.merge(
        style: TextStyle(color: textPrimary),
        child: PageView.builder(
          controller: _pageController,
          itemCount: 1 + app.favorites.length,
          onPageChanged: (page) => app.selectPage(page),
          itemBuilder: (context, pageIdx) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
              children: [

                // ── Top bar ──────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(children: [
                      Icon(weatherIcon(cw.icon), size: 22, color: icolor),
                      const SizedBox(width: 8),
                      Text('AllWeather',
                          style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: textPrimary,
                              letterSpacing: 0.2,
                              shadows: shadow)),
                    ]),
                    Row(children: [
                      _topBtn(Icons.my_location_rounded, 'My Location', textPrimary, () async {
                        if (_pageController.hasClients) {
                          _pageController.animateToPage(0,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut);
                        }
                        await app.selectPage(0);
                      }),
                      _topBtn(Icons.thermostat_rounded, 'Toggle °C/°F', textPrimary,
                          () => app.toggleUnits()),
                      _topBtn(_themeIcon(app.appTheme), 'Change Theme', textPrimary,
                          () => app.cycleTheme()),
                      _topBtn(Icons.refresh_rounded, 'Refresh', textPrimary,
                          () => app.refresh()),
                      _topBtn(Icons.map_rounded, 'Weather Map', textPrimary, () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const MapScreen()),
                        );
                      }),
                      _topBtn(Icons.list_rounded, 'My Cities', textPrimary,
                          () => _showCitiesSheet(context, app)),
                    ]),
                  ],
                ),

                const SizedBox(height: 10),
                _pageIndicator(app, icolor),
                const SizedBox(height: 10),

                // ── Main weather card ────────────────────────────────
                _currentHeader(cw, app, icolor,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    textTertiary: textTertiary,
                    cardColor: cardColor,
                    cardBorder: cardBorder,
                    isLight: isLight,
                    shadow: shadow),

                // ── Alert banner ─────────────────────────────────────
                if (app.alerts.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _alertBanner(app.alerts),
                ],

                // ── AI Overview ──────────────────────────────────────
                const SizedBox(height: 18),
                AiOverviewTile(
                  current: cw,
                  hourly: app.hourly,
                  daily: app.daily,
                  alerts: app.alerts,
                  isCelsius: app.isCelsius,
                  accentColor: icolor,
                ),

                const SizedBox(height: 18),
                _sectionLabel(Icons.schedule_rounded, 'Next 24 Hours', icolor, textPrimary, shadow),
                const SizedBox(height: 8),
                HourlyForecastStrip(items: app.hourly),

                const SizedBox(height: 18),
                _sectionLabel(Icons.show_chart_rounded, 'Temperature', icolor, textPrimary, shadow),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: cardColor,
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: TempChart(items: app.hourly),
                ),

                const SizedBox(height: 18),
                _sectionLabel(Icons.water_drop_rounded, 'Rain Probability', const Color(0xFF4FC3F7), textPrimary, shadow),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: cardColor,
                    border: Border.all(color: cardBorder, width: 1),
                  ),
                  child: RainChart(items: app.hourly),
                ),

                // ── Mini map preview ─────────────────────────────────
                if (app.lat != null && app.lon != null) ...[
                  const SizedBox(height: 18),
                  _sectionLabel(Icons.map_rounded, 'Weather Map', icolor, textPrimary, shadow),
                  const SizedBox(height: 8),
                  _MiniMap(
                    lat: app.lat!,
                    lon: app.lon!,
                    apiKey: app.api.apiKey,
                    icolor: icolor,
                    weatherIcon: cw.icon,
                    temp: app.displayTemp(cw.temp),
                    unit: app.tempUnit(),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MapScreen()),
                    ),
                  ),
                ],

                const SizedBox(height: 18),
                _sectionLabel(Icons.grid_view_rounded, 'Details', icolor, textPrimary, shadow),
                const SizedBox(height: 8),
                WeatherDetailsGrid(weather: cw),

                const SizedBox(height: 18),
                _sectionLabel(Icons.calendar_today_rounded, 'Next 5 Days', icolor, textPrimary, shadow),
                const SizedBox(height: 8),
                DailyForecastList(items: app.daily),

                const SizedBox(height: 20),
                Center(
                  child: Text('Weather data by OpenWeatherMap',
                      style: TextStyle(fontSize: 11, color: textTertiary)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ── Theme icon helper ─────────────────────────────────────────────────────
  IconData _themeIcon(AppTheme t) {
    switch (t) {
      case AppTheme.weather: return Icons.palette_rounded;
      case AppTheme.dark:    return Icons.dark_mode_rounded;
      case AppTheme.light:   return Icons.light_mode_rounded;
    }
  }

  // ── Section header (theme-aware) ──────────────────────────────────────────
  Widget _sectionLabel(IconData icon, String label, Color iconColor, Color textColor, List<Shadow> shadow) {
    return Row(children: [
      Icon(icon, size: 17, color: iconColor.withOpacity(0.85)),
      const SizedBox(width: 7),
      Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: textColor.withOpacity(0.90),
              letterSpacing: 0.4,
              shadows: shadow)),
    ]);
  }

  // ── Small icon button in top bar ──────────────────────────────────────────
  Widget _topBtn(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 20, color: color.withOpacity(0.75)),
        ),
      ),
    );
  }

  // ── Main weather header card ──────────────────────────────────────────────
  Widget _currentHeader(CurrentWeather cw, AppState app, Color icolor, {
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    required Color cardColor,
    required Color cardBorder,
    required bool isLight,
    required List<Shadow> shadow,
  }) {
    final df = DateFormat('EEE, MMM d · HH:mm');
    final tempStr = '${app.displayTemp(cw.temp).toStringAsFixed(0)}${app.tempUnit()}';
    final feelsStr = 'Feels like ${app.displayTemp(cw.feelsLike).toStringAsFixed(0)}${app.tempUnit()}';
    final desc = cw.description.isNotEmpty
        ? '${cw.description[0].toUpperCase()}${cw.description.substring(1)}'
        : '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: cardColor,
        border: Border.all(color: cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${cw.city}, ${cw.country}',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700,
                          color: textPrimary,
                          shadows: shadow)),
                  const SizedBox(height: 2),
                  Text(df.format(DateTime.now()),
                      style: TextStyle(
                          fontSize: 12, color: textTertiary,
                          shadows: shadow)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: icolor.withOpacity(isLight ? 0.12 : 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: icolor.withOpacity(0.30), width: 1),
                ),
                child: Icon(weatherIcon(cw.icon), size: 32, color: icolor),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tempStr,
                  style: TextStyle(
                      fontSize: 56,
                      fontWeight: FontWeight.w200,
                      color: textPrimary,
                      height: 1.0,
                      shadows: shadow)),
              const SizedBox(width: 14),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(desc,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: icolor,
                            shadows: shadow)),
                    const SizedBox(height: 3),
                    Text(feelsStr,
                        style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                            shadows: shadow)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(children: [
            _statPill(Icons.water_drop_rounded, '${cw.humidity}%',
                const Color(0xFF4FC3F7), isLight),
            const SizedBox(width: 8),
            _statPill(Icons.air_rounded,
                '${(cw.windSpeed * 3.6).toStringAsFixed(0)} km/h',
                const Color(0xFF80CBC4), isLight),
            const SizedBox(width: 8),
            _statPill(Icons.cloud_rounded, '${cw.clouds}%',
                isLight ? const Color(0xFF78909C) : const Color(0xFFB0BEC5), isLight),
          ]),
        ],
      ),
    );
  }

  Widget _statPill(IconData icon, String value, Color color, bool isLight) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isLight ? 0.10 : 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(isLight ? 0.20 : 0.30), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(value,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }

  // ── Weather alert banner ──────────────────────────────────────────────────
  Widget _alertBanner(List<WeatherAlert> alerts) {
    return Column(
      children: alerts.map((alert) {
        final style = WeatherAlert.styleFor(alert.event);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: style.color.withOpacity(0.82),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: style.color.withOpacity(0.50), width: 1),
          ),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              leading: Icon(style.icon, color: Colors.white, size: 24),
              title: Text(alert.event,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
              subtitle: alert.senderName.isNotEmpty
                  ? Text('Source: ${alert.senderName}',
                      style: const TextStyle(
                          color: Colors.white60, fontSize: 11))
                  : null,
              iconColor: Colors.white,
              collapsedIconColor: Colors.white70,
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                Text(alert.description,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.5)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Page indicator ────────────────────────────────────────────────────────
  Widget _pageIndicator(AppState app, Color icolor) {
    final total = 1 + app.favorites.length;
    if (total <= 1) return const SizedBox.shrink();
    final isLight = app.appTheme == AppTheme.light;
    final inactiveColor = isLight ? Colors.black26 : Colors.white30;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == app.pageIndex;
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            child: Icon(Icons.my_location_rounded,
                size: active ? 16 : 13,
                color: active ? icolor : inactiveColor),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 18 : 7,
          height: 7,
          decoration: BoxDecoration(
            color: active ? icolor : inactiveColor,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ── Cities bottom sheet ───────────────────────────────────────────────────
  void _showCitiesSheet(BuildContext context, AppState app) {
    final sheetSearch = TextEditingController();
    bool isSearching = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setSheet) {
          Future<void> addCity(String raw) async {
            final city = raw.trim();
            if (city.isEmpty) return;
            setSheet(() => isSearching = true);
            final ok = await app.searchCity(city);
            if (!ok) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('City not found')));
              }
              setSheet(() => isSearching = false);
              return;
            }
            await app.addFavorite(city, select: true);
            sheetSearch.clear();
            setSheet(() => isSearching = false);
            final target = app.favorites.length;
            if (_pageController.hasClients) {
              _pageController.animateToPage(target,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut);
            }
            if (ctx.mounted) Navigator.pop(ctx);
          }

          return DraggableScrollableSheet(
            initialChildSize: 0.55,
            minChildSize: 0.35,
            maxChildSize: 0.92,
            expand: false,
            builder: (_, scrollController) {
              return Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0F1E2E),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(26)),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.10), width: 1),
                ),
                child: Column(children: [
                  // drag handle
                  Container(
                    margin: const EdgeInsets.only(top: 10, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
                    child: Row(children: [
                      Icon(Icons.location_city_rounded,
                          color: Colors.white60, size: 18),
                      const SizedBox(width: 8),
                      const Text('My Cities',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  // search
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Row(children: [
                      Expanded(
                        child: TextField(
                          controller: sheetSearch,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Search city…',
                            hintStyle:
                                const TextStyle(color: Colors.white38),
                            prefixIcon: const Icon(Icons.search_rounded,
                                color: Colors.white38, size: 18),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.07),
                            contentPadding:
                                const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 11),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.15)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(
                                  color: Colors.white.withOpacity(0.40)),
                            ),
                          ),
                          onSubmitted: (v) => addCity(v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      isSearching
                          ? const SizedBox(
                              width: 36, height: 36,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white54))
                          : GestureDetector(
                              onTap: () => addCity(sheetSearch.text),
                              child: Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(13),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.20)),
                                ),
                                child: const Icon(Icons.add_rounded,
                                    color: Colors.white70, size: 20),
                              ),
                            ),
                    ]),
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 1),

                  // My Location row
                  Builder(builder: (_) {
                    final isActive = app.pageIndex == 0;
                    final locName = isActive && app.current != null
                        ? app.current!.city
                        : 'My Location';
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 2),
                      leading: Icon(Icons.my_location_rounded,
                          color: isActive
                              ? const Color(0xFF4FC3F7)
                              : Colors.white38,
                          size: 20),
                      title: Text(locName,
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400)),
                      subtitle: const Text('Current location',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11)),
                      onTap: () async {
                        Navigator.pop(ctx);
                        if (_pageController.hasClients) {
                          _pageController.animateToPage(0,
                              duration:
                                  const Duration(milliseconds: 350),
                              curve: Curves.easeInOut);
                        }
                        await app.selectPage(0);
                      },
                    );
                  }),

                  if (app.favorites.isNotEmpty)
                    Divider(
                        color: Colors.white.withOpacity(0.06),
                        height: 1,
                        indent: 16,
                        endIndent: 16),

                  // Saved cities
                  Expanded(
                    child: app.favorites.isEmpty
                        ? Center(
                            child: Text('Add cities with the search bar above.',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 13)),
                          )
                        : ReorderableListView.builder(
                            scrollController: scrollController,
                            padding: const EdgeInsets.only(
                                top: 4, bottom: 16),
                            itemCount: app.favorites.length,
                            onReorder: (o, n) {
                              app.reorderFavorites(o, n);
                              setSheet(() {});
                            },
                            itemBuilder: (_, i) {
                              final city = app.favorites[i];
                              final isActive = app.pageIndex == i + 1;
                              return ListTile(
                                key: ValueKey(city),
                                contentPadding:
                                    const EdgeInsets.symmetric(
                                        horizontal: 20, vertical: 2),
                                leading: Icon(
                                  isActive
                                      ? Icons.location_on_rounded
                                      : Icons.location_on_outlined,
                                  color: isActive
                                      ? const Color(0xFF4FC3F7)
                                      : Colors.white38,
                                  size: 20,
                                ),
                                title: Text(city,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 15,
                                        fontWeight: isActive
                                            ? FontWeight.w600
                                            : FontWeight.w400)),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.drag_handle_rounded,
                                        color: Colors.white.withOpacity(0.20), size: 20),
                                    const SizedBox(width: 4),
                                    GestureDetector(
                                      onTap: () async {
                                        await app.removeFavorite(city);
                                        setSheet(() {});
                                      },
                                      child: Icon(
                                          Icons.remove_circle_outline_rounded,
                                          color: Colors.white30,
                                          size: 18),
                                    ),
                                  ],
                                ),
                                onTap: () async {
                                  Navigator.pop(ctx);
                                  final page = i + 1;
                                  if (_pageController.hasClients) {
                                    _pageController.animateToPage(page,
                                        duration: const Duration(
                                            milliseconds: 350),
                                        curve: Curves.easeInOut);
                                  }
                                  await app.selectPage(page);
                                },
                              );
                            },
                          ),
                  ),
                ]),
              );
            },
          );
        });
      },
    );
  }
}

// ── Mini map preview widget ───────────────────────────────────────────────────
class _MiniMap extends StatelessWidget {
  final double lat, lon;
  final String apiKey;
  final Color icolor;
  final String weatherIcon;
  final double temp;
  final String unit;
  final VoidCallback onTap;

  const _MiniMap({
    required this.lat,
    required this.lon,
    required this.apiKey,
    required this.icolor,
    required this.weatherIcon,
    required this.temp,
    required this.unit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final markerColor = weatherIconColor(weatherIcon);

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              // ── Map (non-interactive preview) ──────────────────────
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat, lon),
                  initialZoom: 7.5,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  // Dark CartoDB base
                  TileLayer(
                    urlTemplate:
                        'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                    retinaMode: RetinaMode.isHighDensity(context),
                    userAgentPackageName: 'com.codemorsh.allweather',
                  ),
                  // OWM precipitation overlay
                  Opacity(
                    opacity: 0.65,
                    child: TileLayer(
                      urlTemplate:
                          'https://tile.openweathermap.org/map/precipitation_new/{z}/{x}/{y}.png?appid=$apiKey',
                      userAgentPackageName: 'com.codemorsh.allweather',
                      errorTileCallback: (_, __, ___) {},
                    ),
                  ),
                  // Location pin
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat, lon),
                      width: 56,
                      height: 56,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: markerColor.withOpacity(0.18),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: markerColor.withOpacity(0.80),
                                  width: 2),
                              boxShadow: [
                                BoxShadow(
                                    color: markerColor.withOpacity(0.45),
                                    blurRadius: 10,
                                    spreadRadius: 1),
                              ],
                            ),
                            child: Icon(
                                weatherIconForCode(weatherIcon),
                                color: markerColor,
                                size: 16),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.72),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: markerColor.withOpacity(0.35)),
                            ),
                            child: Text(
                              '${temp.toStringAsFixed(0)}$unit',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]),
                ],
              ),

              // ── Dark border overlay ─────────────────────────────────
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                      color: icolor.withOpacity(0.22), width: 1),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),

              // ── "Explore" CTA pill (bottom-right) ──────────────────
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.70),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: icolor.withOpacity(0.40), width: 1),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 8)
                    ],
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.open_in_full_rounded,
                        size: 12, color: icolor),
                    const SizedBox(width: 5),
                    Text('Explore map',
                        style: TextStyle(
                            color: icolor,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),

              // ── Layer label (top-left) ──────────────────────────────
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.60),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF4FC3F7).withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.water_drop_rounded,
                        size: 10, color: Color(0xFF4FC3F7)),
                    const SizedBox(width: 4),
                    const Text('Precipitation',
                        style: TextStyle(
                            color: Color(0xFF4FC3F7),
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper exposed from home_screen — re-uses the top-level weatherIcon function
// but named differently to avoid collision with the String field on _TapWeather.
IconData weatherIconForCode(String code) => weatherIcon(code);

