import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// The HealthSync mascot, alive: it pops in and waves hello, then floats,
/// breathes, blinks, and its heart beats. Tapping it makes it wave again, and
/// it waves on its own every few seconds.
///
/// Drawn in code (see [MascotPainter]) rather than shipped as an image, so the
/// eyes, arm and heart can move independently and it stays sharp at any size.
/// Purely decorative, so it is hidden from screen readers.
///
/// Honours the system "remove animations" setting: the mascot then stands
/// still, eyes open.
class FloatingMascot extends StatefulWidget {
  /// Height of the figure, ground shadow included. The width follows from
  /// [MascotPainter.aspectRatio]; the halo and waving arm may paint past it.
  final double size;

  /// Colours of the glow behind the mascot, centre outward. Defaults to a
  /// pale green-blue that suits a white page; pass soft whites on a dark one.
  final List<Color>? haloColors;

  /// Pop in and wave on first appearance. False when the mascot takes over
  /// from the splash screen's mascot, which has already made its entrance.
  final bool popIn;

  const FloatingMascot({
    super.key,
    this.size = 220,
    this.haloColors,
    this.popIn = true,
  });

  @override
  State<FloatingMascot> createState() => _FloatingMascotState();
}

class _FloatingMascotState extends State<FloatingMascot>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  /// Float up and down, breathing with it.
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  /// One loop holds the blinks; each time it wraps, the mascot waves.
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..addListener(_onLifeTick);

  late final AnimationController _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _entrance, curve: Curves.easeOut);
  late final Animation<double> _popIn = Tween<double>(begin: 0.6, end: 1)
      .animate(CurvedAnimation(parent: _entrance, curve: Curves.easeOutBack));

  bool _still = false;
  double _lastLife = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      for (final c in [_idle, _life, _heart, _wave]) {
        c.stop();
        c.value = 0;
      }
      _entrance.value = 1;
      return;
    }
    if (!_idle.isAnimating) _idle.repeat(reverse: true);
    if (!_life.isAnimating) _life.repeat();
    if (!_heart.isAnimating) _heart.repeat();
    if (!widget.popIn && _entrance.isDismissed) _entrance.value = 1;
    if (_entrance.isDismissed) {
      _entrance.forward().then((_) => _waveHello());
    }
  }

  void _onLifeTick() {
    if (_life.value < _lastLife) _waveHello();
    _lastLife = _life.value;
  }

  void _waveHello() {
    if (!mounted || _still || _wave.isAnimating) return;
    _wave.forward(from: 0);
  }

  @override
  void dispose() {
    _entrance.dispose();
    _idle.dispose();
    _life.dispose();
    _heart.dispose();
    _wave.dispose();
    super.dispose();
  }

  /// Eye openness, 1 = open: a blink, then later a quick double blink.
  static double _blinkAt(double v) {
    double closed(double at) {
      final d = (v - at).abs();
      return d < 0.008 ? 1 - d / 0.008 : 0;
    }

    return 1 - [closed(0.30), closed(0.70), closed(0.74)].reduce(math.max);
  }

  /// A lub-dub: a strong beat, then a softer one.
  static double _beatAt(double v) {
    double bump(double at, double width) {
      final d = (v - at).abs();
      if (d >= width) return 0;
      final c = math.cos(d / width * math.pi / 2);
      return c * c;
    }

    return math.max(bump(0.08, 0.07), 0.6 * bump(0.26, 0.07));
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: GestureDetector(
        onTap: _waveHello,
        child: FadeTransition(
          opacity: _fadeIn,
          child: ScaleTransition(
            scale: _popIn,
            child: AnimatedBuilder(
              animation: Listenable.merge([_idle, _life, _heart, _wave]),
              builder: (context, _) => CustomPaint(
                size: Size(
                  widget.size * MascotPainter.aspectRatio,
                  widget.size,
                ),
                painter: MascotPainter(
                  float: Curves.easeInOut.transform(_idle.value),
                  blink: _blinkAt(_life.value),
                  heartbeat: _beatAt(_heart.value),
                  wave: _wave.value,
                  haloColors: widget.haloColors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the mascot in a fixed design space (traced from the original
/// 1078 × 1078 artwork), scaled to the canvas height.
class MascotPainter extends CustomPainter {
  /// 0 = resting on the ground, 1 = top of the float.
  final double float;

  /// Eye openness: 1 = open, 0 = shut.
  final double blink;

  /// Heart pulse, 0 = rest, 1 = full beat.
  final double heartbeat;

  /// Progress through one wave of the right arm; 0 (or 1) = arm at rest.
  final double wave;

  /// See [FloatingMascot.haloColors].
  final List<Color>? haloColors;

  const MascotPainter({
    this.float = 0,
    this.blink = 1,
    this.heartbeat = 0,
    this.wave = 0,
    this.haloColors,
  });

  // Visible window of the design space.
  static const double _viewLeft = 135;
  static const double _viewTop = 100;
  static const double _viewWidth = 800;
  static const double _viewHeight = 900;
  static const double aspectRatio = _viewWidth / _viewHeight;

  static const double _centerX = 535;
  static const double _groundY = 962;

  // Illustration palette, sampled from the original artwork.
  static const Color _ink = Color(0xFF3A736D);
  static const Color _blush = Color(0xFF86CD8F);
  static const Color _armTop = Color(0xFF68B095);
  static const Color _armEnd = Color(0xFF73B798);
  static const Color _legTop = Color(0xFF4F9B90);
  static const Color _legEnd = Color(0xFF6BAB90);
  static const List<Color> _bodyColors = [
    Color(0xFF99C9B1),
    Color(0xFF93C7AC),
    Color(0xFF7CC098),
    Color(0xFF70B895),
    Color(0xFF6CB395),
    Color(0xFF5EA894),
    Color(0xFF4F9A90),
  ];
  static const List<double> _bodyStops = [0, .22, .38, .56, .66, .85, 1];

  static double _mirror(double x) => 2 * _centerX - x;

  static List<double> _evenStops(int n) =>
      [for (var i = 0; i < n; i++) i / (n - 1)];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.height / _viewHeight);
    canvas.translate(-_viewLeft, -_viewTop);

    _paintHalo(canvas);
    _paintShadow(canvas);

    // Rise, stretching a little as it goes, about the feet.
    canvas.save();
    canvas.translate(0, -48 * float);
    canvas.translate(_centerX, _groundY);
    canvas.scale(1 - 0.012 * float, 1 + 0.018 * float);
    canvas.translate(-_centerX, -_groundY);

    _paintLegs(canvas);
    _paintArm(canvas, left: true, angle: 0);
    _paintArm(canvas, left: false, angle: -_waveAngle);
    _paintBody(canvas);
    _paintFace(canvas);
    _paintHeart(canvas);
    _paintShine(canvas);

    canvas.restore();
    canvas.restore();
  }

  /// Arm lifts outward, shakes three times, and comes back down.
  double get _waveAngle {
    if (wave <= 0 || wave >= 1) return 0;
    final lift = math.sin(wave * math.pi);
    final shake = math.sin(wave * math.pi * 6);
    return lift * (0.95 + 0.22 * shake);
  }

  /// How excited the face looks: peaks mid-wave.
  double get _excited =>
      (wave <= 0 || wave >= 1) ? 0 : math.sin(wave * math.pi);

  void _paintHalo(Canvas canvas) {
    const center = Offset(_centerX, 540);
    final radius = 470 * (1 + 0.03 * float);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          haloColors ??
              [
                AppColors.greenLight,
                AppColors.blueLight.withValues(alpha: 0.7),
                AppColors.blueLight.withValues(alpha: 0),
              ],
          _evenStops(haloColors?.length ?? 3),
        ),
    );
  }

  void _paintShadow(Canvas canvas) {
    final shrink = 1 - 0.25 * float;
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(_centerX, 978),
        width: 330 * shrink,
        height: 44 * shrink,
      ),
      Paint()
        ..color = AppColors.textPrimary.withValues(alpha: 0.13 - 0.05 * float)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
  }

  void _paintLegs(Canvas canvas) {
    final paint = Paint()
      ..shader = ui.Gradient.linear(
        const Offset(0, 880),
        const Offset(0, _groundY),
        const [_legTop, _legEnd],
      );
    for (final cx in [449.0, _mirror(449)]) {
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - 51, 820, cx + 51, _groundY),
          bottomLeft: const Radius.circular(51),
          bottomRight: const Radius.circular(51),
        ),
        paint,
      );
    }
  }

  void _paintArm(Canvas canvas, {required bool left, required double angle}) {
    double x(double v) => left ? v : _mirror(v);
    final shoulder = Offset(x(300), 560);
    final path = Path()
      ..moveTo(x(300), 545)
      ..quadraticBezierTo(x(238), 625, x(228), 766);

    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(angle);
    canvas.translate(-shoulder.dx, -shoulder.dy);
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 72
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          const Offset(0, 560),
          const Offset(0, 800),
          const [_armTop, _armEnd],
        ),
    );
    canvas.restore();
  }

  void _paintBody(Canvas canvas) {
    const rect = Rect.fromLTRB(282, 134, 788, 897);
    final body = RRect.fromRectAndRadius(rect, const Radius.circular(253));
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(0, 134),
          const Offset(0, 897),
          _bodyColors,
          _bodyStops,
        ),
    );

    // Light from the upper left and a little shade down the right side give
    // the flat capsule some volume.
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(430, 330),
          420,
          [
            Colors.white.withValues(alpha: 0.22),
            Colors.white.withValues(alpha: 0),
          ],
        ),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(640, 0),
          const Offset(788, 0),
          [
            AppColors.textPrimary.withValues(alpha: 0),
            AppColors.textPrimary.withValues(alpha: 0.08),
          ],
        ),
    );
    canvas.restore();
  }

  void _paintFace(Canvas canvas) {
    final excited = _excited;
    final stroke = Paint()
      ..color = _ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeCap = StrokeCap.round;

    // Brows: gentle arches that lift while it waves.
    final browLift = -10 * excited;
    for (final left in [true, false]) {
      double x(double v) => left ? v : _mirror(v);
      canvas.drawPath(
        Path()
          ..moveTo(x(424), 354 + browLift)
          ..quadraticBezierTo(x(452), 334 + browLift, x(482), 348 + browLift),
        stroke,
      );
    }

    // Eyes, with a catchlight while open.
    final open = blink.clamp(0.08, 1.0);
    final eyePaint = Paint()..color = _ink;
    final glint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final cx in [461.0, _mirror(461)]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(cx, 416),
          width: 52,
          height: 52 * open,
        ),
        eyePaint,
      );
      if (open > 0.6) canvas.drawCircle(Offset(cx + 9, 405), 7.5, glint);
    }

    // Cheeks.
    final blush = Paint()..color = _blush;
    for (final cx in [417.0, _mirror(417)]) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx, 470), width: 66, height: 38),
        blush,
      );
    }

    // Smile, wider while it waves.
    final half = 46 + 8 * excited;
    final depth = 36 + 14 * excited;
    canvas.drawPath(
      Path()
        ..moveTo(_centerX - half, 492)
        ..quadraticBezierTo(_centerX, 492 + depth, _centerX + half, 492),
      stroke,
    );
  }

  void _paintHeart(Canvas canvas) {
    final w = 118 * (1 + 0.1 * heartbeat);
    canvas.save();
    canvas.translate(_centerX, 718);
    canvas.scale(w);
    final heart = Path()
      ..moveTo(0, 0.42)
      ..cubicTo(-0.12, 0.30, -0.5, 0.02, -0.5, -0.18)
      ..cubicTo(-0.5, -0.38, -0.35, -0.48, -0.24, -0.48)
      ..cubicTo(-0.10, -0.48, -0.02, -0.38, 0, -0.30)
      ..cubicTo(0.02, -0.38, 0.10, -0.48, 0.24, -0.48)
      ..cubicTo(0.35, -0.48, 0.5, -0.38, 0.5, -0.18)
      ..cubicTo(0.5, 0.02, 0.12, 0.30, 0, 0.42)
      ..close();
    canvas.drawPath(heart, Paint()..color = _blush);
    // Same colour, round joins: softens the point like the original.
    canvas.drawPath(
      heart,
      Paint()
        ..color = _blush
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.07
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  void _paintShine(Canvas canvas) {
    // A glossy streak following the curve of the head, plus a dot.
    const head = Offset(_centerX, 387);
    canvas.drawArc(
      Rect.fromCircle(center: head, radius: 225),
      -161.7 * math.pi / 180,
      35.4 * math.pi / 180,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 26
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          const Offset(320, 316),
          const Offset(402, 206),
          [
            Colors.white.withValues(alpha: 0.55),
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
    );
    canvas.drawCircle(
      const Offset(442, 186),
      13,
      Paint()..color = Colors.white.withValues(alpha: 0.95),
    );
  }

  @override
  bool shouldRepaint(MascotPainter old) =>
      old.float != float ||
      old.blink != blink ||
      old.heartbeat != heartbeat ||
      old.wave != wave ||
      old.haloColors != haloColors;
}
