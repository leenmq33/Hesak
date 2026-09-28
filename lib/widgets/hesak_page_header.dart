import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_palette.dart';
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
///   HesakPageHeader(title: 'الأوضاع', onBack: () => Navigator.pop(context)), // + back arrow on the right
///   HesakPageHeader(title: 'الإعدادات', followsAppearance: true), // changes with فاتح / داكن
class HesakPageHeader extends StatelessWidget {
  /// The text shown under the logo (page title or greeting).
  final String title;

  /// true = greeting style, aligned to the right. false = centered page title.
  final bool isGreeting;

  /// Optional: shows a back arrow on the right (for inner pages). null = no arrow.
  final VoidCallback? onBack;

  /// true = follows the appearance (فاتح / داكن) from HesakThemeController.
  /// For now only the الإعدادات pages use it; the rest stay light.
  final bool followsAppearance;

  /// Centered page title (all pages except home).
  const HesakPageHeader({super.key, required this.title, this.onBack, this.followsAppearance = false})
      : isGreeting = false;

  /// Greeting on the right side, used on the home page instead of a title.
  const HesakPageHeader.greeting({super.key, required String text})
      : title = text,
        isGreeting = true,
        onBack = null,
        followsAppearance = false;

  @override
  Widget build(BuildContext context) {
    // Headers that follow فاتح / داكن rebuild by themselves when it changes
    // (works even when the header is created with const).
    if (followsAppearance) {
      return ListenableBuilder(
        listenable: HesakThemeController.instance,
        builder: (context, _) => _buildHeader(context),
      );
    }
    return _buildHeader(context);
  }

  Widget _buildHeader(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    // Dark only when this header follows the appearance AND داكن is picked.
    final bool isDark = followsAppearance && HesakThemeController.instance.isDark;
    final HesakPalette palette = isDark ? HesakPalette.dark : HesakPalette.light;

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
                child: CustomPaint(
                  painter: _HesakHeaderWavePainter(color: isDark ? palette.headerLines : HesakColors.headerWaves),
                ),
              ),

              // Logo: 6% from the left, 36% of the screen width.
              Positioned(
                left: screenWidth * 0.06,
                top: 0,
                bottom: 6,
                child: Center(
                  child: _HesakHeaderLogo(width: screenWidth * 0.36, isOnDark: isDark),
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
              // Page title: centered, big title style (+ back arrow on the right if given).
              : SizedBox(
                  width: double.infinity, // Full width, so the arrow sits at the screen edge
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        title,
                        key: const Key('header_page_title'),
                        textAlign: TextAlign.center,
                        style: HesakTextStyles.pageTitle.copyWith(color: palette.title),
                      ),
                      if (onBack != null)
                        Positioned(
                          right: 0,
                          child: IconButton(
                            key: const Key('header_back_button'),
                            onPressed: onBack,
                            // Points right in Arabic (flips with the text direction).
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 22),
                            color: palette.textPrimary,
                            tooltip: 'رجوع',
                          ),
                        ),
                    ],
                  ),
                ),
        ),

        // ---------- 3) Divider ----------
        _HesakHeaderDivider(color: isDark ? palette.headerLines : HesakColors.lavenderAccent),
      ],
    );
  }
}

/// Thin divider under the page title.
/// Lavender in the middle, fades out at both ends.
class _HesakHeaderDivider extends StatelessWidget {
  final Color color;

  const _HesakHeaderDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: HesakSizes.pagePadding),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.withOpacity(0), // Invisible at the left end
              color, // Full color in the middle
              color.withOpacity(0), // Invisible at the right end
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
  final bool isOnDark; // Dark page: the purple logo sits on a light pill so it stays visible

  const _HesakHeaderLogo({required this.width, this.isOnDark = false});

  @override
  Widget build(BuildContext context) {
    if (isOnDark) {
      return Container(
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: HesakColors.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: _buildLogoImage(),
      );
    }
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
  final Color color;

  _HesakHeaderWavePainter({required this.color});

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
          color.withOpacity(0),
          color.withOpacity(0.40),
          color.withOpacity(0.40),
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
  bool shouldRepaint(covariant _HesakHeaderWavePainter oldDelegate) => oldDelegate.color != color;
}
