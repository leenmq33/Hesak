import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../services/auth_service.dart';
import '../widgets/hesak_page_header.dart';
import 'modes/mode_editor_screen.dart';
import 'modes/modes_widgets.dart';

// =====================================================================
//  MODES PAGE (الأوضاع) — the tab in the bottom bar.
//
//  The tab has its OWN navigator, so the inner pages (إضافة وضع, تعديل وضع)
//  open INSIDE the tab and the bottom bar stays visible.
//
//  ONE page, top to bottom:
//   - A small grey hint on top: "شغّل المفتاح للاختيار" · "اسحب للترتيب"
//   - ALL the modes in ONE fixed order. Choosing a mode does NOT move it:
//     it stays in its place and only turns purple ("مفعّل" deep purple while
//     listening, "غير مفعّل" lighter + a hint strip at its bottom).
//     The others are lavender cards (same gradient as المحادثات).
//     Every card:
//       line 1: ⋮⋮, icon, name, schedule, the choose switch
//       line 2: star · pencil · arrow ⌄
//       switch     = it becomes the selected mode (stays in its place)
//       pencil     = edit it WITHOUT selecting it
//       arrow / tap on the card = opens "إعدادات الوضع" (view only) and
//                    "جدولة الوضع" (add / edit / delete periods) under it
//       drag       = change the order (the wheel on the bar follows this order)
//   - "إضافة وضع جديد"
//
//  "مفعّل" = the selected mode is really working, which only happens while
//  the listen button on الرئيسية is ON (HesakModeStore.isListening).
//
//  Data: HesakModeStore (lib/core/data/hesak_mode_store.dart).
//  Shared pieces: modes/modes_widgets.dart.
//
//  NAMING: everything here starts with "Modes". Keys: 'modes_<name>'.
//  This page does NOT build the bottom bar — HesakMainShell does that.
// =====================================================================

/// The الأوضاع tab (with its own navigator for the inner pages).
class ModesScreen extends StatelessWidget {
  /// true while the الأوضاع tab is the one on screen. The phone back button
  /// only goes back inside this tab while it's shown.
  final bool isActive;

  const ModesScreen({super.key, this.isActive = true});

  /// The navigator of this tab (inner pages open here, under the bottom bar).
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>(debugLabel: 'modes_navigator');

