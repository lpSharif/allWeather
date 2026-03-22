import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/weather_models.dart';
import '../../providers/app_state.dart';

/// ─────────────────────────────────────────────────────────────────────────────
/// TEMP CHART — temperature (solid) + feels-like (dashed) curves
/// ─────────────────────────────────────────────────────────────────────────────
class TempChart extends StatefulWidget {
  final List<HourlyForecastEntry> items;
  const TempChart({super.key, required this.items});

  @override
  State<TempChart> createState() => _TempChartState();
}

class _TempChartState extends State<TempChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim.forward();
  }

  @override
  void didUpdateWidget(TempChart old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) _anim.forward(from: 0);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  List<HourlyForecastEntry> get _pts {
    final src = widget.items.take(24).toList();
    final out = <HourlyForecastEntry>[];
    for (int i = 0; i < src.length; i += 3) out.add(src[i]);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pts = _pts;
    if (pts.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GestureDetector(
        onTapDown:  (d) => _onTap(d.localPosition, context),
        onPanUpdate:(d) => _onTap(d.localPosition, context),
        onPanEnd:   (_) => setState(() => _hover = null),
        onTapUp:    (_) => setState(() => _hover = null),
        child: CustomPaint(
          size: const Size(double.infinity, 200),
          painter: _TempPainter(
            points: pts,
            progress: _anim.value,
            hover: _hover,
            displayTemp: app.displayTemp,
            unit: app.tempUnit(),
            isLight: app.appTheme == AppTheme.light,
          ),
        ),
      ),
    );
  }

  void _onTap(Offset pos, BuildContext ctx) {
    final pts = _pts;
    if (pts.isEmpty) return;
    final w = ctx.size?.width ?? 300.0;
    const padL = 44.0;
    final step = (w - padL - 16) / (pts.length - 1);
    int best = 0; double bestD = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = (pos.dx - (padL + i * step)).abs();
      if (d < bestD) { bestD = d; best = i; }
    }
    setState(() => _hover = best);
  }
}

class _TempPainter extends CustomPainter {
  final List<HourlyForecastEntry> points;
  final double progress;
  final int? hover;
  final double Function(double) displayTemp;
  final String unit;
  final bool isLight;

  _TempPainter({required this.points, required this.progress,
      required this.hover, required this.displayTemp, required this.unit,
      this.isLight = false});

  static const double padL   = 44;
  static const double padR   = 16;
  static const double padTop = 32;
  static const double padBot = 24; // time labels
  static const Color _cTemp  = Color(0xFF81D4FA);
  static const Color _cFeel  = Color(0xFFFFCC80);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final n = points.length;
    if (n < 2) return;

