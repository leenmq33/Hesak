import 'package:flutter/material.dart';
import 'dart:async';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_text_styles.dart';
import 'main_shell.dart';

/// The first screen the user sees when the app opens.
/// Colors and text styles come from lib/core/theme.
/// Shows the animated logo, then the tagline, then moves to the home screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

// TickerProviderStateMixin (not Single...) because we have two animation controllers.
class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // --- Sound wave animation ---
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

  // --- Tagline animation ---
  late AnimationController _taglineController;
  late Animation<double> _taglineOpacity; // Fades the text from invisible to visible
  late Animation<Offset> _taglineSlide; // Moves the text slightly upward while it appears

  // Timers are stored so we can cancel them if the screen closes early.
  Timer? _taglineTimer;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // One full wave movement takes 700ms.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    // The waves stretch vertically between 82% and 108% of their size.
    _waveAnimation = Tween<double>(
      begin: 0.82,
      end: 1.08,
    ).animate(
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
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _taglineController,
        curve: Curves.easeOut,
      ),
    );

    // Wait 1.5 seconds after the logo appears, then show the tagline.
    _taglineTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) _taglineController.forward();
    });

    // After 5 seconds, replace the splash screen with the home screen
    // (pushReplacement means the user can't go back to the splash).
    _navigationTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const HesakMainShell(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    // Clean up timers and controllers to avoid memory leaks and errors.
    _taglineTimer?.cancel();
    _navigationTimer?.cancel();
    _controller.dispose();
    _taglineController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Used to size the logo relative to the screen width.
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        // Soft purple gradient background.
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: HesakColors.splashGradient,
          ),
        ),

        // Stack lets us place decorative shapes behind the logo.
        child: Stack(
          children: [
            // Decorative curved shape in the top-left corner.
            Positioned(
              top: -90,
              left: -80,
              child: Container(
                width: 350,
                height: 220,
                decoration: BoxDecoration(
                  color: HesakColors.splashShapeTop.withOpacity(0.18),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(220),
                  ),
                ),
              ),
            ),

            // Decorative curved shape in the bottom-right corner.
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 420,
                height: 260,
                decoration: BoxDecoration(
                  color: HesakColors.splashShapeBottom.withOpacity(0.20),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(250),
                  ),
                ),
              ),
            ),

            // Main content: logo on top, tagline below it.
            Center(
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
                            offset: const Offset(18, -6), // Nudge to connect with the waves
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
                            offset: const Offset(-8, 0), // Nudge left to close the gap
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
                          'لأن ما لا يسمع يستحق أن يدرك',
                          textAlign: TextAlign.center,
                          textDirection: TextDirection.rtl, // Arabic reads right-to-left
                          style: HesakTextStyles.splashTagline,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}