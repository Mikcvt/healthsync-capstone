import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'welcome_screen.dart';

/// HealthSync Splash Screen
///
/// Displays the HealthSync logo and brand wordmark centered on a plain white
/// background with a refined, staggered entrance animation.
///
/// Animation sequence:
/// 1. Logo fades in and gently scales up.
/// 2. Wordmark appears smoothly beneath the logo.
/// 3. Holds briefly, then automatically navigates to the WelcomeScreen
///    within 3 seconds (2.5 s display + smooth fade transition).
class SplashScreen extends StatefulWidget {
  final Widget? nextScreen;
  const SplashScreen({super.key, this.nextScreen});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoFadeAnimation;
  late final Animation<double> _logoScaleAnimation;
  late final Animation<double> _wordmarkFadeAnimation;
  late final Animation<double> _wordmarkScaleAnimation;

  Timer? _navigationTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    // Staggered entrance animation for logo and wordmark (1200 ms total)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // 1. Logo entrance (0% - 65% of controller: ~0ms to 780ms)
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
      ),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Wordmark entrance (20% - 85% of controller: ~240ms to 1020ms)
    _wordmarkFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.85, curve: Curves.easeOut),
      ),
    );

    _wordmarkScaleAnimation = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.20, 0.85, curve: Curves.easeOutCubic),
      ),
    );

    _controller.forward();

    // Auto-navigate to WelcomeScreen after 2.5 seconds (under 3.0s total)
    _navigationTimer = Timer(const Duration(milliseconds: 2500), _goToWelcome);
  }

  void _goToWelcome() {
    if (!mounted || _navigated) return;
    _navigated = true;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            widget.nextScreen ?? const WelcomeScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // Responsive dimensions clamped to avoid distortion on tablets/small phones
    final logoWidth = (size.width * 0.38).clamp(130.0, 170.0);
    final wordmarkWidth = (size.width * 0.48).clamp(180.0, 240.0);
    final bottomPadding = (size.height * 0.045).clamp(24.0, 44.0);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: GestureDetector(
          onTap: _goToWelcome,
          behavior: HitTestBehavior.opaque,
          child: SafeArea(
            child: Stack(
              children: [
                // 1. Primary HealthSync Logo centered on the screen
                Center(
                  child: FadeTransition(
                    opacity: _logoFadeAnimation,
                    child: ScaleTransition(
                      scale: _logoScaleAnimation,
                      child: Image.asset(
                        'assets/images/healthsync_logo.png',
                        width: logoWidth,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('HealthSync logo load error: $error');
                          return const Icon(
                            Icons.favorite_rounded,
                            size: 100,
                            color: Color(0xFF2BB5A0),
                          );
                        },
                      ),
                    ),
                  ),
                ),

                // 2. HealthSync Brand Wordmark placed at center bottom
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: bottomPadding),
                    child: FadeTransition(
                      opacity: _wordmarkFadeAnimation,
                      child: ScaleTransition(
                        scale: _wordmarkScaleAnimation,
                        child: Image.asset(
                          'assets/images/healthsync_wordmark.png',
                          width: wordmarkWidth,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint('HealthSync wordmark load error: $error');
                            return const Text(
                              'HealthSync',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2BB5A0),
                                fontFamily: 'PlusJakartaSans',
                                letterSpacing: -0.5,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}