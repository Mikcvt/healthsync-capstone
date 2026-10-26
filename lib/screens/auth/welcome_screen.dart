import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

import '../../constants/app_colors.dart';
import '../../utils/splash_handoff.dart';
import '../../widgets/shared/floating_mascot.dart';
import '../../widgets/shared/welcome_backdrop.dart';

import 'login_screen.dart';
import 'otp_entry_screen.dart';
import 'role_select_screen.dart';
import '../../widgets/shared/legal_links.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  /// Below this height the mascot gets a fixed size and the page scrolls.
  static const double _compactHeight = 680;

  /// Title, text and buttons rise in one after another.
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  /// Slow drift of the light orbs behind everything.
  late final AnimationController _drift = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 10),
  );

  late final Animation<double> _titleIn = _interval(0.30, 0.70);
  late final Animation<double> _textIn = _interval(0.40, 0.80);
  late final Animation<double> _buttonsIn = _interval(0.52, 0.95);
  late final Animation<double> _footerIn = _interval(0.62, 1.0);

  Animation<double> _interval(double begin, double end) => CurvedAnimation(
        parent: _entrance,
        curve: Interval(begin, end, curve: Curves.easeOutCubic),
      );

  /// Built underneath the start-up splash, which then glides its mascot into
  /// this screen's place: this mascot must not pop in a second time.
  late final bool _arrivedUnderSplash = SplashHandoff.covering.value;

  @override
  void initState() {
    super.initState();
    SplashHandoff.covering.addListener(_onSplashHandoff);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under the splash, wait: the title and buttons rise once the mascot has
    // landed, and the backdrop must match the splash's still one until then.
    if (!SplashHandoff.covering.value) _startAnimations();
  }

  void _onSplashHandoff() {
    if (!SplashHandoff.covering.value && mounted) _startAnimations();
  }

  void _startAnimations() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _entrance.value = 1;
      _drift.stop();
    } else {
      if (_entrance.isDismissed) _entrance.forward();
      if (!_drift.isAnimating) _drift.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    SplashHandoff.covering.removeListener(_onSplashHandoff);
    _entrance.dispose();
    _drift.dispose();
    super.dispose();
  }

  void _push(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  /// The mascot with its lower body melting into the backdrop, the way the
  /// title below overlaps it.
  Widget _mascot(double size) {
    // Measured by the splash as its landing spot, and hidden until it lands.
    return KeyedSubtree(
      key: SplashHandoff.welcomeMascotKey,
      child: ValueListenableBuilder<bool>(
        valueListenable: SplashHandoff.covering,
        builder: (context, covering, child) =>
            Opacity(opacity: covering ? 0 : 1, child: child),
        child: welcomeMascotMask(
          child: FloatingMascot(
            size: size,
            haloColors: welcomeMascotHalo,
            popIn: !_arrivedUnderSplash,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Dark status icons on the light top, light nav icons on the dark
      // bottom.
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: AppColors.welcomeForest,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: AppColors.welcomeForest,
        body: Stack(
          children: [
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _drift,
                  builder: (context, _) => CustomPaint(
                    painter: WelcomeBackdropPainter(
                      t: Curves.easeInOut.transform(_drift.value),
                      bottomInset: bottomInset,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final content = Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _content(),
                  );

                  // Short phone: everything scrolls, nothing is cut off.
                  if (constraints.maxHeight < _compactHeight) {
                    const size = 240.0;
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 8),
                          SizedBox(
                            height: size * 0.78,
                            child: OverflowBox(
                              alignment: Alignment.topCenter,
                              maxHeight: size,
                              child: _mascot(size),
                            ),
                          ),
                          content,
                        ],
                      ),
                    );
                  }

                  // Otherwise the buttons sit at the bottom and the mascot
                  // fills the space above, its faded lower body tucked
                  // behind the title.
                  return Column(
                    children: [
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, area) {
                            final size = math.min(
                              area.maxHeight * 1.22,
                              constraints.maxWidth * 0.86,
                            );
                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  bottom: -size * 0.22,
                                  child: Center(child: _mascot(size)),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      content,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _content() {
    return Column(
      children: [
        _Rise(
          animation: _titleIn,
          child: const Text(
            'HealthSync',
            style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontFamily: 'PlusJakartaSans',
              letterSpacing: -1.2,
              height: 1.1,
              shadows: [
                Shadow(
                  color: Color(0x40000000),
                  blurRadius: 24,
                  offset: Offset(0, 6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        _Rise(
          animation: _textIn,
          child: Column(
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'PlusJakartaSans',
                    height: 1.25,
                  ),
                  // "Never miss a dose again" was a promise no reminder app
                  // can keep, and Play reviews medical-sounding claims.
                  children: [
                    TextSpan(text: 'Stay on top of '),
                    TextSpan(
                      text: 'every dose.',
                      style: TextStyle(color: AppColors.welcomeMint),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // The box is optional: the old line ("Smart LED visual
              // guidance") read as if it were required.
              Text(
                'Medicine reminders and missed-dose alerts for you and your care partner.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withValues(alpha: 0.78),
                  fontFamily: 'PlusJakartaSans',
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 14,
                      color: AppColors.welcomeMint,
                    ),
                    const SizedBox(width: 6),
                    // Flexible so the line wraps at a large font size instead
                    // of running off the screen (BUG-026).
                    Flexible(
                      child: Text(
                        'Works with the optional HealthSync medicine box',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.85),
                          fontFamily: 'PlusJakartaSans',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        _Rise(
          animation: _buttonsIn,
          child: Column(
            children: [
              // Get Started: the bright pill, like the reference "Continue"
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _push(const RoleSelectScreen()),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      elevation: 0,
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'Get Started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'PlusJakartaSans',
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Managed patients never sign up — they arrive with a code
              // from their caregiver, so this is their whole entry point.
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: () => _push(const OtpEntryScreen()),
                  icon: const Icon(Icons.key_rounded, size: 20),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.6),
                      width: 1.2,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  label: const Text(
                    'I have a code',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _Rise(
          animation: _footerIn,
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Already have an account?',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.78),
                      fontFamily: 'PlusJakartaSans',
                    ),
                  ),
                  TextButton(
                    onPressed: () => _push(const LoginScreen()),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                    ),
                    child: const Text(
                      'Log In',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'PlusJakartaSans',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.62),
                    fontFamily: 'PlusJakartaSans',
                  ),
                  children: [
                    const TextSpan(text: 'By continuing, you agree to our '),
                    _link('Terms', () => openLegalPage(context, privacy: false)),
                    const TextSpan(text: ' & '),
                    _link('Privacy', () => openLegalPage(context, privacy: true)),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }
}

/// An underlined footer link.
TextSpan _link(String text, VoidCallback onTap) {
  return TextSpan(
    text: text,
    style: const TextStyle(
      decoration: TextDecoration.underline,
      decorationColor: Color(0xB3FFFFFF),
    ),
    recognizer: TapGestureRecognizer()..onTap = onTap,
  );
}

/// Fades a child in while lifting it a few pixels into place.
class _Rise extends StatelessWidget {
  final Animation<double> animation;
  final Widget child;

  const _Rise({required this.animation, required this.child});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) => Opacity(
        opacity: animation.value.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - animation.value)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