    // Theme-aware color helpers
    final Color _fg    = isLight ? const Color(0xFF1A1A2E) : Colors.white;
    final Color _fgDim = isLight ? const Color(0xFF8A8AA0) : Colors.white.withOpacity(0.50);
    final Color _grid  = isLight ? Colors.black.withOpacity(0.06) : Colors.white.withOpacity(0.06);
    final Color _label = isLight ? const Color(0xFF4A4A68).withOpacity(0.80) : Colors.white.withOpacity(0.80);
    final Color _labelHi = isLight ? const Color(0xFF1A1A2E) : Colors.white;
    final Color _axisC = isLight ? const Color(0xFF8A8AA0).withOpacity(0.50) : Colors.white.withOpacity(0.28);
    final Color _timeC = isLight ? const Color(0xFF8A8AA0).withOpacity(0.60) : Colors.white.withOpacity(0.38);
    final Color _lineC = isLight ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.15);
    final Color _tipBg = isLight ? const Color(0xFFF5F5FA).withOpacity(0.97) : const Color(0xFF0D1E30).withOpacity(0.95);
    final Color _tipTimC = isLight ? const Color(0xFF8A8AA0) : Colors.white54;
    final Color _tipValC = isLight ? const Color(0xFF1A1A2E) : Colors.white;

    final zoneTop = padTop;
    final zoneBot = h - padBot;
    final zoneH   = zoneBot - zoneTop;
    final step    = (w - padL - padR) / (n - 1);

    double tx(int i) => padL + i * step;

    final temps  = points.map((p) => displayTemp(p.temp)).toList();
    final feels  = points.map((p) => displayTemp(p.feelsLike)).toList();
    final allVals = [...temps, ...feels];
    final vMin  = allVals.reduce(min) - 2;
    final vMax  = allVals.reduce(max) + 2;
    final vRange = (vMax - vMin).clamp(1.0, double.infinity);

    double vy(double v) => zoneTop + zoneH * (1 - (v - vMin) / vRange);

    // ── Grid ──────────────────────────────────────────────────────────────
    final gridP = Paint()..color = _grid..strokeWidth = 1;
    for (int g = 0; g <= 3; g++) {
      final y = zoneTop + zoneH * g / 3;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridP);
    }

    // ── Feels-like dashed line (behind temp) ──────────────────────────────
    _drawDashedCurve(canvas, points, feels, tx, vy, zoneBot, progress,
        _cFeel.withOpacity(0.65), 1.8);

    // ── Temp filled area ──────────────────────────────────────────────────
    final areaPath = Path()..moveTo(tx(0), zoneBot);
    for (int i = 0; i < n; i++) {
      final x = tx(i), y = _lerp(zoneBot, vy(temps[i]), progress);
      if (i == 0) { areaPath.lineTo(x, y); }
      else {
        final px = tx(i-1), py = _lerp(zoneBot, vy(temps[i-1]), progress);
        areaPath.cubicTo((px+x)/2, py, (px+x)/2, y, x, y);
      }
    }
    areaPath..lineTo(tx(n-1), zoneBot)..close();
    canvas.drawPath(areaPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_cTemp.withOpacity(0.20), _cTemp.withOpacity(0.02)],
      ).createShader(Rect.fromLTWH(0, zoneTop, w, zoneH))
      ..style = PaintingStyle.fill);

    // ── Temp solid line ───────────────────────────────────────────────────
    _drawSolidCurve(canvas, points, temps, tx, vy, zoneBot, progress,
        _cTemp, 2.5);

    // ── Dots + temp labels ────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final x  = tx(i);
      final y  = _lerp(zoneBot, vy(temps[i]), progress);
      final fy = _lerp(zoneBot, vy(feels[i]), progress);
      final hi = hover == i;

      if (hi) canvas.drawCircle(Offset(x, y), 9,
          Paint()..color = _cTemp.withOpacity(0.18));

      // temp dot
      canvas.drawCircle(Offset(x, y), hi ? 5.5 : 3.5,
          Paint()..color = hi ? _fg : _cTemp);
      canvas.drawCircle(Offset(x, y), hi ? 5.5 : 3.5,
          Paint()..color = _cTemp..strokeWidth = 1.5..style = PaintingStyle.stroke);

      // feels dot (small)
      if (!hi) {
        canvas.drawCircle(Offset(x, fy), 2.5,
            Paint()..color = _cFeel.withOpacity(0.70));
      }

      // temp label above dot
      _drawText(canvas, '${temps[i].toStringAsFixed(0)}$unit', Offset(x, y - 15),
          fontSize: hi ? 11 : 10,
          fontWeight: hi ? FontWeight.w700 : FontWeight.w500,
          color: hi ? _labelHi : _label,
          align: TextAlign.center);
    }

    // ── Hover tooltip ─────────────────────────────────────────────────────
    if (hover != null && hover! < n) {
      final i    = hover!;
      final x    = tx(i);
      final y    = _lerp(zoneBot, vy(temps[i]), progress);
      final time = DateFormat('HH:mm').format(points[i].time);

      final tpTime = _tp(i == 0 ? 'Now' : time,       10, _tipTimC, FontWeight.w500);
      final tpTemp = _tp('${temps[i].toStringAsFixed(0)}$unit', 17, _tipValC, FontWeight.w700);
      final tpFeel = _tp('Feels ${feels[i].toStringAsFixed(0)}$unit', 11, _cFeel, FontWeight.w500);
      tpTime.layout(); tpTemp.layout(); tpFeel.layout();

      const bPad = 10.0;
      final bw = [tpTime.width, tpTemp.width, tpFeel.width].reduce(max) + bPad * 2;
      final bh = tpTime.height + 4 + tpTemp.height + 4 + tpFeel.height + bPad * 2;
      double bx = x - bw / 2;
      bx = bx.clamp(padL, w - padR - bw);
      final by = max(4.0, y - bh - 14);

      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(12));
      canvas.drawRRect(rr.shift(const Offset(0, 2)),
          Paint()..color = Colors.black.withOpacity(0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawRRect(rr, Paint()..color = _tipBg);
      canvas.drawRRect(rr, Paint()..color = _cTemp.withOpacity(0.28)
          ..strokeWidth = 1..style = PaintingStyle.stroke);

      double ty = by + bPad;
      tpTime.paint(canvas, Offset(bx + bPad, ty)); ty += tpTime.height + 4;
      tpTemp.paint(canvas, Offset(bx + bPad, ty)); ty += tpTemp.height + 4;
      tpFeel.paint(canvas, Offset(bx + bPad, ty));

      canvas.drawLine(Offset(x, by + bh + 4), Offset(x, y - 7),
          Paint()..color = _lineC..strokeWidth = 1);
    }

    // ── Time labels ───────────────────────────────────────────────────────
    final timeFmt = DateFormat('ha');
    for (int i = 0; i < n; i++) {
      _drawText(canvas, i == 0 ? 'Now' : timeFmt.format(points[i].time).toLowerCase(),
          Offset(tx(i), h - padBot + 5),
          fontSize: 10, color: _timeC, align: TextAlign.center);
    }

    // ── Y-axis ────────────────────────────────────────────────────────────
    for (int g = 0; g <= 2; g++) {
      final v = vMin + vRange * (1 - g / 2);
      final y = zoneTop + zoneH * g / 2;
      _drawText(canvas, '${v.toStringAsFixed(0)}°', Offset(padL - 6, y - 6),
          fontSize: 9, color: _axisC, align: TextAlign.right);
    }

    // ── Legend ────────────────────────────────────────────────────────────
    // Temp line swatch
    canvas.drawLine(const Offset(padL, 13), const Offset(padL + 14, 13),
        Paint()..color = _cTemp..strokeWidth = 2);
    canvas.drawCircle(const Offset(padL + 7, 13), 2.5, Paint()..color = _cTemp);
    _drawText(canvas, 'Temp', const Offset(padL + 18, 6),
        fontSize: 9, color: _fgDim);

    // Feels-like dashed swatch
    const flX = padL + 70.0;
    _drawDashSegment(canvas, const Offset(flX, 13), const Offset(flX + 14, 13),
        _cFeel.withOpacity(0.75), 1.5);
    canvas.drawCircle(const Offset(flX + 7, 13), 2, Paint()..color = _cFeel.withOpacity(0.75));
    _drawText(canvas, 'Feels like', const Offset(flX + 18, 6),
        fontSize: 9, color: _fgDim);
  }

  // ── Curve helpers ──────────────────────────────────────────────────────────
  void _drawSolidCurve(Canvas canvas, List<HourlyForecastEntry> pts,
      List<double> vals, double Function(int) tx, double Function(double) vy,
      double zoneBot, double progress, Color color, double strokeW) {
    final path = Path();
    final n = pts.length;
    for (int i = 0; i < n; i++) {
      final x = tx(i), y = _lerp(zoneBot, vy(vals[i]), progress);
      if (i == 0) path.moveTo(x, y);
      else {
        final px = tx(i-1), py = _lerp(zoneBot, vy(vals[i-1]), progress);
        path.cubicTo((px+x)/2, py, (px+x)/2, y, x, y);
      }
    }
    canvas.drawPath(path, Paint()
      ..color = color..strokeWidth = strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);
  }

  void _drawDashedCurve(Canvas canvas, List<HourlyForecastEntry> pts,
      List<double> vals, double Function(int) tx, double Function(double) vy,
      double zoneBot, double progress, Color color, double strokeW) {
    // Approximate dashed by sampling many short segments along the bezier
    final n = pts.length;
    const dashLen = 5.0, gapLen = 4.0;
    double accumulated = 0;
    bool drawing = true;

    for (int i = 1; i < n; i++) {
      final x0 = tx(i-1), y0 = _lerp(zoneBot, vy(vals[i-1]), progress);
      final x1 = tx(i),   y1 = _lerp(zoneBot, vy(vals[i]), progress);
      final cx = (x0 + x1) / 2;
      // Subdivide bezier into small straight segments
      const steps = 20;
      for (int s = 0; s < steps; s++) {
        final t0 = s / steps, t1 = (s + 1) / steps;
        final p0 = _bezierPoint(x0, y0, cx, y0, cx, y1, x1, y1, t0);
        final p1 = _bezierPoint(x0, y0, cx, y0, cx, y1, x1, y1, t1);
        final segLen = (p1 - p0).distance;
        if (drawing) {
          canvas.drawLine(p0, p1,
              Paint()..color = color..strokeWidth = strokeW..strokeCap = StrokeCap.round);
        }
        accumulated += segLen;
        if (drawing && accumulated >= dashLen) { drawing = false; accumulated = 0; }
        else if (!drawing && accumulated >= gapLen) { drawing = true; accumulated = 0; }
      }
    }
  }

  void _drawDashSegment(Canvas canvas, Offset a, Offset b, Color c, double sw) {
    const dash = 4.0, gap = 3.0;
    final dir = (b - a);
    final len = dir.distance;
    final unit = dir / len;
    double pos = 0; bool draw = true;
    while (pos < len) {
      final end = min(pos + (draw ? dash : gap), len);
      if (draw) {
        canvas.drawLine(a + unit * pos, a + unit * end,
            Paint()..color = c..strokeWidth = sw..strokeCap = StrokeCap.round);
      }
      pos = end; draw = !draw;
    }
  }

  Offset _bezierPoint(double x0, double y0, double cx0, double cy0,
      double cx1, double cy1, double x1, double y1, double t) {
    final mt = 1 - t;
    final x = mt*mt*mt*x0 + 3*mt*mt*t*cx0 + 3*mt*t*t*cx1 + t*t*t*x1;
    final y = mt*mt*mt*y0 + 3*mt*mt*t*cy0 + 3*mt*t*t*cy1 + t*t*t*y1;
    return Offset(x, y);
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  TextPainter _tp(String text, double fs, Color color, FontWeight fw) =>
      TextPainter(
        text: TextSpan(text: text, style: TextStyle(fontSize: fs, color: color, fontWeight: fw)),
        textDirection: ui.TextDirection.ltr,
      );

  void _drawText(Canvas canvas, String text, Offset offset,
      {double fontSize = 10, Color color = Colors.white,
       FontWeight fontWeight = FontWeight.normal, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight)),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 110);
    double dx = offset.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    if (align == TextAlign.right)  dx -= tp.width;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(_TempPainter old) =>
      old.progress != progress || old.hover != hover ||
      old.points != points || old.unit != unit || old.isLight != isLight;
}

