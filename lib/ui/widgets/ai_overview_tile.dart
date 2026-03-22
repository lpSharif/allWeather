import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';

// ── AI Overview Tile ──────────────────────────────────────────────────────────
// Generates a smart, contextual natural-language weather briefing from the
// existing weather data — no external AI API required.

class AiOverviewTile extends StatefulWidget {
  final CurrentWeather current;
  final List<HourlyForecastEntry> hourly;
  final List<DailyForecastEntry> daily;
  final List<WeatherAlert> alerts;
  final bool isCelsius;
  final Color accentColor;

  const AiOverviewTile({
    super.key,
    required this.current,
    required this.hourly,
    required this.daily,
    required this.alerts,
    required this.isCelsius,
    required this.accentColor,
  });

  @override
  State<AiOverviewTile> createState() => _AiOverviewTileState();
}

class _AiOverviewTileState extends State<AiOverviewTile>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  // ── Summary generation ────────────────────────────────────────────────────
  _AiSummary _buildSummary() {
    final cw       = widget.current;
    final hourly   = widget.hourly;
    final daily    = widget.daily;
    final alerts   = widget.alerts;
    final celsius  = widget.isCelsius;
    final now      = DateTime.now();
    final hour     = now.hour;

    double disp(double c) => celsius ? c : (c * 9 / 5) + 32;
    String unit()         => celsius ? '°C' : '°F';

    // ── Time greeting ──────────────────────────────────────────────────────
    final greeting = hour < 5   ? 'Good night'
        : hour < 12 ? 'Good morning'
        : hour < 17 ? 'Good afternoon'
        :              'Good evening';

    final temp      = disp(cw.temp);
    final feels     = disp(cw.feelsLike);
    final desc      = cw.description.isNotEmpty
        ? '${cw.description[0].toUpperCase()}${cw.description.substring(1)}'
        : 'Clear';
    final diffFeel  = (feels - temp).abs();

    // ── Opening sentence ──────────────────────────────────────────────────
    String opening = '$greeting! It\'s $desc in ${cw.city} right now — '
        '${temp.toStringAsFixed(0)}${unit()}.';

    if (diffFeel >= 4) {
      final colder = feels < temp;
      opening += ' With ${colder ? 'the wind' : 'humidity'} it feels '
          '${colder ? 'colder' : 'warmer'} at ${feels.toStringAsFixed(0)}${unit()}.';
    }

    // ── Rain outlook (next 6 h) ────────────────────────────────────────────
    String rainNote = '';
    if (hourly.isNotEmpty) {
      final next6 = hourly.take(6).toList();
      final maxPop = next6.map((e) => e.pop).reduce((a, b) => a > b ? a : b);
      final rainHour = next6.indexWhere((e) => e.pop >= 0.40);
      if (maxPop >= 0.80) {
        rainNote = 'Expect rain soon — keep an umbrella handy.';
      } else if (maxPop >= 0.40) {
        final inH = rainHour >= 0 ? ' in about ${rainHour + 1}h' : '';
        rainNote = 'There\'s a chance of showers$inH — light rain gear is wise.';
      }
    }

    // ── Wind advisory ─────────────────────────────────────────────────────
    String windNote = '';
    final wsKmh = cw.windSpeed * 3.6;
    if (wsKmh >= 60) {
      windNote = 'Strong winds at ${wsKmh.toStringAsFixed(0)} km/h — hold onto your hat!';
    } else if (wsKmh >= 30) {
      windNote = 'A gusty breeze of ${wsKmh.toStringAsFixed(0)} km/h — jackets may flap.';
    }

    // ── Temperature feel tip ──────────────────────────────────────────────
    String dressTip = '';
    final tc = cw.temp; // always Celsius for thresholds
    if (tc <= 0) {
      dressTip = 'Bundle up — it\'s freezing. Wear a heavy coat, hat, and gloves.';
    } else if (tc <= 8) {
      dressTip = 'It\'s quite cold. A warm jacket and layers are recommended.';
    } else if (tc <= 15) {
      dressTip = 'A light jacket or sweater should keep you comfortable.';
    } else if (tc <= 22) {
      dressTip = 'Comfortable weather — a light top or casual outfit works well.';
    } else if (tc <= 28) {
      dressTip = 'Warm and pleasant — light, breathable clothing is ideal.';
    } else if (tc <= 35) {
      dressTip = 'Hot day ahead! Stay hydrated and wear light, loose clothing.';
    } else {
      dressTip = 'Extreme heat — limit outdoor exposure, drink water frequently.';
    }

    // ── Humidity note ─────────────────────────────────────────────────────
    String humNote = '';
    if (cw.humidity >= 85) {
      humNote = 'High humidity (${cw.humidity}%) makes the air feel muggy.';
    } else if (cw.humidity <= 25) {
      humNote = 'Very dry air today (${cw.humidity}%) — consider moisturising.';
    }

    // ── Daylight note ────────────────────────────────────────────────────
    String daylightNote = '';
    final sunset  = cw.sunset;
    final sunrise = cw.sunrise;
    final minsToSunset  = sunset.difference(now).inMinutes;
    final minsToSunrise = sunrise.difference(now).inMinutes;
    if (minsToSunset > 0 && minsToSunset < 60) {
      daylightNote = 'Sunset in ${minsToSunset} min — golden hour is near.';
    } else if (minsToSunrise > 0 && minsToSunrise < 60) {
      daylightNote = 'Sunrise in ${minsToSunrise} min — the day is about to begin.';
    }

    // ── Tomorrow outlook ──────────────────────────────────────────────────
    String tomorrowNote = '';
    if (daily.length >= 2) {
      final tom = daily[1];
      final hi  = disp(tom.maxTemp);
      final lo  = disp(tom.minTemp);
      final tDesc = tom.description.isNotEmpty
          ? tom.description : 'similar conditions';
      tomorrowNote = 'Tomorrow: ${hi.toStringAsFixed(0)}/${lo.toStringAsFixed(0)}${unit()} '
          'with ${tDesc.toLowerCase()}.';
    }

    // ── Alert summary ─────────────────────────────────────────────────────
    String alertNote = '';
    if (alerts.isNotEmpty) {
      alertNote = '⚠️ Active alert: ${alerts.first.event}. Stay informed.';
    }

    // ── Assemble paragraphs ───────────────────────────────────────────────
    final bullets = <_Bullet>[];
    if (rainNote.isNotEmpty)     bullets.add(_Bullet(Icons.water_drop_rounded, const Color(0xFF4FC3F7), rainNote));
    if (windNote.isNotEmpty)     bullets.add(_Bullet(Icons.air_rounded, const Color(0xFF80CBC4), windNote));
    if (dressTip.isNotEmpty)     bullets.add(_Bullet(Icons.checkroom_rounded, const Color(0xFFCE93D8), dressTip));
    if (humNote.isNotEmpty)      bullets.add(_Bullet(Icons.water_rounded, const Color(0xFF81D4FA), humNote));
    if (daylightNote.isNotEmpty) bullets.add(_Bullet(Icons.wb_twilight_rounded, const Color(0xFFFFCC80), daylightNote));
    if (alertNote.isNotEmpty)    bullets.add(_Bullet(Icons.warning_amber_rounded, const Color(0xFFFFB74D), alertNote));

    return _AiSummary(
      opening: opening,
      bullets: bullets,
      closing: tomorrowNote,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final summary = _buildSummary();
    final accent  = widget.accentColor;
    final app     = context.watch<AppState>();
    final isLight = app.appTheme == AppTheme.light;
    final subColor  = isLight ? const Color(0xFF4A4A68) : Colors.white.withOpacity(0.75);
    final dimColor  = isLight ? const Color(0xFF8A8AA0) : Colors.white.withOpacity(0.38);
    final cardFill  = isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.04);
    final borderOp  = isLight ? 0.15 : 0.30;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accent.withOpacity(isLight ? 0.08 : 0.13),
              cardFill,
              const Color(0xFF6C3FE8).withOpacity(isLight ? 0.06 : 0.10),
            ],
          ),
          border: Border.all(
            color: accent.withOpacity(borderOp),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(0.08),
              blurRadius: 20,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              children: [
                // Animated shimmer badge
                AnimatedBuilder(
                  animation: _shimmer,
                  builder: (_, __) {
                    return ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: [
                          accent.withOpacity(0.6),
                          Colors.white,
                          const Color(0xFFCE93D8),
                          accent.withOpacity(0.6),
                        ],
                        stops: const [0.0, 0.35, 0.65, 1.0],
                        begin: Alignment(-1.5 + _shimmer.value * 3, 0),
                        end: Alignment(-0.5 + _shimmer.value * 3, 0),
                      ).createShader(bounds),
                      child: const Text(
                        '✦  AI Overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6C3FE8).withOpacity(0.18),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: const Color(0xFF6C3FE8).withOpacity(0.35)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.auto_awesome_rounded,
                        size: 11, color: Color(0xFFCE93D8)),
                    const SizedBox(width: 4),
                    Text(
                      'Smart Summary',
                      style: TextStyle(
                        color: subColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: dimColor,
                  size: 18,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Opening text ────────────────────────────────────────────
            Text(
              summary.opening,
              style: TextStyle(
                color: subColor,
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w400,
              ),
            ),

            // ── Expanded detail bullets ─────────────────────────────────
            if (_expanded && summary.bullets.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...summary.bullets.map((b) => _BulletRow(bullet: b)),
            ],

            // ── Closing / Tomorrow ──────────────────────────────────────
            if (_expanded && summary.closing.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.08)),
                ),
                child: Row(children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 13, color: accent.withOpacity(0.75)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      summary.closing,
                      style: TextStyle(
                        color: dimColor,
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                  ),
                ]),
              ),
            ],

            // ── Collapsed teaser chips ──────────────────────────────────
            if (!_expanded && summary.bullets.isNotEmpty) ...[
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: summary.bullets.take(3).map((b) {
                    return Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: b.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: b.color.withOpacity(0.28)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(b.icon, size: 11, color: b.color),
                        const SizedBox(width: 4),
                        Text(
                          _chipLabel(b.text),
                          style: TextStyle(
                            color: b.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ]),
                    );
                  }).toList(),
                ),
              ),
            ],

            const SizedBox(height: 8),

            // ── Tap hint ────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _expanded ? 'Tap to collapse' : 'Tap for full briefing',
                  style: TextStyle(
                    color: dimColor,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Shorten a bullet text to a short chip label.
  String _chipLabel(String text) {
    if (text.length <= 22) return text;
    final words = text.split(' ');
    String out = '';
    for (final w in words) {
      if ((out + ' $w').length > 22) break;
      out = out.isEmpty ? w : '$out $w';
    }
    return '$out…';
  }
}

// ── Data models ───────────────────────────────────────────────────────────────
class _Bullet {
  final IconData icon;
  final Color    color;
  final String   text;
  const _Bullet(this.icon, this.color, this.text);
}

class _AiSummary {
  final String         opening;
  final List<_Bullet>  bullets;
  final String         closing;
  const _AiSummary({
    required this.opening,
    required this.bullets,
    required this.closing,
  });
}

// ── Bullet row ────────────────────────────────────────────────────────────────
class _BulletRow extends StatelessWidget {
  final _Bullet bullet;
  const _BulletRow({required this.bullet});

  @override
  Widget build(BuildContext context) {
    final isLight = context.watch<AppState>().appTheme == AppTheme.light;
    final textCol = isLight ? const Color(0xFF3A3A52) : Colors.white.withOpacity(0.82);
    return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 1),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: bullet.color.withOpacity(0.14),
            shape: BoxShape.circle,
            border: Border.all(color: bullet.color.withOpacity(0.30)),
          ),
          child: Icon(bullet.icon, size: 12, color: bullet.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            bullet.text,
            style: TextStyle(
              color: textCol,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
  }
}
