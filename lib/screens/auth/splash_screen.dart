import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:provider/provider.dart';

import '../../constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../utils/splash_handoff.dart';
import '../../widgets/shared/floating_mascot.dart';
import '../../widgets/shared/welcome_backdrop.dart';

/// The start-up splash. It covers the first screen while the sign-in and
/// profile load, then hands over to it:
///
///  * to the welcome screen, its mascot glides into the welcome mascot's exact
///    spot on the same backdrop, and the welcome title and buttons rise in;
///  * to anything else (a dashboard), the mascot zooms toward the viewer and
///    the splash fades away.
///
/// The first screen is built underneath from the moment it is known, so its
/// data loads during the animation, not after it. The splash runs once per
/// app launch; later loading (after signing in) does not bring it back.
///
/// It replaced a plain spinner that switched abruptly to the next screen.
class StartupSplash extends StatefulWidget {
  /// Whether [child] is the real first screen yet.
  final bool ready;

  /// Whether [child] is the welcome screen, which decides the hand-off.
  final bool toWelcome;

  final Widget child;

  const StartupSplash({
    super.key,
    required this.ready,
    required this.toWelcome,
    required this.child,
  });

  @override
  State<StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<StartupSplash>
    with TickerProviderStateMixin {
  /// Long enough to see the mascot, never longer than loading takes after it.
  static const _minShown = Duration(milliseconds: 1300);

  /// Share of the exit spent gliding; the rest cross-fades the two mascots.
  static const _glideEnd = 0.8;

  /// After this long without loading, say so and offer Try again.
  static const _slowAfter = Duration(seconds: 8);

  /// Set by [_minTimer]. A `late final _shownAt = DateTime.now()` used to stand
  /// here, but a late initializer runs on first read, not at start-up: when the
  /// profile loaded quickly (a signed-in patient, from cache) the clock started
  /// at that first exit attempt, the timer's own check then came too early, and
  /// nothing asked again — the splash stayed up forever.
  bool _minElapsed = false;
  Timer? _minTimer;
  Timer? _slowTimer;

  /// Loading has taken longer than [_slowAfter]: usually no or a poor
  /// connection on a phone with nothing cached yet. Without a message the
  /// splash looked frozen.
  bool _slow = false;

  /// Mascot height in the system splash image (720 px at 4 px per dp; see
  /// tool/render_splash_mascot_test.dart). The first frame matches it.
  static const _nativeMascotDp = 180.0;

  /// Eases from the system splash picture (flat colour, smaller mascot, no
  /// glow) into the full splash, so Android's splash and this one read as one.
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  late final AnimationController _exit = AnimationController(vsync: this);
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// The content keeps one place in the tree for the app's whole life, so it
  /// is never rebuilt from scratch when the splash goes away.
  final _contentKey = GlobalKey(debugLabel: 'startupContent');

  /// Keeps the mascot's state (its float and blink) while it moves from the
  /// centred layout to the gliding one.
  final _mascotKey = GlobalKey(debugLabel: 'splashMascot');

  bool _exiting = false;
  bool _done = false;
  Rect? _from;
  Rect? _to;

  @override
  void initState() {
    super.initState();
    // Before the first screen is built, so the welcome screen sees it.
    SplashHandoff.covering.value = true;
    _minTimer = Timer(_minShown, () {
      _minElapsed = true;
      _maybeExit();
    });
    _startSlowTimer();
    _exit.addListener(_onExitTick);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _intro.value = 1;
      return;
    }
    if (_intro.isDismissed) _intro.forward();
    if (!_pulse.isAnimating) _pulse.repeat();
  }

  @override
  void didUpdateWidget(StartupSplash oldWidget) {
    super.didUpdateWidget(oldWidget);
    _maybeExit();
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _slowTimer?.cancel();
    _intro.dispose();
    _exit.dispose();
    _pulse.dispose();
    SplashHandoff.covering.value = false;
    super.dispose();
  }

  void _startSlowTimer() {
    _slowTimer?.cancel();
    _slowTimer = Timer(_slowAfter, () {
      if (mounted && !widget.ready && !_exiting) setState(() => _slow = true);
    });
  }

  /// Asks for the profile again, e.g. after the user turned their internet
  /// back on.
  void _retry() {
    setState(() => _slow = false);
    _startSlowTimer();
    context.read<AuthProvider>().retryProfileLoad();
  }

  void _maybeExit() {
    if (_exiting || _done || !mounted || !widget.ready || !_minElapsed) return;
    _exiting = true;
    _slowTimer?.cancel();
    // One frame so the first screen underneath is laid out and measurable.
    // scheduleFrame() makes sure that frame comes: with animations turned
    // off nothing else asks for one, and the splash used to wait forever.
    WidgetsBinding.instance.addPostFrameCallback((_) => _startExit());
    WidgetsBinding.instance.scheduleFrame();
  }