/// ─────────────────────────────────────────────────────────────────────────────
/// RAIN CHART — probability of precipitation smooth area
/// ─────────────────────────────────────────────────────────────────────────────
class RainChart extends StatefulWidget {
  final List<HourlyForecastEntry> items;
  const RainChart({super.key, required this.items});

  @override
  State<RainChart> createState() => _RainChartState();
}

class _RainChartState extends State<RainChart>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  int? _hover;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _anim.forward();
  }

  @override
  void didUpdateWidget(RainChart old) {
    super.didUpdateWidget(old);
    if (old.items != widget.items) _anim.forward(from: 0);
  }

  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  List<HourlyForecastEntry> get _pts {
    final src = widget.items.take(24).toList();
    final out = <HourlyForecastEntry>[];
    for (int i = 0; i < src.length; i += 3) out.add(src[i]);
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final pts = _pts;
    if (pts.isEmpty) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => GestureDetector(
        onTapDown:  (d) => _onTap(d.localPosition, context),
        onPanUpdate:(d) => _onTap(d.localPosition, context),
        onPanEnd:   (_) => setState(() => _hover = null),
        onTapUp:    (_) => setState(() => _hover = null),
        child: CustomPaint(
          size: const Size(double.infinity, 160),
          painter: _RainPainter(
            points: pts,
            progress: _anim.value,
            hover: _hover,
            isLight: app.appTheme == AppTheme.light,
          ),
        ),
      ),
    );
  }

  void _onTap(Offset pos, BuildContext ctx) {
    final pts = _pts;
    if (pts.isEmpty) return;
    final w = ctx.size?.width ?? 300.0;
    const padL = 44.0;
    final step = (w - padL - 16) / (pts.length - 1);
    int best = 0; double bestD = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = (pos.dx - (padL + i * step)).abs();
      if (d < bestD) { bestD = d; best = i; }
    }
    setState(() => _hover = best);
  }
}