  /// Opens "إضافة وضع" inside this tab (used by "إضافة +" on the bar wheel).
  static void openAddModePage() {
    navigatorKey.currentState?.push(
      MaterialPageRoute(builder: (_) => ModeEditorScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phone back button: go back inside the tab first (e.g. from تعديل وضع to الأوضاع).
    return NavigatorPopHandler(
      enabled: isActive,
      onPop: () => navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: navigatorKey,
        onGenerateRoute: (settings) => MaterialPageRoute(
          settings: settings,
          builder: (_) => _ModesHomePage(),
        ),
      ),
    );
  }
}

/// The first page of the tab: header + selected mode card + the other modes.
class _ModesHomePage extends StatelessWidget {
  const _ModesHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HesakColors.tabPageBackground, // Same lavender as the other tabs
      body: SafeArea(
        bottom: false, // The bottom bar handles the bottom edge
        child: Column(
          children: [
            // Shared header: logo + waves + page title + divider.
            HesakPageHeader(title: 'الأوضاع'),

            // Rebuilds whenever a mode changes (selected, starred, edited, listening ...).
            Expanded(
              child: ListenableBuilder(
                // Also AuthService: "نداء اسمك" under the arrow depends on الاسم للنداء.
                listenable: Listenable.merge([HesakModeStore.instance, AuthService.instance]),
                // Not const on purpose: a const widget would never rebuild.
                builder: (context, _) => _ModesPageContent(store: HesakModeStore.instance),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Everything under the header.
class _ModesPageContent extends StatefulWidget {
  final HesakModeStore store;

  const _ModesPageContent({required this.store});

  @override
  State<_ModesPageContent> createState() => _ModesPageContentState();
}

class _ModesPageContentState extends State<_ModesPageContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Switch turned on: that mode becomes the selected one. It stays in its
  /// place in the list (nothing moves) — only its colors change.
  void _selectMode(String id) => widget.store.selectMode(id);

  /// Drag: change the order of ALL the modes (the selected one too).
  /// The wheel on the bar follows this order.
  void _reorderModes(List<HesakModeConfig> modes, int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex -= 1; // ReorderableListView counts the moved row
    final List<String> orderedIds = modes.map((m) => m.id).toList();
    final String movedId = orderedIds.removeAt(oldIndex);
    orderedIds.insert(newIndex.clamp(0, orderedIds.length), movedId);
    widget.store.setModesOrder(orderedIds);
  }

  @override
  Widget build(BuildContext context) {
    final HesakModeStore store = widget.store;
    final List<HesakModeConfig> modes = store.modes;
    final String selectedId = store.selectedModeId;

    return SingleChildScrollView(
      controller: _scrollController,
      // Bottom space keeps the content above the bottom bar.
      padding: EdgeInsets.fromLTRB(
        HesakSizes.pagePadding,
        4,
        HesakSizes.pagePadding,
        HesakSizes.pageBottomSafeSpace,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ---- Hint on top: switch = choose, ⋮⋮ = drag ----
          if (modes.length > 1) ...[
            SizedBox(height: 6),
            _ModesListHint(),
            SizedBox(height: 12),
          ] else
            SizedBox(height: 10),

          // ---- All the modes, in a fixed order (the selected one stays in its place) ----
          ReorderableListView(
            // Lives inside the page's scroll: not scrollable by itself.
            shrinkWrap: true,
            padding: EdgeInsets.zero, // No hidden bottom gap (the bar height) before "إضافة وضع جديد"
            physics: NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false, // Our own handle (⋮⋮) + long-press on the card
            onReorder: (oldIndex, newIndex) => _reorderModes(modes, oldIndex, newIndex),
            // The card being dragged: a little lifted with a soft shadow.
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.transparent,
              elevation: 6,
              shadowColor: HesakColors.glassShadow,
              borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
              child: child,
            ),
            children: [
              for (int i = 0; i < modes.length; i++)
                ReorderableDelayedDragStartListener(
                  key: ValueKey('modes_row_${modes[i].id}'),
                  index: i,
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: _ModesModeCard(
                      // Same key selected or not, so an open card stays open when chosen.
                      key: ValueKey('modes_card_${modes[i].id}'),
                      mode: modes[i],
                      isSelected: modes[i].id == selectedId,
                      isListening: store.isListening,
                      dragIndex: i,
                      onSelect: () => _selectMode(modes[i].id),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 4),

          // ---- إضافة وضع جديد ----
          _ModesAddCard(),
        ],
      ),
    );
  }
}

/// Small grey line: "⊙ شغّل المفتاح للاختيار   ⋮⋮ اسحب للترتيب".
class _ModesListHint extends StatelessWidget {
  const _ModesListHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.toggle_on_outlined, size: 18, color: HesakColors.iconInactive),
        SizedBox(width: 4),
        Text('شغّل المفتاح للاختيار', style: HesakTextStyles.modeHint),
        SizedBox(width: 18),
        Icon(Icons.drag_indicator_rounded, size: 16, color: HesakColors.iconInactive),
        SizedBox(width: 2),
        Text('اسحب للترتيب', style: HesakTextStyles.modeHint),
      ],
    );
  }
}

// ---------------------------------------------------------------------
// One mode card (selected or not)
// ---------------------------------------------------------------------

/// One mode:
///  - selected: purple (deep while listening, lighter + hint strip when not)
///  - not selected: lavender gradient, icon in a white circle, drag handle
/// Line 1: icon, name (+ badge), schedule, the choose switch.
/// Line 2: star · pencil · arrow. The arrow (or a tap on the card) opens
/// "إعدادات الوضع" + "جدولة الوضع" under it.
class _ModesModeCard extends StatefulWidget {
  final HesakModeConfig mode;
  final bool isSelected;
  final bool isListening;
  final int? dragIndex; // Its place in the list (others only, for ⋮⋮)
  final VoidCallback onSelect;

  const _ModesModeCard({
    super.key,
    required this.mode,
    required this.isSelected,
    required this.isListening,
    required this.onSelect,
    this.dragIndex,
  });

  @override
  State<_ModesModeCard> createState() => _ModesModeCardState();
}

class _ModesModeCardState extends State<_ModesModeCard> {
  bool _isOpen = false; // Closed when the page opens

  void _toggleOpen() => setState(() => _isOpen = !_isOpen);

  void _openEditor() => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ModeEditorScreen(modeId: widget.mode.id)),
      );

