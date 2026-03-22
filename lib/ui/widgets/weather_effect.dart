import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Apple Weather-style ambient sky effects
//
// ☀️  01d  clear day    → sun disk + corona + lens flare + god rays
// 🌙  01n  clear night  → crescent moon + earthshine + 3-layer stars + shooting star
// ⛅  02d  partly day   → sun peeking through layered clouds
// 🌥  02n  partly night → moon + stars behind drifting cloud banks
// ☁️  03/04 overcast    → 3-layer volumetric cloud masses + rain mist
// 🌦  09   drizzle      → gentle thin streaks + ground mist
// 🌧  10   rain         → 4-layer parallax rainfall + splash particles + ground mist
// ⛈  11   storm        → heavy rain + forked lightning + thunder flash + dark base clouds
// 🌨  13   snow         → bokeh 3-layer snowfall + gentle drift + ground accumulation haze
// 🌫  50   fog          → rolling volumetric fog banks + reduced visibility
// ─────────────────────────────────────────────────────────────────────────────

class WeatherEffect extends StatefulWidget {
  final String icon;
  const WeatherEffect({super.key, required this.icon});
  @override
  State<WeatherEffect> createState() => _WeatherEffectState();
}

enum _FX {
  none, clearDay, clearNight,
  partlyDay, partlyNight,
  overcast, drizzle, rain, storm,
  snow, fog,
}

_FX _fxFor(String icon) {
  switch (icon) {
    case '01d': return _FX.clearDay;
    case '01n': return _FX.clearNight;
    case '02d': return _FX.partlyDay;
    case '02n': return _FX.partlyNight;
    case '03d': case '04d': case '03n': case '04n': return _FX.overcast;
    case '09d': case '09n': return _FX.drizzle;
    case '10d': case '10n': return _FX.rain;
    case '11d': case '11n': return _FX.storm;
    case '13d': case '13n': return _FX.snow;
    case '50d': case '50n': return _FX.fog;
    default: return _FX.none;
  }
}

// ── Particle ──────────────────────────────────────────────────────────────────
class _P {
  final double x, y, spd, len, w, r, op, ph, dx, layer;
  const _P({
    this.x = 0, this.y = 0, this.spd = 0.1, this.len = 0.02,
    this.w = 1, this.r = 3, this.op = 0.5, this.ph = 0,
    this.dx = 0, this.layer = 0,
  });
}

