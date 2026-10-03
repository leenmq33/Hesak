import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../core/data/hesak_mode_store.dart';
import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../services/conversation_service.dart';
import '../widgets/hesak_listening_required.dart';
import '../widgets/hesak_page_header.dart';
import 'chats_conversation_screen.dart';
import 'chats_models.dart';
import 'home/home_mode_section.dart';

// =====================================================================
//  HOME PAGE (الرئيسية)
//
//  Layout (top -> bottom):
//    1) Shared header exactly as on the other pages (purple logo + waves +
//       "مرحبًا, رحاب !"). Under it the color slowly turns purple behind the
//       listen button, then slowly back to the lavender page (no hard edge).
//         big listen button + a hint line under it
//    2) Current mode card (light = غير مفعّل, dark purple = مفعّل):
//       its 4 settings always shown, the arrow opens جدولة الوضع
//    3) محادثات اليوم: last 24 hours (scrolls inside the card) + "محادثة جديدة"
//    4) التنبيهات card (last 24 hours)
//
//  NAMING RULES used in this file (so team files never clash):
//  - Everything that belongs to this page starts with "Home".
//  - Important widgets have a unique Key: 'home_<name>'.
//  - Colors / text styles / sizes come ONLY from lib/core/theme.
//
//  This page does NOT build the bottom bar — HesakMainShell does that.
// =====================================================================

/// The home page.
class HomeScreen extends StatelessWidget {
  /// The user's name shown in the greeting ("مرحبًا, رحاب !").
  final String userName;

  /// Opens the المحادثات tab. Not used on the page for now (kept so
  /// main_shell.dart doesn't need to change).
  final VoidCallback? onShowAllChats;

  const HomeScreen({super.key, required this.userName, this.onShowAllChats});

  /// Height of the colored band (header + listen button + hint).
  static const double _bandHeight = 560;