  void _startExit() {
    if (!mounted) return;
    final still = MediaQuery.disableAnimationsOf(context);
    if (widget.toWelcome && !still) {
      _from = _rectOf(_mascotKey);
      _to = _rectOf(SplashHandoff.welcomeMascotKey);
    }
    _exit.duration = Duration(
      milliseconds: still ? 250 : (_gliding ? 900 : 650),
    );
    _pulse.stop();
    setState(() {});
    _exit.forward().whenComplete(() {
      SplashHandoff.covering.value = false;
      if (mounted) setState(() => _done = true);
    });
  }

  bool get _gliding => _from != null && _to != null;

  /// Lets the welcome mascot appear for the cross-fade at the end of a glide.
  void _onExitTick() {
    if (_gliding && _exit.value >= _glideEnd && SplashHandoff.covering.value) {
      SplashHandoff.covering.value = false;
    }
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        KeyedSubtree(key: _contentKey, child: widget.child),
        if (!_done) _splashLayer(context),
      ],
    );
  }

  Widget _splashLayer(BuildContext context) {
    final media = MediaQuery.of(context);
    final fullSize = math.min(media.size.width * 0.58, 240.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.welcomeForest,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _exit, _pulse]),
        builder: (context, _) {
          final intro = Curves.easeInOutCubic.transform(_intro.value);
          final size = _nativeMascotDp + (fullSize - _nativeMascotDp) * intro;
          final mascot = FloatingMascot(
            key: _mascotKey,
            size: size,
            // Already on screen in the system splash: no pop-in.
            popIn: false,
            haloColors: [
              for (final c in welcomeMascotHalo)
                c.withValues(alpha: c.a * intro),
            ],
          );

          final t = _exit.value;
          final Widget body;
          final double opacity;

          if (_gliding) {
            // Glide into the welcome mascot's spot, taking on its faded
            // lower body as it lands, then cross-fade with it.
            final g = Curves.easeInOutCubic.transform(
              (t / _glideEnd).clamp(0.0, 1.0),
            );
            body = Positioned.fromRect(
              rect: Rect.lerp(_from, _to, g)!,
              child: FittedBox(
                child: welcomeMascotMask(strength: g, child: mascot),
              ),
            );
            opacity = t < _glideEnd
                ? 1
                : 1 - (t - _glideEnd) / (1 - _glideEnd);
          } else {
            // Waiting, or zooming out toward the viewer. Centred exactly, like
            // the system splash; the loading ring sits below without moving it.
            final zoom = _exiting ? Curves.easeInCubic.transform(t) : 0.0;
            final center = media.size.center(Offset.zero);
            body = Stack(
              fit: StackFit.expand,
              children: [
                Center(
                  child: Transform.scale(scale: 1 + 1.6 * zoom, child: mascot),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: center.dy + size / 2 + 14,
                  child: Center(
                    child: Opacity(
                      opacity: _exiting ? 0 : intro,
                      child: _LoadingPulse(progress: _pulse.value),
                    ),
                  ),
                ),
                if (_slow && !_exiting)
                  Positioned(
                    left: 32,
                    right: 32,
                    top: center.dy + size / 2 + 48,
                    child: _SlowNotice(onRetry: _retry),
                  ),
              ],
            );
            opacity = _exiting
                ? 1 - Curves.easeIn.transform(((t - 0.25) / 0.75).clamp(0, 1))
                : 1;
          }

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The system splash's flat colour, giving way to the welcome
                // screen's own backdrop (standing still), so the splash and
                // the welcome screen are one continuous picture.
                ColoredBox(color: AppColors.welcomeBackdrop[2]),
                Opacity(
                  opacity: intro,
                  child: CustomPaint(
                    painter: WelcomeBackdropPainter(
                      t: 0,
                      bottomInset: media.padding.bottom,
                    ),
                  ),
                ),
                body,
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Shown under the mascot when loading takes too long.
class _SlowNotice extends StatelessWidget {
  final VoidCallback onRetry;

  const _SlowNotice({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Taking longer than usual.\nCheck your internet connection.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.45,
            fontWeight: FontWeight.w600,
            shadows: [Shadow(color: Color(0x66000000), blurRadius: 8)],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: const Text(
            'Try again',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// The loading cue under the mascot: a soft ring that widens and fades, over
/// and over. Quieter than a spinner, and in the mascot's colours.
class _LoadingPulse extends StatelessWidget {
  /// 0..1, repeating.
  final double progress;

  const _LoadingPulse({required this.progress});

  @override
  Widget build(BuildContext context) {
    final eased = Curves.easeOut.transform(progress);
    return SizedBox(
      width: 64,
      height: 18,
      child: Center(
        child: Transform.scale(
          scale: 0.4 + 0.6 * eased,
          child: Container(
            width: 64,
            height: 18,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.7 * (1 - eased)),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
