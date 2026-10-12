// Renders the system splash image: the full mascot, centred, on a transparent
// 1152 × 1152 canvas. Run after changing the mascot drawing:
//
//   flutter test tool/render_splash_mascot_test.dart
//   dart run flutter_native_splash:create
//
// Kept outside test/ so the normal `flutter test` run does not rewrite assets.
//
// Why generated: Android 12+ masks the system splash icon to a circle, and the
// logo (the mascot peeking in from a corner) came out cut off with a white
// crescent. Drawing it with MascotPainter also makes it identical to the
// animated splash that takes over, so there is no jump between the two.

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:healthsync/widgets/shared/floating_mascot.dart';

/// Android's splash icon box (no icon background): 288 dp. The image is
/// treated as xxxhdpi (4 px per dp), so 1152 px.
const double canvasPx = 1152;

/// Mascot height in px; 4 px per dp makes it [splashMascotDp] tall. Small
/// enough to sit inside the 192 dp circle Android keeps visible.
const double mascotPx = 720;

void main() {
  testWidgets('render splash mascot', (tester) async {
    await tester.runAsync(() async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const height = mascotPx;
      const width = height * MascotPainter.aspectRatio;
      canvas.translate((canvasPx - width) / 2, (canvasPx - height) / 2);
      const MascotPainter(
        // No glow: the animated splash fades its own in.
        haloColors: [Color(0x00000000), Color(0x00000000), Color(0x00000000)],
      ).paint(canvas, const Size(width, height));

      final image = await recorder
          .endRecording()
          .toImage(canvasPx.toInt(), canvasPx.toInt());
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      File('assets/branding/splash_mascot.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
    });
  });
}