  @override
  Widget build(BuildContext context) {
    final double topInset = MediaQuery.of(context).padding.top; // Status bar

    return ColoredBox(
      color: HesakColors.tabPageBackground,
      child: SingleChildScrollView(
        key: const Key('home_scroll'),
        // Bottom space keeps the last card above the floating nav bar.
        padding: const EdgeInsets.only(bottom: HesakSizes.pageBottomSafeSpace),
        child: Stack(
          children: [
            // Light header -> purple behind the button -> lavender page.
            // Scrolls together with the page.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: topInset + _bandHeight,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: HesakColors.homeListenBandGradient,
                    stops: HesakColors.homeListenBandStops,
                  ),
                ),
              ),
            ),

            Column(
              children: [
                SizedBox(height: topInset),
                // Shared header, same as every page (purple logo + waves).
                HesakPageHeader.greeting(
                  text: userName.isEmpty ? 'مرحبًا !' : 'مرحبًا, $userName !',
                ),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(HesakSizes.pagePadding, 18, HesakSizes.pagePadding, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _HomeListenButton(),
                        const SizedBox(height: 22),
                        const HomeModeSection(),
                        const SizedBox(height: HesakSizes.sectionGap + 4),
                        const _HomeConversationsCard(),
                        const SizedBox(height: HesakSizes.sectionGap + 4),
                        const _HomeAlertsCard(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
//                         LISTEN BUTTON
// =====================================================================

/// Big round button.
/// Before: white button with ONE soft circle around it + "ابدأ الاستماع".
/// After pressing: purple button, white rings spread out, a white arc turns
/// around it, and the current mode becomes مفعّل.
class _HomeListenButton extends StatefulWidget {
  const _HomeListenButton();

  @override
  State<_HomeListenButton> createState() => _HomeListenButtonState();
}

class _HomeListenButtonState extends State<_HomeListenButton> with TickerProviderStateMixin {
  // Soft grow / shrink of the button while listening.
  late final AnimationController _listenPulseController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  // Rings that spread out from the button.
  late final AnimationController _listenRingsController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  // The white arc that turns around the button.
  late final AnimationController _listenArcController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  /// Last listening state we animated for.
  bool _isAnimatingListening = false;

  @override
  void initState() {
    super.initState();
    // Coming back to the page while listening -> keep the animation going.
    _syncAnimationsWithStore();
    // Listening can also be turned on from a conversation ("تشغيل الاستماع").
    HesakModeStore.instance.addListener(_syncAnimationsWithStore);
  }

  void _syncAnimationsWithStore() {
    final bool isListening = HesakModeStore.instance.isListening;
    if (isListening == _isAnimatingListening) return;
    _isAnimatingListening = isListening;
    isListening ? _startAnimations() : _stopAnimations();
  }

  @override
  void dispose() {
    HesakModeStore.instance.removeListener(_syncAnimationsWithStore);
    _listenPulseController.dispose();
    _listenRingsController.dispose();
    _listenArcController.dispose();
    super.dispose();
  }

  void _startAnimations() {
    _listenPulseController.repeat(reverse: true);
    _listenRingsController.repeat();
    _listenArcController.repeat();
  }

  void _stopAnimations() {
    _listenPulseController.animateTo(0, duration: const Duration(milliseconds: 200));
    _listenRingsController
      ..stop()
      ..reset();
    _listenArcController
      ..stop()
      ..reset();
  }

  /// Start or stop listening. The mode card + الأوضاع page follow the store.
  void _toggleListening() {
    // The store tells _syncAnimationsWithStore, which starts / stops the animation.
    HesakModeStore.instance.setListening(!HesakModeStore.instance.isListening);
    // TODO: start / stop the real microphone listening here.
  }

  @override
  Widget build(BuildContext context) {
    const double buttonSize = 184;
    const double areaSize = 280; // Space for the halos / rings

    return ListenableBuilder(
      listenable: HesakModeStore.instance,
      builder: (context, _) {
        final store = HesakModeStore.instance;
        final bool isListening = store.isListening;

        return Column(
          children: [
            SizedBox(
              width: areaSize,
              height: areaSize,
              child: AnimatedBuilder(
                animation: Listenable.merge([_listenPulseController, _listenRingsController, _listenArcController]),
                builder: (context, _) {
                  final double pulseScale = 1 + 0.03 * Curves.easeInOut.transform(_listenPulseController.value);
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (!isListening) ...[
                        // Before pressing: ONE soft circle behind the white button.
                        // The other circles show only after pressing.
                        _buildHalo(buttonSize + 42),
                      ] else ...[
                        for (int i = 0; i < 3; i++) _buildSpreadingRing(buttonSize, areaSize, i),
                        // Turning white arc.
                        Transform.rotate(
                          angle: _listenArcController.value * 2 * math.pi,
                          child: const SizedBox(
                            width: buttonSize + 24,
                            height: buttonSize + 24,
                            child: CircularProgressIndicator(
                              value: 0.25,
                              strokeWidth: 4,
                              strokeCap: StrokeCap.round,
                              color: HesakColors.onPrimary,
                              backgroundColor: HesakColors.homeListenTrack,
                            ),
                          ),
                        ),
                      ],

                      // The button.
                      Transform.scale(
                        scale: isListening ? pulseScale : 1,
                        child: Semantics(
                          button: true,
                          label: isListening ? 'إيقاف الاستماع' : 'ابدأ الاستماع',
                          child: GestureDetector(
                            key: const Key('home_listen_button'),
                            onTap: _toggleListening,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              width: buttonSize,
                              height: buttonSize,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isListening
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: HesakColors.homeListenButtonActive,
                                      )
                                    : const RadialGradient(
                                        center: Alignment(0, -0.3),
                                        colors: HesakColors.homeListenButtonIdle,
                                        stops: [0.0, 0.7, 1.0],
                                      ),
                                border: Border.all(
                                  color: isListening ? HesakColors.onModeHeaderSoft : HesakColors.onPrimary,
                                  width: isListening ? 3 : 1.5,
                                ),
                                boxShadow: const [
                                  BoxShadow(color: HesakColors.homeListenShadow, blurRadius: 36, offset: Offset(0, 16)),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 250),
                                child: isListening ? _buildListeningContent() : _buildIdleContent(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            // Hint under the button: tells the user the mode turns on with listening.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Text(
                isListening
                    ? 'حِسّك يستمع الآن ووضع ${store.selectedMode.name} مفعّل'
                    : 'اضغط لبدء الاستماع وتفعيل الوضع',
                key: ValueKey('home_listen_hint_$isListening'),
                textAlign: TextAlign.center,
                style: HesakTextStyles.body.copyWith(color: HesakColors.primary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIdleContent() {
    return Column(
      key: const ValueKey('home_listen_idle'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.mic_none_rounded, size: 52, color: HesakColors.primary),
        const SizedBox(height: 6),
        Text('ابدأ الاستماع', style: HesakTextStyles.cardTitle.copyWith(color: HesakColors.primary)),
      ],
    );
  }

  Widget _buildListeningContent() {
    return Column(
      key: const ValueKey('home_listen_on'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.graphic_eq_rounded, size: 52, color: HesakColors.onPrimary),
        const SizedBox(height: 4),
        Text('يستمع…', style: HesakTextStyles.cardTitle.copyWith(color: HesakColors.onPrimary)),
        const SizedBox(height: 2),
        const Text('اضغط للإيقاف', style: HesakTextStyles.modeHeaderSubtitle),
      ],
    );
  }

  /// A still, see-through white circle behind the white button.
  Widget _buildHalo(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: HesakColors.homeHaloFill,
        border: Border.all(color: HesakColors.homeHaloBorder),
      ),
    );
  }

  /// One white ring that grows and fades. [i] shifts its timing.
  Widget _buildSpreadingRing(double buttonSize, double areaSize, int i) {
    final double progress = (_listenRingsController.value + i / 3) % 1.0;
    final double ringSize = buttonSize + (areaSize - buttonSize) * progress;
    return Container(
      width: ringSize,
      height: ringSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: HesakColors.onPrimary.withOpacity(0.5 * (1 - progress)), width: 2),
      ),
    );
  }
}

// =====================================================================
//                         SHARED CARD
// =====================================================================

/// White rounded card: title (+ optional thing on the left), then content.
class _HomeSectionCard extends StatelessWidget {
  final String title;
  final Widget? trailing; // Shown on the left of the title ("عرض الكل", "آخر 24 ساعة")
  final Widget child;

  const _HomeSectionCard({super.key, required this.title, this.trailing, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        HesakSizes.cardPaddingHorizontal,
        HesakSizes.cardPaddingTop,
        HesakSizes.cardPaddingHorizontal,
        HesakSizes.cardPaddingBottom,
      ),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        border: Border.all(color: HesakColors.surfaceBorder),
        boxShadow: [
          BoxShadow(color: HesakColors.primary.withOpacity(0.07), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: HesakTextStyles.cardTitle)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

// =====================================================================
//                         CONVERSATIONS CARD
// =====================================================================

/// "محادثات اليوم": the conversations of the last 24 hours (saved and not
/// saved), newest first. The card has a fixed height: the list scrolls
/// inside it. Each row has "كمّل". "محادثة جديدة" starts a new one.
class _HomeConversationsCard extends StatefulWidget {
  const _HomeConversationsCard();

  @override
  State<_HomeConversationsCard> createState() => _HomeConversationsCardState();
}

class _HomeConversationsCardState extends State<_HomeConversationsCard> {
  /// All the user's conversations (used for the next "محادثة 0X" number too).
  List<ChatsConversation> _allConversations = <ChatsConversation>[];

  /// Max height of the list inside the card: ~2 rows, the rest scrolls.
  static const double _listMaxHeight = 148;

  /// Scrolls the list inside the card (also drives the scrollbar).
  final ScrollController _listScrollController = ScrollController();

  @override
  void dispose() {
    ConversationService.instance.changeCount.removeListener(_loadConversations);
    _listScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Reload when a conversation is saved / deleted on the المحادثات page.
    ConversationService.instance.changeCount.addListener(_loadConversations);
  }

  /// true when loading failed (e.g. no internet) and nothing is shown yet.
  bool _hasLoadFailed = false;

  Future<void> _loadConversations() async {
    final List<ChatsConversation>? loaded = await ConversationService.instance.loadConversations();
    if (!mounted) return;
    setState(() {
      _hasLoadFailed = loaded == null;
      if (loaded != null) _allConversations = loaded; // Failed -> keep the old list
    });
  }

  /// Last 24 hours only, newest first.
  List<ChatsConversation> get _todayConversations {
    final DateTime since = DateTime.now().subtract(const Duration(hours: 24));
    final List<ChatsConversation> today = _allConversations.where((c) => c.displayTime.isAfter(since)).toList()
      ..sort((a, b) => b.displayTime.compareTo(a.displayTime));
    return today;
  }

  /// Opens a conversation full screen (above the bottom bar), then saves it.
  Future<void> _openConversation(ChatsConversation conversation) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(builder: (_) => ChatsConversationScreen(conversation: conversation)),
    );
    if (conversation.hasStartedListening || conversation.messages.isNotEmpty) {
      await ConversationService.instance.saveConversation(conversation);
    }
    // The list reloads by itself (ConversationService.changeCount).
  }

  /// Works only while listening is on; otherwise the shared window asks to
  /// turn it on. The number "محادثة NN" is never reused (ConversationService).
  Future<void> _startNewConversation() async {
    if (!await hesakRequireListening(context)) return;
    final ChatsConversation conversation =
        await ConversationService.instance.createNewConversation(_allConversations);
    if (!mounted) return;
    _openConversation(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatsConversation> today = _todayConversations;

    return _HomeSectionCard(
      key: const Key('home_conversations_card'),
      title: 'محادثات اليوم',
      // How many conversations today, e.g. "(5)".
      trailing: today.isEmpty ? null : Text('(${today.length})', style: HesakTextStyles.caption),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (today.isEmpty && _hasLoadFailed)
            // No internet / Firebase error: tap to try again.
            InkWell(
              key: const Key('home_conversations_retry'),
              onTap: _loadConversations,
              borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'تعذّر تحميل المحادثات، اضغط لإعادة المحاولة',
                  textAlign: TextAlign.center,
                  style: HesakTextStyles.caption.copyWith(color: HesakColors.urgent),
                ),
              ),
            )
          else if (today.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('لا توجد محادثات خلال 24 ساعة', textAlign: TextAlign.center, style: HesakTextStyles.caption),
            )
          else
            // Fixed box: never grows. Scroll inside it to see the rest.
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _listMaxHeight),
              child: Scrollbar(
                controller: _listScrollController,
                thumbVisibility: today.length > 2, // Shows there is more to scroll
                radius: const Radius.circular(4),
                child: Padding(
                  // Room for the scrollbar on the side.
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: ListView.separated(
                    key: const Key('home_conversations_list'),
                    controller: _listScrollController,
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: today.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) => _HomeConversationRow(
                      conversation: today[i],
                      onTap: () => _openConversation(today[i]),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              key: const Key('home_conversation_new'),
              onPressed: _startNewConversation,
              style: ElevatedButton.styleFrom(
                backgroundColor: HesakColors.primary,
                foregroundColor: HesakColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.add_rounded, size: 22),
              label: Text('محادثة جديدة', style: HesakTextStyles.cardTitle.copyWith(color: HesakColors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// One conversation row: icon · title · "قبل ساعة · محفوظة / تُحذف بعد 22:10:05".
/// The whole row opens the conversation.
class _HomeConversationRow extends StatelessWidget {
  final ChatsConversation conversation;
  final VoidCallback onTap;

  const _HomeConversationRow({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bool isSaved = conversation.isSaved;
    return Material(
      color: HesakColors.modeTileSelectedFill,
      borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(HesakSizes.radiusInnerCard),
        child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: HesakSizes.iconBox,
            height: HesakSizes.iconBox,
            decoration: BoxDecoration(
              color: HesakColors.primaryLight,
              borderRadius: BorderRadius.circular(HesakSizes.radiusIconBox),
            ),
            child: const Icon(Icons.chat_outlined, size: HesakSizes.iconInBox, color: HesakColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(conversation.title, style: HesakTextStyles.itemTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: '${_homeTimeAgo(conversation.displayTime)} · ', style: HesakTextStyles.caption),
                      TextSpan(
                        text: isSaved ? 'محفوظة' : 'تُحذف بعد ${chatsFormatTimeLeft(conversation.timeUntilAutoDelete)}',
                        style: isSaved
                            ? HesakTextStyles.caption.copyWith(color: HesakColors.primary, fontWeight: FontWeight.w600)
                            : HesakTextStyles.caption,
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// "الآن" / "قبل 5 د" / "قبل ساعة" / "قبل 3 ساعات" / "أمس" / "قبل 4 أيام".
String _homeTimeAgo(DateTime time) {
  final Duration diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours == 1) return 'قبل ساعة';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعات';
  if (diff.inDays == 1) return 'أمس';
  return 'قبل ${diff.inDays} أيام';
}

// =====================================================================
//                         ALERTS CARD
// =====================================================================

/// "التنبيهات": recent alerts (last 24 hours). Urgent ones are red.
class _HomeAlertsCard extends StatelessWidget {
  const _HomeAlertsCard();

  @override
  Widget build(BuildContext context) {
    // TODO: real alerts from the listening service.
    return const _HomeSectionCard(
      key: Key('home_alerts_card'),
      title: 'التنبيهات',
      trailing: Text('آخر 24 ساعة', style: HesakTextStyles.caption),
      child: Column(
        children: [
          _HomeAlertTile(
            icon: Icons.warning_amber_rounded,
            title: 'إنذار حريق',
            subtitle: 'تم رصد صوت إنذار حريق',
            time: 'الآن',
            isUrgent: true,
          ),
          Divider(height: 18, thickness: 0.8, color: HesakColors.listDivider),
          _HomeAlertTile(
            icon: Icons.child_care_outlined,
            title: 'بكاء طفل',
            subtitle: 'تم رصد صوت بكاء طفل',
            time: 'منذ ساعة',
          ),
          Divider(height: 18, thickness: 0.8, color: HesakColors.listDivider),
          _HomeAlertTile(
            icon: Icons.notifications_none_rounded,
            title: 'جرس الباب',
            subtitle: 'تم رصد صوت جرس الباب',
            time: 'منذ 3 ساعات',
          ),
        ],
      ),
    );
  }
}

/// One alert row: icon box, title + subtitle, time.
class _HomeAlertTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String time;
  final bool isUrgent; // Red icon box + red time

  const _HomeAlertTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
    this.isUrgent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: HesakSizes.iconBox,
          height: HesakSizes.iconBox,
          decoration: BoxDecoration(
            color: isUrgent ? HesakColors.homeUrgentIconFill : HesakColors.primaryLight,
            borderRadius: BorderRadius.circular(HesakSizes.radiusIconBox),
          ),
          child: Icon(icon, size: HesakSizes.iconInBox, color: isUrgent ? HesakColors.urgent : HesakColors.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: HesakTextStyles.itemTitle),
              const SizedBox(height: 2),
              Text(subtitle, style: HesakTextStyles.body),
            ],
          ),
        ),
        Text(time, style: isUrgent ? HesakTextStyles.captionUrgent : HesakTextStyles.caption),
      ],
    );
  }
}