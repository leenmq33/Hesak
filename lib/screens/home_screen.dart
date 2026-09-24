import 'package:flutter/material.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: const Color(0xFFFCF9FF),

      body: SafeArea(
        child: Column(
          children: [
            // Home screen header
            SizedBox(
              height: 95,
              child: Stack(
                children: [
                  // Decorative wave pattern
                  Positioned(
                    right: -10,
                    top: 5,
                    child: SizedBox(
                      width: screenWidth * 0.68,
                      height: 85,
                      child: CustomPaint(
                        painter: HeaderWavePainter(),
                      ),
                    ),
                  ),

                  // Hesak logo
                  Positioned(
                    left: 22,
                    top: 20,
                    child: SizedBox(
                      width: screenWidth * 0.25,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Flexible(
                            flex: 27,
                            child: Transform.translate(
                              offset: const Offset(4, -2),
                              child: Image.asset(
                                'assets/images/logo/splash_ear.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 46,
                            child: Image.asset(
                              'assets/images/logo/splash_waves.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          Flexible(
                            flex: 27,
                            child: Transform.translate(
                              offset: const Offset(-2, 0),
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

            // Main home content will be added here
            const Expanded(
              child: SizedBox(),
            ),
          ],
        ),
      ),

      // Main application navigation bar
      bottomNavigationBar: HesakBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

// Draws the soft decorative waves used in the header
class HeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFBFA3E8).withOpacity(0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    // Creates multiple overlapping curves for a soft wave effect
    for (int i = 0; i < 6; i++) {
      final path = Path();
      final y = size.height * 0.50 + (i * 3);

      path.moveTo(0, y);

      path.cubicTo(
        size.width * 0.20,
        y - 28 - (i * 2),
        size.width * 0.38,
        y + 25 + (i * 2),
        size.width * 0.55,
        y,
      );

      path.cubicTo(
        size.width * 0.72,
        y - 30,
        size.width * 0.88,
        y - 25,
        size.width,
        y - 3,
      );

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}