import 'package:flutter/material.dart';
import 'dart:async';
import 'home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _waveAnimation;

 @override
void initState() {
  super.initState();

  // Controls the sound wave animation
  _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );

  // Defines the vertical scaling range of the sound waves
  _waveAnimation = Tween<double>(
    begin: 0.82,
    end: 1.08,
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ),
  );

  // Repeats the sound wave animation continuously
  _controller.repeat(reverse: true);

  // Navigate to the home screen after displaying the splash screen
  Timer(const Duration(seconds: 5), () {
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        ),
      );
    }
  });
}

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0E6FF),
              Color(0xFFFCF9FF),
              Color(0xFFF3E9FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -90,
              left: -80,
              child: Container(
                width: 350,
                height: 220,
                decoration: BoxDecoration(
                  color: const Color(0xFFBFA3E8).withOpacity(0.18),
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(220),
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 420,
                height: 260,
                decoration: BoxDecoration(
                  color: const Color(0xFFCAB3EE).withOpacity(0.20),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(250),
                  ),
                ),
              ),
            ),

            Center(
              child: SizedBox(
                width: screenWidth * 0.72,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [

                    Flexible(
                      flex: 27,
                      child: Transform.translate(
                        offset: const Offset(18, -6),
                        child: Image.asset(
                          'assets/images/logo/splash_ear.png',
                          width: 105,
                        ),
                      ),
                    ),

                    Flexible(
                      flex: 46,
                      child: AnimatedBuilder(
                        animation: _waveAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scaleX: 1.0,
                            scaleY: _waveAnimation.value,
                            alignment: Alignment.center,
                            child: child,
                          );
                        },
                        child: Image.asset(
                          'assets/images/logo/splash_waves.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),

                    Flexible(
                      flex: 27,
                      child: Transform.translate(
                        offset: const Offset(-8, 0),
                        child: Image.asset(
                          'assets/images/logo/splash_end.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}