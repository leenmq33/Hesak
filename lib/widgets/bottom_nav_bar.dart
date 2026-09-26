import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/data/hesak_modes.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';

// =====================================================================
//  NAMING RULES used in this file (so team files never clash):
//  - Public names start with "Hesak" + what they are (HesakNavTab ...).
//  - Private names say exactly what they belong to
//    (e.g. _modeMenuController, not _controller).
//  - Every tappable widget has a unique Key: 'navbar_<part>_<name>'.
//  - Colors / text styles / sizes come ONLY from lib/core/theme.
//  - Mode ids / names / icons come ONLY from lib/core/data/hesak_modes.dart.
// =====================================================================

/// The 4 tabs of the bottom bar.
/// Order on screen (right -> left, Arabic): home, chats, [mode button], modes, settings.
enum HesakNavTab { home, chats, modes, settings }

/// Floating bottom navigation bar for Hesak.
/// - 4 tabs with icon + label. The selected tab gets a small light-purple pill.
/// - A raised round "general mode" button (person icon) sits in a curved notch.
/// - Tapping it opens a half-circle "wheel" (like a steering wheel):
///     * 2 modes are visible at a time (top + right) and "إضافة" is fixed on the left.
///     * Spin the wheel with a finger to bring the other modes into view.
///     * The wheel stops at the last mode — it can't spin past the list.
/// - The active mode's icon is purple, the others are grey,
///   and the middle button shows the active mode's icon.
/// - The bar stretches down to the very bottom of the screen.
class HesakBottomNavBar extends StatefulWidget {
  /// The tab that is currently selected.
  final HesakNavTab selectedTab;

  /// Called when the user taps a tab.
  final ValueChanged<HesakNavTab> onTabSelected;

  /// All the user's modes, in wheel order (first one is shown on top).
  final List<HesakModeOption> modes;

  /// id of the active mode (e.g. 'general'). null = nothing picked yet.
  final String? selectedModeId;

  /// Called with the picked mode's id.
  final ValueChanged<String>? onModeSelected;

  /// Called when the user taps "إضافة" (add a new mode).
  final VoidCallback? onAddModeTap;

  const HesakBottomNavBar({
    super.key,
    required this.selectedTab,
    required this.onTabSelected,
    this.modes = const [],
    this.selectedModeId,
    this.onModeSelected,
    this.onAddModeTap,
  });

  @override
  State<HesakBottomNavBar> createState() => _HesakBottomNavBarState();
}

