import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../constants/app_colors.dart';

/// Glow behind the mascot on the welcome backdrop: a soft white spotlight.
/// Shared with the splash so the two mascots look identical at the hand-off.
final List<Color> welcomeMascotHalo = [
  Colors.white.withValues(alpha: 0.32),
  Colors.white.withValues(alpha: 0.10),
  Colors.white.withValues(alpha: 0),
];

/// The mascot with its lower body melting into the backdrop, the way the
/// welcome title overlaps it. [strength] 0 shows the whole mascot (the
/// splash), 1 the full fade (the welcome screen).
Widget welcomeMascotMask({required Widget child, double strength = 1}) {
  return ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) => LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Colors.white,
        Colors.white,
        Color.lerp(Colors.white, Colors.transparent, strength)!,
      ],
      stops: const [0, 0.58, 0.9],
    ).createShader(rect),
    child: child,
  );
}

/// The welcome backdrop: misty sage on top deepening to emerald, with
/// faint curved bands of light and soft bokeh that drift and twinkle.
class WelcomeBackdropPainter extends CustomPainter {
  /// 0..1, back and forth.
  final double t;

  /// System navigation inset; the colour stops sit above it, with the text.
  final double bottomInset;

  const WelcomeBackdropPainter({required this.t, required this.bottomInset});

  /// Distance of each [AppColors.welcomeBackdrop] colour from the bottom of
  /// the content, in logical pixels. The first colour is the very top.
  static const List<double> _fromBottom = [
    double.infinity, 520, 465, 423, 382, 341, 300, 258, 0,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final rect = Offset.zero & size;

    final stops = [
      for (final d in _fromBottom)
        (1 - (d + bottomInset) / h).clamp(0.0, 1.0),
    ];
    canvas.drawRect(
      rect,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, h),
          AppColors.welcomeBackdrop,
          stops,
        ),
    );

    // Height of the light part, where the bands and bokeh live.
    final light = math.max(h - _fromBottom[1] - bottomInset, h * 0.3);

    void glow(Offset center, double radius, Color color) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = ui.Gradient.radial(
            center,
            radius,
            [color, color.withValues(alpha: 0)],
          ),
      );
    }

    // Paler mint light from the top right.
    glow(Offset(w, light * 0.15), w * 0.9,
        AppColors.welcomeMist.withValues(alpha: 0.65));

    // Curved bands of light, edges catching a little highlight.
    void band(Offset center, double radius, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: alpha * 1.6),
      );
    }

    band(Offset(w * (0.45 + 0.03 * t), -light * 0.55), w * 0.85, 0.07);
    band(Offset(w * (1.18 - 0.03 * t), -light * 0.08), w * 0.8, 0.10);
    band(Offset(-w * (0.30 - 0.03 * t), light * 0.02), w * 0.62, 0.08);

    // Bokeh: soft dots that breathe in brightness and float a little.
    void bokeh(double x, double y, double r, double alpha, double phase) {
      final pulse = 0.5 + 0.5 * math.sin((t + phase) * math.pi * 2);
      glow(
        Offset(w * x, light * y - 6 * pulse),
        r,
        Colors.white.withValues(alpha: alpha * (0.65 + 0.35 * pulse)),
      );
    }

    bokeh(0.13, 0.82, 22, 0.80, 0.0);
    bokeh(0.12, 0.95, 17, 0.75, 0.35);
    bokeh(0.23, 0.79, 9, 0.70, 0.7);
    bokeh(0.26, 0.46, 13, 0.70, 0.2);
    bokeh(0.26, 0.52, 8, 0.60, 0.55);
    bokeh(0.42, 0.28, 9, 0.45, 0.85);
    bokeh(0.84, 0.68, 19, 0.80, 0.45);
    bokeh(0.85, 0.79, 11, 0.95, 0.1);
  }

  @override
  bool shouldRepaint(WelcomeBackdropPainter old) =>
      old.t != t || old.bottomInset != bottomInset;
}