  @override
  Widget build(BuildContext context) {
    final HesakModeConfig mode = widget.mode;
    final bool isSelected = widget.isSelected;
    final bool showListenHint = isSelected && !widget.isListening;

    final BoxDecoration decoration = isSelected
        ? BoxDecoration(
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
            gradient: LinearGradient(
              begin: AlignmentDirectional.topStart,
              end: AlignmentDirectional.bottomEnd,
              colors: widget.isListening
                  ? [HesakColors.primaryMuted, HesakColors.primary]
                  : [HesakColors.modeHeaderIdleStart, HesakColors.modeHeaderIdleEnd],
            ),
          )
        : BoxDecoration(
            borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
            border: Border.all(color: HesakColors.modesCardBorder),
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart,
              end: AlignmentDirectional.centerEnd,
              colors: HesakColors.modesCardGradient,
            ),
          );

    return AnimatedContainer(
      key: Key(isSelected ? 'modes_selected_row' : 'modes_row_${mode.id}_card'),
      duration: Duration(milliseconds: 300),
      clipBehavior: Clip.antiAlias, // The hint strip follows the rounded bottom
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Tap on the card = same as the arrow.
            InkWell(
              key: Key(isSelected ? 'modes_selected_tap' : 'modes_row_tap_${mode.id}'),
              onTap: _toggleOpen,
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(widget.dragIndex == null ? 12 : 2, 10, 0, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFirstLine(mode, isSelected),
                    SizedBox(height: 8),
                    _buildButtonsLine(mode, isSelected),
                  ],
                ),
              ),
            ),