class _WeatherEffectState extends State<WeatherEffect>
    with TickerProviderStateMixin {
  late AnimationController _tick;
  late AnimationController _flash;
  late List<_P> _pts;
  late List<_P> _clouds;
  late List<_P> _splashes;
  late _FX _fx;
  Timer? _ltTimer;
  int _boltSeed = 0;
  double _shootingStar = -1; // progress of shooting star (-1 = off)
  double _ssX = 0, _ssY = 0, _ssAng = 0;

  @override
  void initState() {
    super.initState();
    _fx = _fxFor(widget.icon);
    _rebuild();
    _tick = AnimationController(vsync: this, duration: const Duration(seconds: 16))..repeat();
    _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    if (_fx == _FX.storm) _scheduleLt();
    if (_fx == _FX.clearNight || _fx == _FX.partlyNight) _scheduleShootingStar();
  }

  @override
  void didUpdateWidget(WeatherEffect old) {
    super.didUpdateWidget(old);
    if (old.icon != widget.icon) {
      _ltTimer?.cancel();
      _fx = _fxFor(widget.icon);
      _rebuild();
      if (_fx == _FX.storm) _scheduleLt(); else { _flash.stop(); _flash.value = 0; }
      if (_fx == _FX.clearNight || _fx == _FX.partlyNight) _scheduleShootingStar();
    }
  }

  void _rebuild() {
    final rng = Random(42);
    _pts = _buildPts(_fx, rng);
    _clouds = _buildClouds(_fx, rng);
    _splashes = _buildSplashes(_fx, rng);
  }

  // ── Lightning ─────────────────────────────────────────────────────────────
  void _scheduleLt() {
    final rng = Random();
    _ltTimer = Timer(Duration(milliseconds: 2200 + rng.nextInt(6000)), () async {
      if (!mounted) return;
      _boltSeed = rng.nextInt(99999);
      await _flash.forward(from: 0);
      await Future.delayed(const Duration(milliseconds: 55));
      await _flash.reverse();
      // Double-strike
      if (rng.nextDouble() > 0.35) {
        await Future.delayed(Duration(milliseconds: 60 + rng.nextInt(80)));
        _boltSeed = rng.nextInt(99999);
        await _flash.forward(from: 0.2);
        await _flash.reverse();
      }
      // Triple-strike (rare)
      if (rng.nextDouble() > 0.70) {
        await Future.delayed(Duration(milliseconds: 120 + rng.nextInt(100)));
        _boltSeed = rng.nextInt(99999);
        await _flash.forward(from: 0.15);
        await _flash.reverse();
      }
      if (mounted) _scheduleLt();
    });
  }

  // ── Shooting star ─────────────────────────────────────────────────────────
  void _scheduleShootingStar() {
    final rng = Random();
    Future.delayed(Duration(seconds: 4 + rng.nextInt(12)), () {
      if (!mounted) return;
      if (_fx != _FX.clearNight && _fx != _FX.partlyNight) return;
      _ssX = 0.15 + rng.nextDouble() * 0.65;
      _ssY = rng.nextDouble() * 0.35;
      _ssAng = 0.4 + rng.nextDouble() * 0.5;
      _shootingStar = 0;
      _scheduleShootingStar();
    });
  }

  // ── Particle builders ──────────────────────────────────────────────────────
  List<_P> _buildPts(_FX fx, Random r) {
    switch (fx) {
      case _FX.drizzle:
        return _genRain(r, 80, [0.10, 0.20], [0.008, 0.012], [0.35, 0.55], [0.08, 0.18], [-0.03, -0.06]);
      case _FX.rain:
        return [
          ..._genRain(r, 55, [0.16, 0.22], [0.008, 0.010], [0.35, 0.55], [0.06, 0.12], [-0.030, -0.050]),
          ..._genRain(r, 50, [0.28, 0.38], [0.012, 0.018], [0.65, 1.0], [0.15, 0.28], [-0.055, -0.085]),
          ..._genRain(r, 30, [0.42, 0.60], [0.018, 0.028], [1.3, 2.2], [0.25, 0.42], [-0.090, -0.140]),
          ..._genRain(r, 12, [0.60, 0.80], [0.028, 0.042], [2.5, 3.5], [0.35, 0.55], [-0.120, -0.180]),
        ];
      case _FX.storm:
        return [
          ..._genRain(r, 80, [0.22, 0.35], [0.012, 0.016], [0.50, 0.80], [0.12, 0.22], [-0.065, -0.100]),
          ..._genRain(r, 65, [0.45, 0.65], [0.018, 0.028], [1.0, 1.8], [0.22, 0.38], [-0.110, -0.170]),
          ..._genRain(r, 40, [0.70, 0.95], [0.026, 0.040], [2.0, 3.2], [0.32, 0.52], [-0.160, -0.240]),
          ..._genRain(r, 18, [0.90, 1.10], [0.035, 0.050], [3.0, 4.2], [0.40, 0.60], [-0.200, -0.280]),
        ];
      case _FX.snow:
        return [
          // Far — tiny sharp flakes
          ...List.generate(80, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble(),
            spd: 0.014 + r.nextDouble() * 0.016, r: 0.8 + r.nextDouble() * 1.2,
            op: 0.22 + r.nextDouble() * 0.28,
            ph: r.nextDouble() * pi * 2, dx: (r.nextDouble() - 0.5) * 0.016, layer: 0,
          )),
          // Mid — soft medium flakes
          ...List.generate(40, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble(),
            spd: 0.022 + r.nextDouble() * 0.024, r: 2.2 + r.nextDouble() * 2.5,
            op: 0.40 + r.nextDouble() * 0.30,
            ph: r.nextDouble() * pi * 2, dx: (r.nextDouble() - 0.5) * 0.026, layer: 1,
          )),
          // Close — large bokeh flakes
          ...List.generate(14, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble(),
            spd: 0.010 + r.nextDouble() * 0.012, r: 6.0 + r.nextDouble() * 8.0,
            op: 0.12 + r.nextDouble() * 0.16,
            ph: r.nextDouble() * pi * 2, dx: (r.nextDouble() - 0.5) * 0.020, layer: 2,
          )),
        ];
      case _FX.fog:
        return List.generate(26, (_) => _P(
          x: r.nextDouble(),
          y: 0.05 + r.nextDouble() * 0.90,
          r: 0.22 + r.nextDouble() * 0.42,
          op: 0.035 + r.nextDouble() * 0.065,
          ph: r.nextDouble() * pi * 2,
          dx: (r.nextBool() ? 1 : -1) * (0.0012 + r.nextDouble() * 0.004),
          layer: r.nextInt(3).toDouble(),
        ));
      case _FX.clearNight: case _FX.partlyNight:
        return [
          // Dust stars
          ...List.generate(120, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.80,
            r: 0.40 + r.nextDouble() * 0.60, op: 0.12 + r.nextDouble() * 0.40,
            ph: r.nextDouble() * pi * 2, spd: 0.15 + r.nextDouble() * 0.50, layer: 0,
          )),
          // Medium stars
          ...List.generate(50, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.78,
            r: 0.8 + r.nextDouble() * 1.0, op: 0.35 + r.nextDouble() * 0.45,
            ph: r.nextDouble() * pi * 2, spd: 0.18 + r.nextDouble() * 0.45, layer: 1,
          )),
          // Bright stars
          ...List.generate(12, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.70,
            r: 1.6 + r.nextDouble() * 1.4, op: 0.65 + r.nextDouble() * 0.35,
            ph: r.nextDouble() * pi * 2, spd: 0.22 + r.nextDouble() * 0.38, layer: 2,
          )),
        ];
      case _FX.clearDay: case _FX.partlyDay:
        return [const _P(x: 0.78, y: 0.085, r: 0.058, op: 1.0, spd: 0.30)];
      case _FX.overcast:
        return [];
      case _FX.none:
        return [];
    }
  }

  List<_P> _genRain(Random r, int n,
      List<double> spdR, List<double> lenR, List<double> wR,
      List<double> opR, List<double> dxR) {
    return List.generate(n, (_) => _P(
      x: r.nextDouble() * 1.4 - 0.2, y: r.nextDouble(),
      spd: spdR[0] + r.nextDouble() * (spdR[1] - spdR[0]),
      len: lenR[0] + r.nextDouble() * (lenR[1] - lenR[0]),
      w: wR[0] + r.nextDouble() * (wR[1] - wR[0]),
      op: opR[0] + r.nextDouble() * (opR[1] - opR[0]),
      dx: dxR[0] + r.nextDouble() * (dxR[1] - dxR[0]),
    ));
  }

  List<_P> _buildClouds(_FX fx, Random r) {
    switch (fx) {
      case _FX.partlyDay: case _FX.partlyNight:
        return [
          ...List.generate(4, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.22,
            r: 0.30 + r.nextDouble() * 0.32, op: 0.06 + r.nextDouble() * 0.06,
            spd: 0.0008 + r.nextDouble() * 0.0020, dx: r.nextBool() ? 1 : -1,
          )),
          ...List.generate(3, (_) => _P(
            x: r.nextDouble(), y: 0.12 + r.nextDouble() * 0.22,
            r: 0.20 + r.nextDouble() * 0.24, op: 0.04 + r.nextDouble() * 0.05,
            spd: 0.0012 + r.nextDouble() * 0.0030, dx: r.nextBool() ? 1 : -1,
          )),
        ];
      case _FX.overcast:
        return [
          ...List.generate(4, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.18,
            r: 0.36 + r.nextDouble() * 0.38, op: 0.12 + r.nextDouble() * 0.08,
            spd: 0.0006 + r.nextDouble() * 0.0018, dx: r.nextBool() ? 1 : -1,
          )),
          ...List.generate(3, (_) => _P(
            x: r.nextDouble(), y: 0.14 + r.nextDouble() * 0.25,
            r: 0.26 + r.nextDouble() * 0.30, op: 0.08 + r.nextDouble() * 0.06,
            spd: 0.0010 + r.nextDouble() * 0.0028, dx: r.nextBool() ? 1 : -1,
          )),
          ...List.generate(3, (_) => _P(
            x: r.nextDouble(), y: 0.30 + r.nextDouble() * 0.22,
            r: 0.22 + r.nextDouble() * 0.24, op: 0.06 + r.nextDouble() * 0.05,
            spd: 0.0015 + r.nextDouble() * 0.0035, dx: r.nextBool() ? 1 : -1,
          )),
        ];
      case _FX.drizzle: case _FX.rain:
        return List.generate(4, (_) => _P(
          x: r.nextDouble(), y: r.nextDouble() * 0.15,
          r: 0.32 + r.nextDouble() * 0.36, op: 0.06 + r.nextDouble() * 0.06,
          spd: 0.0008 + r.nextDouble() * 0.0022, dx: r.nextBool() ? 1 : -1,
        ));
      case _FX.storm:
        return [
          ...List.generate(4, (_) => _P(
            x: r.nextDouble(), y: r.nextDouble() * 0.16,
            r: 0.34 + r.nextDouble() * 0.38, op: 0.14 + r.nextDouble() * 0.08,
            spd: 0.0010 + r.nextDouble() * 0.0028, dx: r.nextBool() ? 1 : -1,
          )),
          ...List.generate(3, (_) => _P(
            x: r.nextDouble(), y: 0.10 + r.nextDouble() * 0.22,
            r: 0.24 + r.nextDouble() * 0.28, op: 0.08 + r.nextDouble() * 0.06,
            spd: 0.0014 + r.nextDouble() * 0.0032, dx: r.nextBool() ? 1 : -1,
          )),
        ];
      default:
        return [];
    }
  }

  List<_P> _buildSplashes(_FX fx, Random r) {
    if (fx != _FX.rain && fx != _FX.storm) return [];
    final count = fx == _FX.storm ? 30 : 18;
    return List.generate(count, (_) => _P(
      x: r.nextDouble(),
      y: 0.92 + r.nextDouble() * 0.08,
      r: 1.5 + r.nextDouble() * 2.5,
      op: 0.15 + r.nextDouble() * 0.25,
      ph: r.nextDouble() * pi * 2,
      spd: 0.5 + r.nextDouble() * 1.5,
    ));
  }

  @override
  void dispose() {
    _ltTimer?.cancel();
    _tick.dispose();
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_fx == _FX.none) return const SizedBox.shrink();

    // Advance shooting star
    if (_shootingStar >= 0 && _shootingStar < 1.0) {
      _shootingStar += 0.018;
      if (_shootingStar >= 1.0) _shootingStar = -1;
    }

    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: Listenable.merge([_tick, _flash]),
          builder: (_, __) => CustomPaint(
            painter: _AppleFXPainter(
              pts: _pts, clouds: _clouds, splashes: _splashes,
              fx: _fx, t: _tick.value,
              flash: _flash.value, boltSeed: _boltSeed,
              shootingStar: _shootingStar,
              ssX: _ssX, ssY: _ssY, ssAng: _ssAng,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Apple-style painter
// ─────────────────────────────────────────────────────────────────────────────
class _AppleFXPainter extends CustomPainter {
  final List<_P> pts, clouds, splashes;
  final _FX fx;
  final double t, flash;
  final int boltSeed;
  final double shootingStar, ssX, ssY, ssAng;

  _AppleFXPainter({
    required this.pts, required this.clouds, required this.splashes,
    required this.fx, required this.t,
    required this.flash, required this.boltSeed,
    required this.shootingStar,
    required this.ssX, required this.ssY, required this.ssAng,
  });

  @override
  bool shouldRepaint(_AppleFXPainter o) => true; // always repaint for smooth animation

  @override
  void paint(Canvas canvas, Size sz) {
    switch (fx) {
      case _FX.clearDay:
        _sun(canvas, sz);
      case _FX.clearNight:
        _nebula(canvas, sz);
        _stars(canvas, sz);
        _shootStar(canvas, sz);
        _moon(canvas, sz);
      case _FX.partlyDay:
        _sun(canvas, sz);
        _cloudLayer(canvas, sz);
      case _FX.partlyNight:
        _nebula(canvas, sz);
        _stars(canvas, sz);
        _shootStar(canvas, sz);
        _moon(canvas, sz);
        _cloudLayer(canvas, sz);
      case _FX.overcast:
        _cloudLayer(canvas, sz);
      case _FX.drizzle:
        _cloudLayer(canvas, sz);
        _rain(canvas, sz);
        _groundMist(canvas, sz, 0.5);
      case _FX.rain:
        _cloudLayer(canvas, sz);
        _rain(canvas, sz);
        _rainSplashes(canvas, sz);
        _groundMist(canvas, sz, 0.8);
      case _FX.storm:
        _cloudLayer(canvas, sz);
        _rain(canvas, sz);
        _rainSplashes(canvas, sz);
        _groundMist(canvas, sz, 1.0);
        if (flash > 0.01) _bolt(canvas, sz);
        _screenFlash(canvas, sz);
      case _FX.snow:
        _snow(canvas, sz);
        _groundMist(canvas, sz, 0.4);
      case _FX.fog:
        _fog(canvas, sz);
      case _FX.none:
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SUN — Apple-style with lens flare + god rays
  // ═══════════════════════════════════════════════════════════════════════════
  void _sun(Canvas canvas, Size sz) {
    final pulse = sin(t * pi * 2 * 0.30) * 0.5 + 0.5;
    final p = pts[0];
    final cx = sz.width * p.x;
    final cy = sz.height * p.y;
    final R = sz.width * p.r;

    // Very wide atmospheric scatter
    _glow(canvas, cx, cy, R * 6.0,
        Colors.white.withOpacity(0.015 + pulse * 0.010), Colors.transparent);
    // Warm atmospheric haze
    _glow(canvas, cx, cy, R * 4.0,
        const Color(0xFFFFE082).withOpacity(0.030 + pulse * 0.022), Colors.transparent);
    // Outer corona
    _glow(canvas, cx, cy, R * 2.2,
        Colors.orange.withOpacity(0.06 + pulse * 0.04), Colors.transparent);
    // Inner corona
    _glow(canvas, cx, cy, R * 1.3,
        Colors.yellow.withOpacity(0.22 + pulse * 0.14),
        Colors.orangeAccent.withOpacity(0.08));
    // White-hot disk
    canvas.drawCircle(Offset(cx, cy), R * 0.48,
        Paint()
          ..color = Colors.white.withOpacity(0.88 + pulse * 0.12)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0));

    // God rays — long, faint, slowly rotating
    _godRays(canvas, cx, cy, R, 12, t, pulse);

    // Lens flare artifacts (hexagonal spots along a line away from center)
    _lensFlare(canvas, sz, cx, cy, pulse);
  }

  void _godRays(Canvas canvas, double cx, double cy, double R,
      int n, double t, double pulse) {
    for (int i = 0; i < n; i++) {
      final a = (i / n) * pi * 2 + t * pi * 0.06;
      final r1 = R * 0.52;
      final r2 = R * (1.3 + (i % 3) * 0.35);
      final w = 1.0 + (i % 2) * 0.8;
      canvas.drawLine(
        Offset(cx + r1 * cos(a), cy + r1 * sin(a)),
        Offset(cx + r2 * cos(a), cy + r2 * sin(a)),
        Paint()
          ..color = Colors.white.withOpacity(0.025 + pulse * 0.020)
          ..strokeWidth = w
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  void _lensFlare(Canvas canvas, Size sz, double sunX, double sunY, double pulse) {
    final cx = sz.width / 2;
    final cy = sz.height / 2;
    final dx = cx - sunX;
    final dy = cy - sunY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final nx = dx / dist;
    final ny = dy / dist;

    final flares = [
      [0.3, 6.0, 0.030, const Color(0xFF80D8FF)],
      [0.5, 10.0, 0.022, const Color(0xFFFFE082)],
      [0.7, 4.0, 0.018, const Color(0xFFCE93D8)],
      [1.0, 14.0, 0.015, const Color(0xFF80CBC4)],
      [1.3, 5.0, 0.020, const Color(0xFFFFCC80)],
    ];
    for (final f in flares) {
      final fx = sunX + nx * dist * (f[0] as double);
      final fy = sunY + ny * dist * (f[0] as double);
      final r = f[1] as double;
      final op = (f[2] as double) + pulse * 0.008;
      final color = f[3] as Color;
      _glow(canvas, fx, fy, r, color.withOpacity(op), Colors.transparent);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // MOON — crescent with earthshine
  // ═══════════════════════════════════════════════════════════════════════════
  void _moon(Canvas canvas, Size sz) {
    final pulse = sin(t * pi * 2 * 0.15) * 0.5 + 0.5;
    final cx = sz.width * 0.75;
    final cy = sz.height * 0.095;
    final R = sz.width * 0.062;

    // Outer halo
    _glow(canvas, cx, cy, R * 5.5,
        const Color(0xFFFFF9C4).withOpacity(0.020 + pulse * 0.014), Colors.transparent);
    // Inner halo
    _glow(canvas, cx, cy, R * 2.6,
        const Color(0xFFFFFDE7).withOpacity(0.050 + pulse * 0.030), Colors.transparent);

    // ── Crescent (saveLayer + dstOut) ──────────────────────────
    final layerRect = Rect.fromCircle(center: Offset(cx, cy), radius: R + 12);
    canvas.saveLayer(layerRect, Paint());

    // Earthshine — faint blue-grey illumination on the dark side
    canvas.drawCircle(Offset(cx, cy), R,
        Paint()..color = const Color(0xFF8899AA).withOpacity(0.12));

    // Full lit disk
    canvas.drawCircle(Offset(cx, cy), R,
        Paint()..color = const Color(0xFFFFFDE7));

    // Surface detail (subtle craters)
    _moonDetail(canvas, cx, cy, R);

    // Shadow carve — produces crescent
    canvas.drawCircle(
      Offset(cx + R * 0.40, cy - R * 0.08), R * 0.82,
      Paint()..blendMode = BlendMode.dstOut..color = Colors.black,
    );
    canvas.restore();

    // Rim highlight on the lit edge
    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: R),
      -pi * 0.55, pi * 1.10, false,
      Paint()
        ..color = Colors.white.withOpacity(0.18 + pulse * 0.10)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
    );
  }

  void _moonDetail(Canvas canvas, double cx, double cy, double R) {
    final p = Paint()
      ..color = const Color(0xFFCDB985).withOpacity(0.15)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, R * 0.10);
    canvas.drawCircle(Offset(cx - R * 0.22, cy + R * 0.18), R * 0.18, p);
    canvas.drawCircle(Offset(cx + R * 0.10, cy - R * 0.28), R * 0.12, p);
    canvas.drawCircle(Offset(cx - R * 0.05, cy - R * 0.04), R * 0.15, p);
    canvas.drawCircle(Offset(cx + R * 0.20, cy + R * 0.25), R * 0.10, p);
    // Maria (dark patches)
    p.color = const Color(0xFFA09070).withOpacity(0.08);
    canvas.drawCircle(Offset(cx - R * 0.10, cy + R * 0.05), R * 0.25, p);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // STARS — 3-layer Apple-style
  // ═══════════════════════════════════════════════════════════════════════════
  void _stars(Canvas canvas, Size sz) {
    final paint = Paint();
    for (final p in pts) {
      final twinkle = sin(t * pi * 2.0 * p.spd + p.ph) * 0.5 + 0.5;
      final op = p.op * (0.20 + 0.80 * twinkle);
      final cx = p.x * sz.width;
      final cy = p.y * sz.height;

      if (p.layer >= 2) {
        // Bright — glow halo + diffraction spikes
        paint
          ..color = Colors.white.withOpacity(op * 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
        canvas.drawCircle(Offset(cx, cy), p.r + 4.5, paint);
        paint
          ..color = Colors.white.withOpacity(op * 0.50)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(Offset(cx, cy), p.r + 1.5, paint);
        paint..color = Colors.white.withOpacity(op)..maskFilter = null;
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
        _diffraction(canvas, cx, cy, p.r * 4.0, op * 0.40);
      } else if (p.layer == 1) {
        // Medium — soft glow
        paint
          ..color = Colors.white.withOpacity(op * 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);
        canvas.drawCircle(Offset(cx, cy), p.r + 2.0, paint);
        paint..color = Colors.white.withOpacity(op)..maskFilter = null;
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
      } else {
        // Tiny
        paint..color = Colors.white.withOpacity(op)..maskFilter = null;
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
      }
    }
  }

  void _diffraction(Canvas canvas, double cx, double cy, double arm, double op) {
    final p = Paint()
      ..strokeWidth = 0.6
      ..strokeCap = StrokeCap.round;
    // 4-point cross
    p.color = Colors.white.withOpacity(op);
    canvas.drawLine(Offset(cx - arm, cy), Offset(cx + arm, cy), p);
    canvas.drawLine(Offset(cx, cy - arm), Offset(cx, cy + arm), p);
    // Fainter diagonal
    final d = arm * 0.5;
    p.color = Colors.white.withOpacity(op * 0.35);
    canvas.drawLine(Offset(cx - d, cy - d), Offset(cx + d, cy + d), p);
    canvas.drawLine(Offset(cx - d, cy + d), Offset(cx + d, cy - d), p);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHOOTING STAR
  // ═══════════════════════════════════════════════════════════════════════════
  void _shootStar(Canvas canvas, Size sz) {
    if (shootingStar < 0 || shootingStar >= 1.0) return;
    final progress = shootingStar;
    final tailLen = 0.12;
    final headX = (ssX + progress * 0.45) * sz.width;
    final headY = (ssY + progress * ssAng * 0.40) * sz.height;
    final tailX = headX - tailLen * sz.width * cos(ssAng);
    final tailY = headY - tailLen * sz.height * sin(ssAng) * 0.5;

    final fade = progress < 0.2 ? progress / 0.2
        : progress > 0.7 ? (1.0 - progress) / 0.3
        : 1.0;

    // Glow trail
    canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), Paint()
      ..color = Colors.white.withOpacity(0.12 * fade)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    // Core trail
    canvas.drawLine(Offset(tailX, tailY), Offset(headX, headY), Paint()
      ..color = Colors.white.withOpacity(0.55 * fade)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round);
    // Head point
    canvas.drawCircle(Offset(headX, headY), 2.0, Paint()
      ..color = Colors.white.withOpacity(0.80 * fade)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // NEBULA
  // ═══════════════════════════════════════════════════════════════════════════
  void _nebula(Canvas canvas, Size sz) {
    // Soft Milky Way suggestion
    _glow(canvas, sz.width * 0.35, sz.height * 0.25, sz.width * 0.75,
        const Color(0xFF5C6BC0).withOpacity(0.028), Colors.transparent);
    _glow(canvas, sz.width * 0.72, sz.height * 0.15, sz.width * 0.50,
        const Color(0xFF42577A).withOpacity(0.018), Colors.transparent);
    _glow(canvas, sz.width * 0.50, sz.height * 0.42, sz.width * 0.55,
        const Color(0xFF7E57C2).withOpacity(0.012), Colors.transparent);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CLOUDS — soft blurred masses composited per-cloud to avoid artefacts
  // ═══════════════════════════════════════════════════════════════════════════
  void _cloudLayer(Canvas canvas, Size sz) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final c in clouds) {
      final rx = ((c.x + t * c.dx * c.spd * 5.0) % 1.8) - 0.40;
      final cx = rx * sz.width;
      final cy = c.y * sz.height;
      final r = c.r * sz.width;

      // Composite the entire cloud into a single layer so overlapping
      // blobs don't accumulate opacity and create grid/chess patterns.
      final layerRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: r * 3.2,
        height: r * 2.4,
      );
      canvas.saveLayer(layerRect, Paint()..color = Colors.white.withOpacity(c.op));

      paint
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.45);

      // Main body
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: r * 2.0, height: r * 0.9),
        paint,
      );
      // Top bump
      canvas.drawCircle(Offset(cx + r * 0.08, cy - r * 0.22), r * 0.42, paint);
      // Left bump
      canvas.drawCircle(Offset(cx - r * 0.40, cy + r * 0.05), r * 0.38, paint);
      // Right bump
      canvas.drawCircle(Offset(cx + r * 0.35, cy + r * 0.02), r * 0.36, paint);

      canvas.restore();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RAIN — Apple-style angled streaks with motion blur
  // ═══════════════════════════════════════════════════════════════════════════
  void _rain(Canvas canvas, Size sz) {
    final paint = Paint()..strokeCap = StrokeCap.round;
    for (final p in pts) {
      final ry = (p.y + t * p.spd * 4.8) % 1.15 - 0.15;
      if (ry < -0.05 || ry > 1.05) continue;
      final traveled = (ry - p.y + 1.0) % 1.0;
      final rx = p.x + traveled * p.dx;
      final len = p.len * sz.height;
      final ang = atan2(p.dx * sz.height, sz.height);

      // Fade at top and bottom edges
      double fade = 1.0;
      if (ry < 0.05) fade = ry / 0.05;
      if (ry > 0.92) fade = (1.0 - ry) / 0.08;
      fade = fade.clamp(0.0, 1.0);

      paint
        ..color = const Color(0xFFCFE8F8).withOpacity(p.op * fade)
        ..strokeWidth = p.w;
      final px = rx * sz.width;
      final py = ry * sz.height;
      canvas.drawLine(
        Offset(px, py),
        Offset(px + len * sin(ang), py - len * cos(ang)),
        paint,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // RAIN SPLASHES — small burst circles at the bottom
  // ═══════════════════════════════════════════════════════════════════════════
  void _rainSplashes(Canvas canvas, Size sz) {
    final paint = Paint();
    for (final s in splashes) {
      // Each splash has its own phase cycling
      final phase = (t * s.spd * 5.0 + s.ph) % 1.0;
      final r = s.r * (0.5 + phase * 1.5);
      final op = s.op * (1.0 - phase); // fade out as it expands

      paint
        ..color = Colors.white.withOpacity(op * 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..maskFilter = null;
      canvas.drawCircle(Offset(s.x * sz.width, s.y * sz.height), r, paint);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // GROUND MIST — semi-transparent haze at bottom
  // ═══════════════════════════════════════════════════════════════════════════
  void _groundMist(Canvas canvas, Size sz, double intensity) {
    final rect = Rect.fromLTWH(0, sz.height * 0.82, sz.width, sz.height * 0.18);
    canvas.drawRect(rect, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          Colors.white.withOpacity(0.018 * intensity),
          Colors.white.withOpacity(0.04 * intensity),
        ],
      ).createShader(rect));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // LIGHTNING BOLT — forked with branches
  // ═══════════════════════════════════════════════════════════════════════════
  void _bolt(Canvas canvas, Size sz) {
    final rng = Random(boltSeed);
    final startX = sz.width * (0.12 + rng.nextDouble() * 0.76);
    final segs = 6 + rng.nextInt(5);
    final points = <Offset>[Offset(startX, 0)];
    for (int i = 1; i <= segs; i++) {
      final jag = (rng.nextDouble() - 0.5) * sz.width * 0.18;
      points.add(Offset(points.last.dx + jag, sz.height * (i / segs) * 0.85));
    }
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (var p in points.skip(1)) path.lineTo(p.dx, p.dy);

    // Sky illumination around bolt
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFFB3E5FC).withOpacity(flash * 0.18)
      ..strokeWidth = 40
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28));
    // Wide glow
    canvas.drawPath(path, Paint()
      ..color = const Color(0xFF80D8FF).withOpacity(flash * 0.30)
      ..strokeWidth = 18
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12));
    // Mid glow
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(flash * 0.55)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    // Core bolt
    canvas.drawPath(path, Paint()
      ..color = Colors.white.withOpacity(flash * 0.95)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round);

    // Branches at 2-3 points
    for (int b = 0; b < min(3, points.length - 2); b++) {
      if (rng.nextDouble() > 0.45) continue;
      final bp = points[1 + b];
      final branchSegs = 2 + rng.nextInt(3);
      final bPath = Path()..moveTo(bp.dx, bp.dy);
      var bx = bp.dx, by = bp.dy;
      for (int j = 0; j < branchSegs; j++) {
        bx += (rng.nextDouble() - 0.35) * sz.width * 0.12;
        by += sz.height * 0.06 + rng.nextDouble() * sz.height * 0.04;
        bPath.lineTo(bx, by);
      }
      canvas.drawPath(bPath, Paint()
        ..color = Colors.white.withOpacity(flash * 0.35)
        ..strokeWidth = 1.0
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
      canvas.drawPath(bPath, Paint()
        ..color = Colors.white.withOpacity(flash * 0.65)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke);
    }
  }

  void _screenFlash(Canvas canvas, Size sz) {
    if (flash < 0.01) return;
    // Top-heavier flash (sky illumination)
    canvas.drawRect(Rect.fromLTWH(0, 0, sz.width, sz.height), Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity(flash * 0.35),
          Colors.white.withOpacity(flash * 0.12),
        ],
      ).createShader(Rect.fromLTWH(0, 0, sz.width, sz.height)));
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SNOW — bokeh depth-of-field
  // ═══════════════════════════════════════════════════════════════════════════
  void _snow(Canvas canvas, Size sz) {
    final paint = Paint();
    for (final p in pts) {
      final ry = (p.y + t * p.spd * 3.0) % 1.08 - 0.08;
      if (ry < -0.05 || ry > 1.05) continue;
      final sway = sin(t * pi * 2.5 * p.spd + p.ph) * 0.022;
      final rx = ((p.x + sway + p.dx * t * 3.0) % 1.08 + 1.08) % 1.08 - 0.04;
      final cx = rx * sz.width;
      final cy = ry * sz.height;

      if (p.layer >= 2) {
        // Large bokeh flakes (out of focus / close to camera)
        paint
          ..color = Colors.white.withOpacity(p.op)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.35);
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
        // Soft fill
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(p.op * 0.30)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.55);
        canvas.drawCircle(Offset(cx, cy), p.r * 0.85, paint);
      } else if (p.layer == 1) {
        // Medium — soft solid flakes
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(p.op)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, p.r * 0.30);
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
      } else {
        // Tiny sharp flakes
        paint
          ..style = PaintingStyle.fill
          ..color = Colors.white.withOpacity(p.op)
          ..maskFilter = null;
        canvas.drawCircle(Offset(cx, cy), p.r, paint);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // FOG — soft blurred elliptical banks
  // ═══════════════════════════════════════════════════════════════════════════
  void _fog(Canvas canvas, Size sz) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in pts) {
      final rx = ((p.x + t * p.dx * 1.2 + p.ph * 0.03) % 1.6) - 0.30;
      final ry = p.y + sin(t * pi * 2 * 0.18 + p.ph) * 0.025;
      final cx = rx * sz.width;
      final cy = ry * sz.height;
      final rw = p.r * sz.width;
      final rh = rw * 0.32;

      final layerRect = Rect.fromCenter(
        center: Offset(cx, cy),
        width: rw * 2.5,
        height: rh * 2.5,
      );
      canvas.saveLayer(layerRect, Paint()..color = Colors.white.withOpacity(p.op));

      paint
        ..color = Colors.white
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, rw * 0.40);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, cy), width: rw * 2.0, height: rh * 2.0),
        paint,
      );

      canvas.restore();
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // HELPER
  // ═══════════════════════════════════════════════════════════════════════════
  void _glow(Canvas canvas, double cx, double cy,
      double r, Color inner, Color outer) {
    if (r <= 0) return;
    canvas.drawCircle(Offset(cx, cy), r, Paint()
      ..shader = RadialGradient(colors: [inner, outer])
          .createShader(Rect.fromCircle(center: Offset(cx, cy), radius: r)));
  }
}