class _RainPainter extends CustomPainter {
  final List<HourlyForecastEntry> points;
  final double progress;
  final int? hover;
  final bool isLight;

  _RainPainter({required this.points, required this.progress, required this.hover,
      this.isLight = false});

  static const double padL   = 44;
  static const double padR   = 16;
  static const double padTop = 28;
  static const double padBot = 22;
  static const Color _cLine  = Color(0xFF4FC3F7);
  static const Color _cFill1 = Color(0xFF29B6F6);
  static const Color _cFill2 = Color(0xFF0D47A1);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final n = points.length;
    if (n < 2) return;

    // Theme-aware color helpers
    final Color _fg    = isLight ? const Color(0xFF1A1A2E) : Colors.white;
    final Color _fgDim = isLight ? const Color(0xFF8A8AA0) : Colors.white.withOpacity(0.50);
    final Color _grid  = isLight ? Colors.black.withOpacity(0.05) : Colors.white.withOpacity(0.05);
    final Color _axisC = isLight ? const Color(0xFF8A8AA0).withOpacity(0.50) : Colors.white.withOpacity(0.25);
    final Color _axisD = isLight ? const Color(0xFF8A8AA0).withOpacity(0.40) : Colors.white.withOpacity(0.20);
    final Color _timeC = isLight ? const Color(0xFF8A8AA0).withOpacity(0.60) : Colors.white.withOpacity(0.38);
    final Color _lineC = isLight ? Colors.black.withOpacity(0.10) : Colors.white.withOpacity(0.15);
    final Color _tipBg = isLight ? const Color(0xFFF5F5FA).withOpacity(0.97) : const Color(0xFF0D1E30).withOpacity(0.95);
    final Color _tipTimC = isLight ? const Color(0xFF8A8AA0) : Colors.white54;
    final Color _tipValC = isLight ? const Color(0xFF1A1A2E) : Colors.white;