            // "إعدادات الوضع" + "جدولة الوضع" (open with the arrow).
            AnimatedSize(
              duration: Duration(milliseconds: 250),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              child: _isOpen
                  ? Padding(
                      padding: EdgeInsets.fromLTRB(10, 0, 10, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _ModesDetailsBox(mode: mode),
                          SizedBox(height: 10),
                          _ModesScheduleBox(mode: mode),
                        ],
                      ),
                    )
                  : SizedBox(width: double.infinity),
            ),

            // Listening is off: how to really turn the selected mode on.
            if (showListenHint) _ModesListenHintStrip(),
          ],
        ),
      ),
    );
  }

  /// ⋮⋮ · icon · name (+ badge) / schedule · switch.
  Widget _buildFirstLine(HesakModeConfig mode, bool isSelected) {
    return Row(
      children: [
        // Drag handle: drag right away (the card itself needs a long press).
        if (widget.dragIndex != null)
          ReorderableDragStartListener(
            index: widget.dragIndex!,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              child: Icon(
                Icons.drag_indicator_rounded,
                color: isSelected ? HesakColors.onModeHeaderSoft : HesakColors.iconInactive,
                size: 22,
              ),
            ),
          ),

        // Icon (or first letter): white circle on lavender, see-through on purple.
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? HesakColors.modeHeaderOverlay : HesakColors.modesIconCircle,
          ),
          child: Center(
            child: mode.icon != null
                ? Icon(mode.icon, size: 26, color: isSelected ? HesakColors.onPrimary : HesakColors.modeSelected)
                : Text(
                    mode.firstLetter,
                    style: HesakTextStyles.modeCircleLetter.copyWith(
                      color: isSelected ? HesakColors.onPrimary : HesakColors.modeSelected,
                    ),
                  ),
          ),
        ),
        SizedBox(width: 12),

        // Name (+ مفعّل / غير مفعّل) and the schedule under it.
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      mode.name,
                      key: isSelected ? Key('modes_selected_name') : null,
                      style: isSelected ? HesakTextStyles.modeHeaderName : HesakTextStyles.modeRowName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) ...[
                    SizedBox(width: 8),
                    ModesStateBadge(isListening: widget.isListening),
                  ],
                ],
              ),
              SizedBox(height: 3),
              Text(
                mode.scheduleSummary,
                style: isSelected
                    ? HesakTextStyles.modeHeaderSubtitle.copyWith(height: 1.5)
                    : HesakTextStyles.modeHint.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
        SizedBox(width: 8),

        // The choose switch. Selected: a bit further from the edge.
        _ModesChooseSwitch(
          key: Key(isSelected ? 'modes_selected_switch' : 'modes_row_switch_${mode.id}'),
          isOn: isSelected,
          onTap: isSelected ? null : widget.onSelect,
        ),
        SizedBox(width: isSelected ? 14 : 8),
      ],
    );
  }

  /// Star · pencil · arrow, at the end side under the switch.
  Widget _buildButtonsLine(HesakModeConfig mode, bool isSelected) {
    final Color fill = isSelected ? HesakColors.modeHeaderOverlay : HesakColors.modesIconCircle;
    final Color iconColor = isSelected ? HesakColors.onPrimary : HesakColors.modeSelected;
    final Color emptyStarColor = isSelected ? HesakColors.onModeHeaderSoft : HesakColors.iconInactive;
    final String keyPart = isSelected ? 'selected' : 'row';

    return Padding(
      padding: EdgeInsetsDirectional.only(end: isSelected ? 14 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _ModesRoundButton(
            key: Key('modes_${keyPart}_star_${mode.id}'),
            tooltip: mode.isFavorite ? 'إزالة من الأوضاع المفضلة' : 'إضافة إلى الأوضاع المفضلة',
            icon: mode.isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            iconColor: mode.isFavorite ? HesakColors.favoriteStar : emptyStarColor,
            fill: fill,
            onTap: () => modesToggleFavorite(context, mode),
          ),
          SizedBox(width: 8),
          _ModesRoundButton(
            key: Key('modes_${keyPart}_edit_${mode.id}'),
            tooltip: 'تعديل',
            icon: Icons.edit_rounded,
            iconColor: iconColor,
            fill: fill,
            onTap: _openEditor,
          ),
          SizedBox(width: 8),
          _ModesRoundButton(
            key: Key('modes_${keyPart}_arrow_${mode.id}'),
            tooltip: _isOpen ? 'إخفاء التفاصيل' : 'عرض التفاصيل',
            icon: Icons.keyboard_arrow_down_rounded,
            iconColor: iconColor,
            fill: fill,
            turns: _isOpen ? 0.5 : 0, // ⌄ turns into ⌃
            onTap: _toggleOpen,
          ),
        ],
      ),
    );
  }
}

