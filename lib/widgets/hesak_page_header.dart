import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';

/// The same top part for EVERY page:
///   1) Logo on the left + soft twisted waves on the right
///   2) A line of text: the page title in the center,
///      OR a greeting on the right (home page)
///   3) Thin lavender divider that fades at both ends
///
/// Usage in any screen:
///   const HesakPageHeader(title: 'المحادثات'),          // centered page title
///   const HesakPageHeader.greeting(text: 'مرحبًا رحاب'), // greeting on the right
class HesakPageHeader extends StatelessWidget {
  /// The text shown under the logo (page title or greeting).
  final String title;

  /// true = greeting style, aligned to the right. false = centered page title.
  final bool isGreeting;

  /// Centered page title (all pages except home).
  const HesakPageHeader({super.key, required this.title}) : isGreeting = false;

  /// Greeting on the right side, used on the home page instead of a title.
  const HesakPageHeader.greeting({super.key, required String text})
      : title = text,
        isGreeting = true;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ---------- 1) Logo + waves ----------
        SizedBox(
          height: HesakSizes.headerHeight,
          child: Stack(
            children: [
              // Waves start at 40% of the width (right after the logo) and run to the edge.
              Positioned(
                left: screenWidth * 0.40,
                right: 0,
                top: 0,
                bottom: 0,
                child: CustomPaint(painter: _HesakHeaderWavePainter()),
              ),

              // Logo: 6% from the left, 36% of the screen width.
              Positioned(
                left: screenWidth * 0.06,
                top: 0,
                bottom: 6,
                child: Center(
                  child: _HesakHeaderLogo(width: screenWidth * 0.36),
                ),
              ),
            ],
          ),
        ),

        // ---------- 2) Page title OR greeting ----------
        Padding(
          padding: const EdgeInsets.fromLTRB(
            HesakSizes.pagePadding, 4, HesakSizes.pagePadding, 14),
          child: isGreeting
              // Greeting: right side (RTL start), greeting style.
              ? Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    title,
                    key: const Key('header_greeting'),
                    textDirection: TextDirection.rtl,
                    style: HesakTextStyles.greeting,
                  ),
                )
              // Page title: centered, big title style.
              : Text(
                  title,
                  key: const Key('header_page_title'),
                  textAlign: TextAlign.center,
                  style: HesakTextStyles.pageTitle,
                ),
        ),

        // ---------- 3) Divider ----------
        const _HesakHeaderDivider(),
      ],
    );
  }
}

/// Thin divider under the page title.
/// Lavender in the middle, fades out at both ends.
class _HesakHeaderDivider extends StatelessWidget {
  const _HesakHeaderDivider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HesakSizes.pagePadding),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              HesakColors.lavenderAccent.withOpacity(0), // Invisible at the left end
              HesakColors.lavenderAccent, // Full color in the middle
              HesakColors.lavenderAccent.withOpacity(0), // Invisible at the right end
            ],
          ),
        ),
      ),
    );
  }
}

/// The logo with a soft shadow underneath it.
/// The shadow is a blurred, faded copy of the logo drawn slightly lower.
class _HesakHeaderLogo extends StatelessWidget {
  final double width;

  const _HesakHeaderLogo({required this.width});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          // Shadow copy: moved down, blurred, and made transparent.
          Transform.translate(
            offset: const Offset(0, 5),
            child: Opacity(
              opacity: 0.30,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: _buildLogoImage(),
              ),
            ),
          ),

          // The real logo on top.
          _buildLogoImage(),
        ],
      ),
    );
  }

  /// The full logo as a single transparent PNG.
  Widget _buildLogoImage() {
    return Image.asset(
      'assets/images/logo/hesak_logo.png',
      fit: BoxFit.contain,
    );
  }
}

/// Draws the twisted ribbon of thin lines:
/// wide on the left, crosses at ~62% of the width, opens again at the right edge.
/// Fades in from the left so there is no hard start.
class _HesakHeaderWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Invisible on the far left, 40% visible from 25% of the width onward.
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.75
      ..isAntiAlias = true
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          HesakColors.headerWaves.withOpacity(0),
          HesakColors.headerWaves.withOpacity(0.40),
          HesakColors.headerWaves.withOpacity(0.40),
        ],
        stops: const [0.0, 0.25, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    const lineCount = 20; // Number of lines in the ribbon
    const steps = 150; // Points per line (higher = smoother curve)

    for (int i = 0; i < lineCount; i++) {
      // t goes from -1 (one edge of the ribbon) to +1 (the other edge).
      final t = -1 + 2 * i / (lineCount - 1);

      // Each line crosses at a slightly different spot so the twist looks soft.
      final crossPoint = 0.62 + 0.04 * t;

      final path = Path();
      for (int s = 0; s <= steps; s++) {
        final u = s / steps; // 0 = left edge, 1 = right edge

        // Center of the ribbon: sits a bit low, rises slightly at the right end.
        final centerY = h * (0.63 + 0.03 * math.sin(math.pi * u) - 0.06 * u * u * u);

        // Ribbon half-width. Passes through zero at crossPoint = the twist.
        final angle = math.pi / 2 + (u - crossPoint) * 4.2;
        final amp = h * 0.27 * math.cos(angle);

        // Tiny per-line wave so the lines feel silky.
        final wobble = math.sin(u * math.pi * 3 + i * 0.45) * h * 0.015;

        final y = centerY + t * amp + wobble;
        s == 0 ? path.moveTo(0, y) : path.lineTo(u * w, y);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  // The drawing never changes, so no need to repaint.
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
