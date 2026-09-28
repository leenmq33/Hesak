import 'package:flutter/material.dart';

import 'dart:async';
import 'dart:math' as math;

import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_text_styles.dart';
import 'auth/auth_flow_screen.dart';

/// The first screen the user sees when the app opens.
/// Colors and text styles come from lib/core/theme.
/// Shows the animated logo, then the tagline. Then the two corner shapes
/// grow until they cover the screen with the purple of the sign in / sign up
/// screen, and the welcome screen opens on top of the same purple.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// TickerProviderStateMixin (not Single...) because we have three animation controllers.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // --- Sound wave animation ---
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  // --- Tagline animation ---
  late AnimationController _taglineController;
  late Animation<double>
  _taglineOpacity; // Fades the text from invisible to visible
  late Animation<Offset>
  _taglineSlide; // Moves the text slightly upward while it appears

  // --- Reveal animation (corner shapes grow and turn purple) ---
  late AnimationController _revealController;
  late Animation<double> _shapesGrow; // 0 = normal size, 1 = covers the screen
  late Animation<double> _purpleFill; // Final purple gradient fading in on top

  // Timers are stored so we can cancel them if the screen closes early.
  Timer? _taglineTimer;
  Timer? _revealTimer;

  @override
  void initState() {
    super.initState();

    // One full wave movement takes 700ms.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // The waves stretch vertically between 82% and 108% of their size.
    _waveAnimation = Tween<double>(begin: 0.82, end: 1.08).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut, // Smooth start and end of each movement
      ),
    );

    // Play forward, then backward, forever (like a pulsing sound wave).
    _controller.repeat(reverse: true);

    // The tagline takes 1.4 seconds to fully appear.
    _taglineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    // Opacity goes from 0 (transparent) to 1 (fully visible).
    _taglineOpacity = CurvedAnimation(
      parent: _taglineController,
      curve: Curves.easeIn,
    );

    // Starts slightly below its final position, then slides up into place.
    _taglineSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _taglineController, curve: Curves.easeOut),
        );

    // The whole reveal takes 1.3 seconds.
    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );

    // Shapes grow during the first ~75% of the reveal (slow start and end).
    _shapesGrow = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.0, 0.75, curve: Curves.easeInOutCubic),
    );

    // The final purple gradient fades in at the end, so it matches the
    // sign in / sign up background exactly.
    _purpleFill = CurvedAnimation(
      parent: _revealController,
      curve: const Interval(0.65, 1.0, curve: Curves.easeOut),
    );

    // When the reveal is done, open the welcome screen.
    _revealController.addStatusListener((status) {
      if (status == AnimationStatus.completed) _openWelcomeScreen();
    });

    // Wait 1.5 seconds after the logo appears, then show the tagline.
    _taglineTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _taglineController.forward();
    });

    // After 3.8 seconds, start the reveal (it ends at ~5.1 seconds).
    _revealTimer = Timer(const Duration(milliseconds: 3800), _startReveal);
  }

  /// Grows the corner shapes. If the phone has "reduce motion" turned on,
  /// skips the growing and just fades into the welcome screen.
  void _startReveal() {
    if (!mounted) return;
    final bool isReduceMotionOn = MediaQuery.of(context).disableAnimations;
    if (isReduceMotionOn) {
      _openWelcomeScreen(fadeDuration: const Duration(milliseconds: 600));
    } else {
      _revealController.forward();
    }
  }

  /// Replaces the splash with the welcome screen (sign in / sign up).
  /// The splash already ends on the same purple, so a very short fade is
  /// enough and it looks like one screen.
  /// (pushReplacement means the user can't go back to the splash).
  void _openWelcomeScreen({
    Duration fadeDuration = const Duration(milliseconds: 250),
  }) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: fadeDuration,
        pageBuilder: (_, __, ___) => const HesakAuthFlowScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    // Clean up timers and controllers to avoid memory leaks and errors.
    _taglineTimer?.cancel();
    _revealTimer?.cancel();
    _controller.dispose();
    _taglineController.dispose();
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Used to size the logo relative to the screen width.
    final Size screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;

    // How much each shape must grow to cover the whole screen from its corner.
    // 1.35 = extra margin so the rounded edge also passes the far corner.
    final double topShapeMaxScale = math.max(
          (screenSize.width + 80) / 350,
          (screenSize.height + 90) / 220,
        ) *
        1.35;
    final double bottomShapeMaxScale = math.max(
          (screenSize.width + 100) / 420,
          (screenSize.height + 100) / 260,
        ) *
        1.35;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Soft light gradient background (top-left -> bottom-right).
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: HesakColors.splashGradient,
          ),
        ),

        // Stack lets us place decorative shapes behind the logo.
        child: AnimatedBuilder(
          animation: _revealController,
          // The logo + tagline are built once and passed in as child,
          // so they don't rebuild every frame of the reveal.
          child: _buildLogoAndTagline(screenWidth),
          builder: (context, logoAndTagline) {
            final double grow = _shapesGrow.value;
            return Stack(
              children: [
                // Decorative curved shape in the top-left corner.
                // Grows from its corner and turns into the light auth purple.
                Positioned(
                  top: -90,
                  left: -80,
                  child: Transform.scale(
                    scale: 1 + (topShapeMaxScale - 1) * grow,
                    alignment: Alignment.topLeft,
                    child: Container(
                      width: 350,
                      height: 220,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          HesakColors.splashShapeTop.withOpacity(0.18),
                          HesakColors.authGradientLight,
                          grow,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomRight: Radius.circular(220),
                        ),
                      ),
                    ),
                  ),
                ),

                // Decorative curved shape in the bottom-right corner.
                // Grows from its corner and turns into the dark auth purple.
                Positioned(
                  bottom: -100,
                  right: -100,
                  child: Transform.scale(
                    scale: 1 + (bottomShapeMaxScale - 1) * grow,
                    alignment: Alignment.bottomRight,
                    child: Container(
                      width: 420,
                      height: 260,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          HesakColors.splashShapeBottom.withOpacity(0.20),
                          HesakColors.authGradientDark,
                          grow,
                        ),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(250),
                        ),
                      ),
                    ),
                  ),
                ),

                // Final purple (same as the sign in / sign up background),
                // fading in at the end so the handover is seamless.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _purpleFill.value,
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              HesakColors.authGradientLight,
                              HesakColors.authGradientDark,
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Logo and tagline stay still on top of everything.
                logoAndTagline!,
              ],
            );
          },
        ),
      ),
    );
  }

  /// Main content: logo on top, tagline below it.
  Widget _buildLogoAndTagline(double screenWidth) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min, // Only take the height we need
        children: [
          // ---------- Logo (ear + waves + end shape) ----------
          SizedBox(
            width: screenWidth * 0.72, // Logo takes 72% of screen width
            child: Row(
              // The logo is always ear -> waves -> end (left to right),
              // even though the app is Arabic (right-to-left).
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ear image (27% of the logo width).
                Flexible(
                  flex: 27,
                  child: Transform.translate(
                    offset: const Offset(
                      18,
                      -6,
                    ), // Nudge to connect with the waves
                    child: Image.asset(
                      'assets/images/logo/splash_ear.png',
                      width: 105,
                    ),
                  ),
                ),

                // Animated sound waves (46% of the logo width).
                Flexible(
                  flex: 46,
                  child: AnimatedBuilder(
                    animation: _waveAnimation,
                    // Rebuilds every frame to stretch the waves vertically.
                    builder: (context, child) {
                      return Transform.scale(
                        scaleX: 1.0, // Width stays the same
                        scaleY: _waveAnimation.value, // Height pulses
                        alignment: Alignment.center,
                        child: child,
                      );
                    },
                    // Passed as child so the image isn't rebuilt every frame.
                    child: Image.asset(
                      'assets/images/logo/splash_waves.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // End shape of the logo (27% of the logo width).
                Flexible(
                  flex: 27,
                  child: Transform.translate(
                    offset: const Offset(
                      -8,
                      0,
                    ), // Nudge left to close the gap
                    child: Image.asset(
                      'assets/images/logo/splash_end.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Space between the logo and the tagline.
          const SizedBox(height: 28),

          // ---------- Tagline ----------
          // Slides up and fades in together.
          SlideTransition(
            position: _taglineSlide,
            child: FadeTransition(
              opacity: _taglineOpacity,
              child: SizedBox(
                width: screenWidth * 0.8,
                child: const Text(
                  'لأن ما لا يُسمع يَستحق أن يُدرك',
                  textAlign: TextAlign.center,
                  textDirection:
                      TextDirection.rtl, // Arabic reads right-to-left
                  style: HesakTextStyles.splashTagline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}