/// Small round button (star / pencil / arrow) on a mode card.
class _ModesRoundButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final Color fill;
  final VoidCallback onTap;
  final double turns; // For the arrow

  const _ModesRoundButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.fill,
    required this.onTap,
    this.turns = 0,
  });

  static const double _size = 36;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: fill,
        shape: CircleBorder(),
        child: InkWell(
          customBorder: CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: _size,
            height: _size,
            child: AnimatedRotation(
              turns: turns,
              duration: Duration(milliseconds: 250),
              child: Icon(icon, size: 20, color: iconColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// The choose switch (no words under it):
///  on  = white track, purple circle with ✓ (the selected mode)
///  off = empty track with a grey outline and a grey circle
/// Turning it on selects the mode. The selected one can't be turned off.
class _ModesChooseSwitch extends StatelessWidget {
  final bool isOn;
  final VoidCallback? onTap; // null = can't be changed (already selected)

  const _ModesChooseSwitch({super.key, required this.isOn, required this.onTap});

  static const double _width = 52;
  static const double _height = 30;
  static const double _thumb = 24;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: isOn,
      label: isOn ? 'الوضع المختار' : 'اختيار هذا الوضع',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8), // Easier to tap
          child: AnimatedContainer(
            duration: Duration(milliseconds: 200),
            width: _width,
            height: _height,
            padding: EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: HesakColors.modesIconCircle,
              borderRadius: BorderRadius.circular(_height / 2),
              border: Border.all(color: isOn ? HesakColors.modesIconCircle : HesakColors.primaryLightBorder, width: 1.3),
            ),
            child: AnimatedAlign(
              duration: Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: isOn ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
              child: Container(
                width: _thumb - 3, // Fits inside the track (padding + border)
                height: _thumb - 3,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOn ? HesakColors.modeSelected : HesakColors.modeHeaderIdleStart.withValues(alpha: 0.55),
                ),
                child: isOn ? Icon(Icons.check_rounded, size: 15, color: HesakColors.onPrimary) : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Strip stuck to the bottom of the selected card while listening is off:
/// ⓘ "اضغط زر الاستماع في الرئيسية لتفعيل الوضع".
class _ModesListenHintStrip extends StatelessWidget {
  const _ModesListenHintStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('modes_listen_hint'),
      padding: EdgeInsets.symmetric(horizontal: HesakSizes.cardPaddingHorizontal, vertical: 10),
      decoration: BoxDecoration(
        color: HesakColors.modesHintStripFill,
        border: Border(top: BorderSide(color: HesakColors.modesHintStripLine)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: HesakColors.modesHintStripText),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'اضغط زر الاستماع في الرئيسية لتفعيل الوضع',
              style: HesakTextStyles.modeHint.copyWith(color: HesakColors.modesHintStripText),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Under the arrow: "إعدادات الوضع" + "جدولة الوضع"
// ---------------------------------------------------------------------

/// White box "إعدادات الوضع": 4 view-only tiles
/// (نوع التنبيه · الأصوات · نداء اسمك · تكرار التنبيه). Changed in تعديل الوضع.
class _ModesDetailsBox extends StatelessWidget {
  final HesakModeConfig mode;

  const _ModesDetailsBox({required this.mode});

  @override
  Widget build(BuildContext context) {
    // Works only when the user has a الاسم للنداء; otherwise it shows as off.
    final bool hasCallName = AuthService.instance.currentCallName != null;
    final List<HesakAlertType> alertTypes = [
      for (final type in HesakAlertType.values)
        if (mode.alertTypes.contains(type)) type,
    ];

    return Container(
      key: Key('modes_details_${mode.id}'),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: HesakColors.modesDetailsFill,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard + 2),
        border: Border.all(color: HesakColors.modesCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('إعدادات الوضع', style: HesakTextStyles.itemTitle.copyWith(color: HesakColors.modeSelected)),
          SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ModesInfoTile(
                    icon: Icons.notifications_active_outlined,
                    label: 'نوع التنبيه',
                    value: alertTypes.isEmpty ? 'لا يوجد' : alertTypes.map((t) => t.label).join(' + '),
                    valueIcons: alertTypes.map((t) => t.icon).toList(),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _ModesInfoTile(
                    icon: Icons.volume_up_outlined,
                    label: 'الأصوات',
                    value: modesSoundsCountText(mode.soundIds.length),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ModesInfoTile(
                    icon: Icons.record_voice_over_outlined,
                    label: 'نداء اسمك',
                    value: hasCallName && mode.isCallNameAlertOn ? 'مفعّل' : 'غير مفعّل',
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: _ModesInfoTile(
                    icon: Icons.repeat_rounded,
                    label: 'تكرار التنبيه',
                    value: mode.alertRepeat.label,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One small view-only tile: icon + label on top, the value under it.
class _ModesInfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value; // Also read by screen readers when icons are shown
  final List<IconData> valueIcons; // When not empty, shown instead of [value]

  const _ModesInfoTile({required this.icon, required this.label, required this.value, this.valueIcons = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: HesakColors.modesInfoTileFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: HesakColors.modesCardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: HesakColors.textSecondary),
              SizedBox(width: 4),
              Flexible(child: Text(label, style: HesakTextStyles.modeHint, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ],
          ),
          SizedBox(height: 4),
          if (valueIcons.isEmpty)
            Text(value, style: HesakTextStyles.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis)
          else
            Semantics(
              label: value,
              excludeSemantics: true,
              child: Row(
                children: [
                  for (int i = 0; i < valueIcons.length; i++) ...[
                    if (i > 0) SizedBox(width: 8),
                    Icon(valueIcons[i], size: 20, color: HesakColors.textPrimary),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "جدولة الوضع ⌄": darker lavender header + how many periods. Tap it to see
/// the periods (add / edit / delete, saved right away) inside the same frame.
class _ModesScheduleBox extends StatefulWidget {
  final HesakModeConfig mode;

  const _ModesScheduleBox({required this.mode});

  @override
  State<_ModesScheduleBox> createState() => _ModesScheduleBoxState();
}

class _ModesScheduleBoxState extends State<_ModesScheduleBox> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final HesakModeConfig mode = widget.mode;
    final radius = BorderRadius.circular(HesakSizes.radiusInnerCard + 2);

    return Container(
      key: Key('modes_schedule_box_${mode.id}'),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: HesakColors.modesScheduleBodyFill, borderRadius: radius),
      // The outline is drawn ON TOP of the header color, so the rounded corners
      // stay one full frame (before, the header color covered the corners).
      foregroundDecoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: HesakColors.modesScheduleBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: HesakColors.modesScheduleHeaderFill,
            child: InkWell(
              key: Key('modes_schedule_toggle_${mode.id}'),
              onTap: () => setState(() => _isOpen = !_isOpen),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(
                  children: [
                    Icon(Icons.calendar_month_outlined, size: 19, color: HesakColors.modeSelected),
                    SizedBox(width: 8),
                    Expanded(child: Text('جدولة الوضع', style: HesakTextStyles.itemTitle)),
                    Text(modesPeriodsCountText(mode.periods.length), style: HesakTextStyles.caption),
                    SizedBox(width: 6),
                    AnimatedRotation(
                      turns: _isOpen ? 0.5 : 0,
                      duration: Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded, color: HesakColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: Duration(milliseconds: 220),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _isOpen
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Divider(height: 1, thickness: 1, color: HesakColors.modesScheduleBorder),
                      Padding(
                        padding: EdgeInsets.all(10),
                        child: ModesScheduleEditor(
                          // New key per mode, so an open edit box doesn't carry over to another mode.
                          key: ValueKey('modes_schedule_${mode.id}'),
                          modeId: mode.id,
                          periods: mode.periods,
                          periodFill: HesakColors.schedulePeriodOnLavenderFill,
                          onChanged: (periods) => HesakModeStore.instance.updateMode(mode.copyWith(periods: periods)),
                        ),
                      ),
                    ],
                  )
                : SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// Last card: "إضافة وضع جديد".
class _ModesAddCard extends StatelessWidget {
  const _ModesAddCard();

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(HesakSizes.radiusCard);
    return Material(
      color: HesakColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: HesakColors.primaryLightBorder, width: 1.3),
      ),
      child: InkWell(
        key: Key('modes_add_card'),
        borderRadius: radius,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ModeEditorScreen()),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: HesakColors.primaryLightBorder, width: 1.5),
                ),
                child: Icon(Icons.add_rounded, color: HesakColors.iconInactive, size: 26),
              ),
              SizedBox(width: 12),
              Text('إضافة وضع جديد', style: HesakTextStyles.modeLink),
            ],
          ),
        ),
      ),
    );
  }
}