class _HesakBottomNavBarState extends State<HesakBottomNavBar>
    with TickerProviderStateMixin {
  // ---- Sizes ----
  static const double _navBarHeight = 74;
  static const double _modeButtonSize = 80; // Middle button diameter
  static const double _modeMenuItemSize = 56; // Each circle on the wheel
  static const double _modeMenuLabelWidth = 80; // Room for the label under each circle
  static const double _modeWheelRadius = 112; // Distance from the middle button to each circle
  static const double _modeMenuBackdropRadius = 162; // Size of the half-circle background
  static const double _menuAreaHeight = 166; // Room above the bar for the wheel

  // ---- Wheel angles (degrees: 0 = right, 90 = up, 180 = left) ----
  static const double _wheelStep = 60; // Degrees between two modes on the wheel
  static const double _firstModeAngle = 90; // First mode sits on top
  static const double _addButtonAngle = 150; // "إضافة" is fixed on the left
  static const int _visibleModeSlots = 2; // Modes visible at once (top + right)

  // Controls the open/close animation of the mode menu.
  late final AnimationController _modeMenuController;
  late final Animation<double> _modeMenuAnimation;
  bool _isModeMenuOpen = false;

  // ---- Wheel spin state ----
  double _wheelRotation = 0; // How far the wheel is turned, in degrees (0 = start)
  double? _lastFingerAngle; // Finger angle on the previous drag update
  late final AnimationController _wheelSnapController; // Smoothly snaps to the nearest mode
  Animation<double>? _wheelSnapAnimation;

  // Used to turn the finger's screen position into a position inside this widget.
  final GlobalKey _navBarAreaKey = GlobalKey();

  /// Furthest the wheel may turn: stops when the last mode reaches the right slot.
  double get _maxWheelRotation =>
      math.max(0, widget.modes.length - _visibleModeSlots).toDouble() * _wheelStep;

  @override
  void initState() {
    super.initState();
    _modeMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    // easeOutBack gives a small "pop" at the end when opening.
    _modeMenuAnimation = CurvedAnimation(
      parent: _modeMenuController,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );

    _wheelSnapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addListener(() {
        final snap = _wheelSnapAnimation;
        if (snap != null) setState(() => _wheelRotation = snap.value);
      });
  }

  @override
  void dispose() {
    _modeMenuController.dispose();
    _wheelSnapController.dispose();
    super.dispose();
  }

  /// Opens the mode menu if closed, closes it if open.
  /// Every time it opens, the wheel starts from the beginning.
  void _toggleModeMenu() {
    setState(() {
      _isModeMenuOpen = !_isModeMenuOpen;
      if (_isModeMenuOpen) _wheelRotation = 0;
    });
    _isModeMenuOpen ? _modeMenuController.forward() : _modeMenuController.reverse();
  }

  /// A mode circle was tapped: close the menu and make it the active mode.
  void _handleModeTap(String modeId) {
    _toggleModeMenu();
    widget.onModeSelected?.call(modeId);
  }

  /// "إضافة" was tapped.
  void _handleAddModeTap() {
    _toggleModeMenu();
    widget.onAddModeTap?.call();
  }

  // ---------------------------------------------------------------
  // Wheel spinning (steering-wheel style)
  // ---------------------------------------------------------------

  /// Angle (degrees) of the finger around the middle button.
  double _fingerAngle(Offset globalPosition, Offset wheelCenter) {
    final box = _navBarAreaKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(globalPosition);
    final dx = local.dx - wheelCenter.dx;
    final dy = wheelCenter.dy - local.dy; // Flip: up is positive
    return math.atan2(dy, dx) * 180 / math.pi;
  }

  void _handleWheelDragStart(DragStartDetails details, Offset wheelCenter) {
    _wheelSnapController.stop();
    _lastFingerAngle = _fingerAngle(details.globalPosition, wheelCenter);
  }

  /// Turns the wheel by how much the finger moved around the middle button.
  void _handleWheelDragUpdate(DragUpdateDetails details, Offset wheelCenter) {
    final previous = _lastFingerAngle;
    final current = _fingerAngle(details.globalPosition, wheelCenter);
    _lastFingerAngle = current;
    if (previous == null) return;

    // Change since last update, kept between -180 and 180 (no jump when crossing the edge).
    var delta = current - previous;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;

    setState(() {
      // Can't turn before the first mode or past the last one.
      _wheelRotation = (_wheelRotation + delta).clamp(0.0, _maxWheelRotation);
    });
  }

  /// Finger lifted: glide to the nearest mode so the circles sit neatly in their slots.
  void _handleWheelDragEnd(DragEndDetails details) {
    _lastFingerAngle = null;
    final target = ((_wheelRotation / _wheelStep).round() * _wheelStep)
        .clamp(0.0, _maxWheelRotation)
        .toDouble();
    _wheelSnapAnimation = Tween<double>(begin: _wheelRotation, end: target).animate(
      CurvedAnimation(parent: _wheelSnapController, curve: Curves.easeOut),
    );
    _wheelSnapController.forward(from: 0);
  }

  /// Wraps a widget so dragging on it spins the wheel.
  Widget _wheelDragArea({required Widget child, required Offset wheelCenter}) {
    return GestureDetector(
      onPanStart: (d) => _handleWheelDragStart(d, wheelCenter),
      onPanUpdate: (d) => _handleWheelDragUpdate(d, wheelCenter),
      onPanEnd: _handleWheelDragEnd,
      child: child,
    );
  }

  /// How visible a mode is at a given wheel angle:
  /// fully visible in the top/right slots, fades out as it goes under the bar
  /// (right side) or behind "إضافة" (left side).
  double _modeVisibilityAt(double angle) {
    if (angle < 30) return ((angle + 10) / 40).clamp(0.0, 1.0); // Coming up from under the bar
    if (angle > 100) return ((140 - angle) / 40).clamp(0.0, 1.0); // Sliding behind "إضافة"
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    // Height of the phone's bottom area (home indicator). The bar grows by this
    // much so it reaches the very bottom of the screen, while the icons stay above it.
    final bottomInset = MediaQuery.of(context).padding.bottom;
    final barHeight = _navBarHeight + bottomInset;

    return SizedBox(
      key: _navBarAreaKey,
      // Tall enough for the wheel. The empty space above the bar
      // is transparent and lets taps pass through to the page behind it
      // (requires `extendBody: true` on the Scaffold).
      height: _menuAreaHeight + barHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final modeCenterX = constraints.maxWidth / 2;
          // Y of the middle button's center (sits on the bar's top edge).
          const modeCenterY = _menuAreaHeight + 4;
          final wheelCenter = Offset(modeCenterX, modeCenterY);

          return AnimatedBuilder(
            animation: _modeMenuAnimation,
            builder: (context, _) {
              final menuProgress = _modeMenuAnimation.value; // 0 = closed, 1 = open

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ---------- 0) Half-circle background (drag here to spin) ----------
                  if (menuProgress > 0)
                    Positioned(
                      left: modeCenterX - _modeMenuBackdropRadius,
                      top: modeCenterY - _modeMenuBackdropRadius,
                      width: _modeMenuBackdropRadius * 2,
                      height: _modeMenuBackdropRadius * 2,
                      child: _wheelDragArea(
                        wheelCenter: wheelCenter,
                        child: GestureDetector(
                          key: const Key('navbar_mode_menu_backdrop'),
                          onTap: _toggleModeMenu, // Tap the background = close the menu
                          child: Transform.scale(
                            scale: menuProgress.clamp(0.0, 1.0),
                            child: CustomPaint(
                              painter: _HesakModeMenuHalfCirclePainter(
                                diameter: _modeMenuBackdropRadius * 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ---------- 1) The bar with the curved notch ----------
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    height: barHeight,
                    child: CustomPaint(
                      painter: _HesakNavBarNotchPainter(color: HesakColors.navBar),
                      child: Padding(
                        // Extra bottom padding keeps the icons above the home indicator.
                        padding: EdgeInsets.fromLTRB(8, 8, 8, 6 + bottomInset),
                        child: Row(
                          // Right-to-left: "الرئيسية" is the first tab on the right.
                          textDirection: TextDirection.rtl,
                          children: [
                            _buildNavTab(HesakNavTab.home, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
                            _buildNavTab(HesakNavTab.chats, Icons.chat_outlined, Icons.chat_rounded, 'المحادثات'),
                            const SizedBox(width: 92), // Empty space under the middle button (same width as the notch)
                            _buildNavTab(HesakNavTab.modes, Icons.grid_view_outlined, Icons.grid_view_rounded, 'الأوضاع'),
                            _buildNavTab(HesakNavTab.settings, Icons.settings_outlined, Icons.settings_rounded, 'الإعدادات'),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ---------- 2) The modes on the wheel ----------
                  // Mode i sits at (90 - 60*i) degrees, turned by the wheel rotation.
                  // Only the ones near the top/right slots are visible.
                  if (menuProgress > 0)
                    for (int i = 0; i < widget.modes.length; i++)
                      _buildWheelItem(
                        keyName: widget.modes[i].id,
                        icon: widget.modes[i].icon,
                        label: widget.modes[i].label,
                        isActive: widget.selectedModeId == widget.modes[i].id,
                        onTap: () => _handleModeTap(widget.modes[i].id),
                        angleDegrees: _firstModeAngle - _wheelStep * i + _wheelRotation,
                        menuProgress: menuProgress,
                        wheelCenter: wheelCenter,
                      ),

                  // ---------- 3) "إضافة" — fixed on the left, drawn above the modes ----------
                  if (menuProgress > 0)
                    _buildWheelItem(
                      keyName: 'add',
                      icon: Icons.add_rounded,
                      label: 'إضافة',
                      isActive: false, // "Add" is an action, never an active mode
                      onTap: _handleAddModeTap,
                      angleDegrees: _addButtonAngle,
                      menuProgress: menuProgress,
                      wheelCenter: wheelCenter,
                    ),

                  // ---------- 4) The raised middle button (always on top) ----------
                  Positioned(
                    left: modeCenterX - _modeButtonSize / 2,
                    top: modeCenterY - _modeButtonSize / 2,
                    child: _buildModeButton(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  /// The raised round button in the middle. Shows the active mode's icon.
  /// Solid purple circle (no ring), with a soft shadow + gradient so it looks lifted.
  Widget _buildModeButton() {
    return GestureDetector(
      key: const Key('navbar_mode_button'),
      onTap: _toggleModeMenu,
      child: Container(
        width: _modeButtonSize,
        height: _modeButtonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Lighter at the top-left, darker at the bottom-right.
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [HesakColors.primaryMuted, HesakColors.primary],
          ),
          // Shadow underneath = the "raised" look.
          boxShadow: [
            BoxShadow(
              color: HesakColors.primary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        // Shows the active mode's icon (e.g. person for "العام").
        // When it changes, the old icon shrinks away and the new one pops in.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            _activeModeIcon,
            key: ValueKey(_activeModeIcon), // Tells the switcher the icon changed
            color: HesakColors.onPrimary,
            size: 36,
          ),
        ),
      ),
    );
  }

  /// Icon of the active mode. Falls back to the person icon (general mode).
  IconData get _activeModeIcon {
    for (final mode in widget.modes) {
      if (mode.id == widget.selectedModeId) return mode.icon;
    }
    return Icons.person_rounded;
  }

  /// One tab: icon + label.
  /// When selected: light-purple pill behind it, filled icon, purple color.
  Widget _buildNavTab(HesakNavTab tab, IconData icon, IconData selectedIcon, String label) {
    final bool isSelected = tab == widget.selectedTab;

    return Expanded(
      child: GestureDetector(
        key: Key('navbar_tab_${tab.name}'), // e.g. navbar_tab_home
        behavior: HitTestBehavior.opaque, // Whole area is tappable, not just the icon
        onTap: () => widget.onTabSelected(tab),
        child: Center(
          child: AnimatedContainer(
            // Smoothly fades the pill in/out when switching tabs.
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            // Small, fully rounded pill (only as big as the icon + label need).
            width: 62,
            height: 50,
            decoration: BoxDecoration(
              color: isSelected ? HesakColors.primaryLight : Colors.transparent,
              borderRadius: BorderRadius.circular(25), // Half the height = fully rounded ends
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isSelected ? selectedIcon : icon,
                  size: HesakSizes.iconNavTab,
                  color: isSelected ? HesakColors.primaryMuted : HesakColors.iconInactive,
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: isSelected ? HesakTextStyles.navLabelSelected : HesakTextStyles.navLabel,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One circle on the wheel (a mode, or "إضافة"), with its label underneath.
  /// Circle is always light purple; the icon is purple when [isActive], grey otherwise.
  /// Dragging on it spins the wheel; tapping it picks it.
  Widget _buildWheelItem({
    required String keyName,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required double angleDegrees,
    required double menuProgress,
    required Offset wheelCenter,
  }) {
    // Hidden when it's turned out of the visible slots.
    final visibility = keyName == 'add' ? 1.0 : _modeVisibilityAt(angleDegrees);
    final opacity = (visibility * menuProgress).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();

    // Position on the wheel. While the menu opens, circles fly out from the middle.
    final radians = angleDegrees * math.pi / 180;
    final distance = _modeWheelRadius * menuProgress;
    final dx = distance * math.cos(radians);
    final dy = -distance * math.sin(radians); // Minus = up on screen

    return Positioned(
      left: wheelCenter.dx + dx - _modeMenuLabelWidth / 2,
      top: wheelCenter.dy + dy - _modeMenuItemSize / 2,
      width: _modeMenuLabelWidth,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: 0.7 + 0.3 * visibility, // Shrinks a little while fading out
          child: _wheelDragArea(
            wheelCenter: wheelCenter,
            child: GestureDetector(
              key: Key('navbar_mode_${keyName}_button'), // e.g. navbar_mode_prayer_button
              onTap: onTap,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _modeMenuItemSize,
                    height: _modeMenuItemSize,
                    decoration: BoxDecoration(
                      color: HesakColors.primaryLight,
                      shape: BoxShape.circle,
                      // Active mode gets a stronger purple border.
                      border: Border.all(
                        color: isActive ? HesakColors.primaryMuted : HesakColors.primaryLightBorder,
                        width: isActive ? 2 : 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: HesakColors.primaryMuted.withOpacity(0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(
                      icon,
                      size: 28,
                      color: isActive ? HesakColors.primaryMuted : HesakColors.iconInactive,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: isActive
                        ? HesakTextStyles.modeLabel.copyWith(color: HesakColors.primaryMuted)
                        : HesakTextStyles.modeLabel,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the soft half-circle behind the wheel.
/// The bar covers its bottom edge, so only the top half is drawn.
class _HesakModeMenuHalfCirclePainter extends CustomPainter {
  final double diameter; // Size of the square this is painted in

  _HesakModeMenuHalfCirclePainter({required this.diameter});

  /// Top half of a circle, flat side on the middle button's center line.
  Path _buildHalfCirclePath(Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    return Path()
      ..moveTo(center.dx - size.width / 2, center.dy)
      ..arcTo(rect, math.pi, math.pi, false) // From left, over the top, to right
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final half = _buildHalfCirclePath(size);

    // Soft shadow, then the see-through fill, then a thin outline.
    canvas.drawShadow(half, HesakColors.primaryMuted.withOpacity(0.15), 8, true);
    canvas.drawPath(half, Paint()..color = HesakColors.modeMenuBackdrop);
    canvas.drawPath(
      half,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = HesakColors.modeMenuBackdropBorder,
    );
  }

  // Only the half-circle catches taps/drags (not the empty area below it).
  @override
  bool? hitTest(Offset position) => _buildHalfCirclePath(Size.square(diameter)).contains(position);

  @override
  bool shouldRepaint(covariant _HesakModeMenuHalfCirclePainter oldDelegate) =>
      oldDelegate.diameter != diameter;
}

/// Paints the bar: rounded top corners, square bottom (touches the screen edge),
/// and a smooth curved dip
/// in the top center where the middle button sits.
class _HesakNavBarNotchPainter extends CustomPainter {
  final Color color;

  _HesakNavBarNotchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final c = w / 2; // Center X
    const r = HesakSizes.radiusNavBar; // Corner radius of the bar
    const notchHalfWidth = 72.0; // Half the width of the notch
    const notchDepth = 48.0; // How deep the notch goes (fits the 80px button)

    final path = Path()
      ..moveTo(r, 0)
      // Top edge up to the start of the notch.
      ..lineTo(c - notchHalfWidth, 0)
      // Left side of the notch: smooth curve down.
      ..cubicTo(c - 48, 0, c - 54, notchDepth, c, notchDepth)
      // Right side of the notch: smooth curve back up.
      ..cubicTo(c + 54, notchDepth, c + 48, 0, c + notchHalfWidth, 0)
      // Rest of the top edge + rounded corners.
      ..lineTo(w - r, 0)
      ..quadraticBezierTo(w, 0, w, r)
      // Bottom corners are square: the bar touches the bottom of the screen.
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    // Soft shadow under the bar.
    canvas.drawShadow(path, HesakColors.primaryMuted.withOpacity(0.2), 6, false);
    // The bar fill.
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _HesakNavBarNotchPainter oldDelegate) =>
      oldDelegate.color != color;
}