    final zoneTop = padTop;
    final zoneBot = h - padBot;
    final zoneH   = zoneBot - zoneTop;
    final step    = (w - padL - padR) / (n - 1);

    double tx(int i) => padL + i * step;
    final pops = points.map((p) => p.pop.clamp(0.0, 1.0)).toList();
    double py(double pop) => zoneBot - zoneH * pop * progress;

    // ── Grid (0 / 50 / 100%) ─────────────────────────────────────────────
    final gridP = Paint()..color = _grid..strokeWidth = 1;
    for (final frac in [0.5, 1.0]) {
      final y = zoneBot - zoneH * frac;
      canvas.drawLine(Offset(padL, y), Offset(w - padR, y), gridP);
      final label = frac == 1.0 ? '100%' : '50%';
      _drawText(canvas, label, Offset(padL - 6, y - 6),
          fontSize: 8, color: _axisC, align: TextAlign.right);
    }
    // 0% baseline label
    _drawText(canvas, '0%', Offset(padL - 6, zoneBot - 5),
        fontSize: 8, color: _axisD, align: TextAlign.right);

    // ── Filled area ───────────────────────────────────────────────────────
    final areaPath = Path()..moveTo(tx(0), zoneBot);
    for (int i = 0; i < n; i++) {
      final x = tx(i), y = py(pops[i]);
      if (i == 0) { areaPath.lineTo(x, y); }
      else {
        final px = tx(i-1), prev = py(pops[i-1]);
        areaPath.cubicTo((px+x)/2, prev, (px+x)/2, y, x, y);
      }
    }
    areaPath..lineTo(tx(n-1), zoneBot)..close();
    canvas.drawPath(areaPath, Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [_cFill1.withOpacity(0.60), _cFill2.withOpacity(0.08)],
      ).createShader(Rect.fromLTWH(0, zoneTop, w, zoneH))
      ..style = PaintingStyle.fill);

    // ── Outline curve ─────────────────────────────────────────────────────
    final linePath = Path();
    for (int i = 0; i < n; i++) {
      final x = tx(i), y = py(pops[i]);
      if (i == 0) linePath.moveTo(x, y);
      else {
        final px = tx(i-1), prev = py(pops[i-1]);
        linePath.cubicTo((px+x)/2, prev, (px+x)/2, y, x, y);
      }
    }
    canvas.drawPath(linePath, Paint()
      ..color = _cLine.withOpacity(0.90)..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round);

    // ── Dots + peak labels ────────────────────────────────────────────────
    for (int i = 0; i < n; i++) {
      final pop = pops[i];
      if (pop < 0.05) continue;
      final x = tx(i), y = py(pop);
      final hi = hover == i;

      if (hi) canvas.drawCircle(Offset(x, y), 8,
          Paint()..color = _cLine.withOpacity(0.18));

      canvas.drawCircle(Offset(x, y), hi ? 5 : 3.5,
          Paint()..color = hi ? _fg : _cLine);
      canvas.drawCircle(Offset(x, y), hi ? 5 : 3.5,
          Paint()..color = _cLine..strokeWidth = 1.5..style = PaintingStyle.stroke);

      final isPeak = (i == 0 || pops[i] >= pops[i-1]) &&
          (i == n-1 || pops[i] >= pops[i+1]);
      if (isPeak || hi) {
        final pct = '${(pop * 100).round()}%';
        final tp = TextPainter(
          text: TextSpan(text: pct,
              style: TextStyle(fontSize: 9, color: _fg,
                  fontWeight: FontWeight.w700)),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        final pillW = tp.width + 8, pillH = tp.height + 4;
        double pillX = x - pillW / 2;
        pillX = pillX.clamp(padL, w - padR - pillW);
        final pillY = y - pillH - 4;
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(pillX, pillY, pillW, pillH), const Radius.circular(5)),
          Paint()..color = _cFill1.withOpacity(0.80),
        );
        tp.paint(canvas, Offset(pillX + 4, pillY + 2));
      }
    }

    // ── Hover tooltip ─────────────────────────────────────────────────────
    if (hover != null && hover! < n) {
      final i   = hover!;
      final x   = tx(i);
      final pop = pops[i];
      final y   = py(pop);
      final time = DateFormat('HH:mm').format(points[i].time);

      final tpTime = TextPainter(
        text: TextSpan(text: i == 0 ? 'Now' : time,
            style: TextStyle(fontSize: 10, color: _tipTimC, fontWeight: FontWeight.w500)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final tpPop = TextPainter(
        text: TextSpan(text: '${(pop * 100).round()}%',
            style: TextStyle(fontSize: 20, color: _tipValC, fontWeight: FontWeight.w700)),
        textDirection: ui.TextDirection.ltr,
      )..layout();
      final tpLbl = TextPainter(
        text: TextSpan(text: 'rain chance',
            style: TextStyle(fontSize: 10, color: _cLine.withOpacity(0.75), fontWeight: FontWeight.w500)),
        textDirection: ui.TextDirection.ltr,
      )..layout();

      const bPad = 10.0;
      final bw = [tpTime.width, tpPop.width, tpLbl.width].reduce(max) + bPad * 2;
      final bh = tpTime.height + 4 + tpPop.height + 2 + tpLbl.height + bPad * 2;
      double bx = x - bw / 2;
      bx = bx.clamp(padL, w - padR - bw);
      final by = max(4.0, y - bh - 12);

      final rr = RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(12));
      canvas.drawRRect(rr.shift(const Offset(0, 2)),
          Paint()..color = Colors.black.withOpacity(0.22)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
      canvas.drawRRect(rr, Paint()..color = _tipBg);
      canvas.drawRRect(rr, Paint()..color = _cLine.withOpacity(0.28)
          ..strokeWidth = 1..style = PaintingStyle.stroke);

      double ty = by + bPad;
      tpTime.paint(canvas, Offset(bx + bPad, ty)); ty += tpTime.height + 4;
      tpPop.paint(canvas,  Offset(bx + bPad, ty)); ty += tpPop.height + 2;
      tpLbl.paint(canvas,  Offset(bx + bPad, ty));

      canvas.drawLine(Offset(x, by + bh + 4), Offset(x, y - 7),
          Paint()..color = _lineC..strokeWidth = 1);
    }

    // ── Time labels ───────────────────────────────────────────────────────
    final timeFmt = DateFormat('ha');
    for (int i = 0; i < n; i++) {
      _drawText(canvas, i == 0 ? 'Now' : timeFmt.format(points[i].time).toLowerCase(),
          Offset(tx(i), h - padBot + 5),
          fontSize: 10, color: _timeC, align: TextAlign.center);
    }

    // ── Legend ────────────────────────────────────────────────────────────
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(padL, 7, 12, 10), const Radius.circular(3)),
      Paint()..color = _cFill1.withOpacity(0.70),
    );
    _drawText(canvas, 'Rain probability', const Offset(padL + 16, 6),
        fontSize: 9, color: _fgDim);
  }

  void _drawText(Canvas canvas, String text, Offset offset,
      {double fontSize = 10, Color color = Colors.white,
       FontWeight fontWeight = FontWeight.normal, TextAlign align = TextAlign.left}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: TextStyle(fontSize: fontSize, color: color, fontWeight: fontWeight)),
      textDirection: ui.TextDirection.ltr,
    )..layout(maxWidth: 110);
    double dx = offset.dx;
    if (align == TextAlign.center) dx -= tp.width / 2;
    if (align == TextAlign.right)  dx -= tp.width;
    tp.paint(canvas, Offset(dx, offset.dy));
  }

  @override
  bool shouldRepaint(_RainPainter old) =>
      old.progress != progress || old.hover != hover || old.points != points;
}

// Keep ForecastChart as a convenience alias that renders both stacked
// (used nowhere new — home_screen uses TempChart+RainChart directly)
class ForecastChart extends StatelessWidget {
  final List<HourlyForecastEntry> items;
  const ForecastChart({super.key, required this.items});
  @override
  Widget build(BuildContext context) => Column(children: [
    TempChart(items: items),
    const SizedBox(height: 12),
    RainChart(items: items),
  ]);
}
