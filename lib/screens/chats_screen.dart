// ============================================================================
// NAMING RULES (Chats page)
// - Private classes in this file start with "_Chats" (e.g. _ChatsSearchBar).
// - Public classes shared between the chats files start with "Chats".
// - Keys follow page_element: chats_... (see the Keys list in the guide).
// - Booleans start with "is" / "has". Functions describe what they do.
// - Colors / text styles / sizes come ONLY from lib/core/theme.
//   No Color(0x...) and no fontSize in this file.
// - Spelling: hesak (not heask).
// ============================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import '../widgets/hesak_confirm_dialog.dart';
import '../widgets/hesak_listening_required.dart';
import '../widgets/hesak_page_header.dart';
import '../widgets/hesak_toast.dart';
import 'settings/settings_widgets.dart';
import 'chats_conversation_screen.dart';
import 'chats_models.dart';
import '../services/conversation_service.dart';

/// The Chats tab. HesakMainShell shows it and draws the bottom bar.
///
/// The shared header stays fixed at the top; only the list under it
/// scrolls (the list is inside Expanded in _ChatsPageContent).
class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // SafeArea (like الأوضاع / الإعدادات) so the header sits at exactly
    // the same height on every tab.
    return SafeArea(
      bottom: false,
      child: Column(
        children: <Widget>[
          HesakPageHeader(title: 'المحادثات'),
          Expanded(child: _ChatsPageContent()),
        ],
      ),
    );
  }
}

/// Which conversations the list shows.
enum _ChatsFilterTab { all, saved }

/// Date order of the list.
enum _ChatsSortOrder { newestFirst, oldestFirst }

/// Actions in a card's (…) menu.
enum _ChatsCardAction { rename, delete }

/// Shared card shadow from the guide: primary at 6%, blur 16, 4 down.
List<BoxShadow> get _chatsCardShadow => <BoxShadow>[
  BoxShadow(
    color: HesakColors.primary.withValues(alpha: 0.06),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
];

/// Everything under the page header: filter, search, sort, notice, list,
/// and the "محادثة جديدة" button.
class _ChatsPageContent extends StatefulWidget {
  const _ChatsPageContent();

  @override
  State<_ChatsPageContent> createState() => _ChatsPageContentState();
}

class _ChatsPageContentState extends State<_ChatsPageContent> {
  /// Conversations loaded from Firestore (users/{uid}/conversations).
  final List<ChatsConversation> _conversations = <ChatsConversation>[];

  /// True while the list is loading from Firestore.
  bool _isLoading = true;

  /// True when loading failed (e.g. no internet) -> "إعادة المحاولة".
  bool _hasLoadFailed = false;

  final TextEditingController _searchController = TextEditingController();

  _ChatsFilterTab _selectedFilterTab = _ChatsFilterTab.all;
  _ChatsSortOrder _selectedSortOrder = _ChatsSortOrder.newestFirst;
  String _searchQuery = '';

  /// Ticks every minute so "تُحذف بعد 17 ساعة" stays right.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    // Reload when a conversation is saved / deleted from another page (الرئيسية).
    ConversationService.instance.changeCount.addListener(_reloadQuietly);
    _countdownTimer = Timer.periodic(
      Duration(minutes: 1),
          (_) => _refreshCountdowns(),
    );
  }

  /// Reload without the spinner (the list stays on screen meanwhile).
  Future<void> _reloadQuietly() async {
    final List<ChatsConversation>? loaded =
        await ConversationService.instance.loadConversations();
    if (!mounted || loaded == null) return;
    setState(() {
      _hasLoadFailed = false;
      _conversations
        ..clear()
        ..addAll(loaded);
    });
  }

  @override
  void dispose() {
    ConversationService.instance.changeCount.removeListener(_reloadQuietly);
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the user's conversations from Firestore.
  Future<void> _loadConversations() async {
    setState(() {
      _isLoading = true;
      _hasLoadFailed = false;
    });
    final List<ChatsConversation>? loaded =
        await ConversationService.instance.loadConversations();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (loaded == null) {
        _hasLoadFailed = true; // Keep what is already on screen (if any)
        return;
      }
      _conversations
        ..clear()
        ..addAll(loaded);
    });
  }

  /// Rebuilds the countdowns and drops unsaved conversations whose
  /// 24 hours are over (also deletes them from Firestore).
  void _refreshCountdowns() {
    if (!mounted) return;
    setState(() {
      _conversations.removeWhere((c) {
        final bool isExpired = !c.isSaved &&
            c.hasStartedListening &&
            c.timeUntilAutoDelete == Duration.zero;
        if (isExpired) ConversationService.instance.deleteConversation(c.id);
        return isExpired;
      });
    });
  }

  /// Conversations after filter tab, search and date order.
  List<ChatsConversation> get _visibleConversations {
    final String query = _searchQuery.trim();
    final List<ChatsConversation> result = _conversations.where((c) {
      if (_selectedFilterTab == _ChatsFilterTab.saved && !c.isSaved) {
        return false;
      }
      if (query.isNotEmpty && !c.title.contains(query)) return false;
      return true;
    }).toList();

    result.sort((a, b) => _selectedSortOrder == _ChatsSortOrder.newestFirst
        ? b.displayTime.compareTo(a.displayTime)
        : a.displayTime.compareTo(b.displayTime));
    return result;
  }

  /// Saves / un-saves a conversation. Saved ones appear under "المحفوظة".
  void _toggleConversationSaved(ChatsConversation conversation) {
    setState(() => conversation.isSaved = !conversation.isSaved);
    ConversationService.instance.saveConversation(conversation);
    // Same messages as inside the conversation.
    showHesakToast(
      context,
      conversation.isSaved ? 'تم حفظ المحادثة' : 'تم إلغاء حفظ المحادثة',
      icon: conversation.isSaved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
    );
  }

  /// Opens the rename dialog and applies the new title.
  /// Same sheet as editing the name in الإعدادات (rises from the bottom).
  /// "حفظ" stays grey until the name really changes.
  Future<void> _renameConversation(ChatsConversation conversation) {
    return showSettingsNameSheet(
      context,
      title: 'تعديل اسم المحادثة',
      note: null,
      fieldLabel: 'الاسم:',
      hint: 'اسم المحادثة',
      initialValue: conversation.title,
      problemOf: (_) => null, // Any text is OK (numbers too, e.g. "محادثة 38")
      onSave: (newTitle) async {
        if (!mounted) return false;
        setState(() {
          conversation.title = newTitle;
          conversation.markEdited(); // Renaming = a change -> moves to the top
        });
        ConversationService.instance.saveConversation(conversation);
        showHesakToast(context, 'تم تغيير اسم المحادثة');
        return true;
      },
    );
  }

  /// Asks for confirmation, then removes the conversation.
  Future<void> _deleteConversation(ChatsConversation conversation) async {
    final bool isConfirmed = await showHesakConfirmDialog(
      context,
      title: 'هل تريد حذف «${conversation.title}»؟',
      message: 'ستُحذف المحادثة نهائيًا ولا يمكن استعادتها',
      confirmLabel: 'حذف',
      icon: Icons.delete_outline_rounded,
    );
    if (!isConfirmed || !mounted) return;
    ConversationService.instance.deleteConversation(conversation.id);
    setState(() => _conversations.remove(conversation));
    showHesakToast(context, 'تم حذف المحادثة', icon: Icons.delete_outline_rounded);
  }

  /// Opens a conversation full screen (above the bottom bar, which must
  /// not show inside a conversation).
  Future<void> _openConversation(ChatsConversation conversation) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatsConversationScreen(conversation: conversation),
      ),
    );
    if (!mounted) return;
    setState(() {
      // A new conversation that never started and has no messages is dropped.
      // (Its number is not used up: numbers are saved only when used.)
      if (!conversation.hasStartedListening && conversation.messages.isEmpty) {
        _conversations.remove(conversation);
      }
    });
    // Save everything that happened inside the conversation.
    if (conversation.hasStartedListening || conversation.messages.isNotEmpty) {
      ConversationService.instance.saveConversation(conversation);
    }
  }

  /// Creates an empty conversation and opens it (shows the start card).
  /// Works only while listening is on (otherwise the shared window asks
  /// to turn it on). The number is never reused (see ConversationService).
  Future<void> _startNewConversation() async {
    if (!await hesakRequireListening(context)) return;
    final ChatsConversation conversation =
        await ConversationService.instance.createNewConversation(_conversations);
    if (!mounted) return;
    // TODO: AI suggests a name after a few messages.
    setState(() => _conversations.add(conversation));
    _openConversation(conversation);
  }

  @override
  Widget build(BuildContext context) {
    final List<ChatsConversation> visible = _visibleConversations;
    final bool isAllTab = _selectedFilterTab == _ChatsFilterTab.all;

    return Stack(
      children: <Widget>[
        Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                HesakSizes.pagePadding,
                16, // breathing room under the header divider
                HesakSizes.pagePadding,
                0,
              ),
              child: Column(
                children: <Widget>[
                  _ChatsFilterTabs(
                    selectedTab: _selectedFilterTab,
                    onTabSelected: (tab) =>
                        setState(() => _selectedFilterTab = tab),
                  ),
                  SizedBox(height: HesakSizes.sectionGap),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ChatsSearchBar(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      SizedBox(width: 10),
                      _ChatsSortButton(
                        selectedOrder: _selectedSortOrder,
                        onOrderSelected: (order) =>
                            setState(() => _selectedSortOrder = order),
                      ),
                    ],
                  ),
                  // The 24h notice is now the first item of the list
                  // (it scrolls away with the conversations).
                ],
              ),
            ),
            Expanded(
              child: _isLoading && _conversations.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(color: HesakColors.primary))
                  : _hasLoadFailed && _conversations.isEmpty
                  ? _ChatsLoadFailedState(onRetry: _loadConversations)
                  : visible.isEmpty
                  ? Column(
                      children: <Widget>[
                        if (isAllTab)
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              HesakSizes.pagePadding,
                              HesakSizes.sectionGap,
                              HesakSizes.pagePadding,
                              0,
                            ),
                            child: _ChatsExpiryNotice(),
                          ),
                        Expanded(
                          child: _ChatsEmptyState(
                            isSearching: _searchQuery.isNotEmpty,
                            isAllTab: isAllTab,
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                key: Key('chats_conversations_list'),
                padding: EdgeInsets.fromLTRB(
                  HesakSizes.pagePadding,
                  HesakSizes.sectionGap,
                  HesakSizes.pagePadding,
                  // Bar space + room so the last card clears the
                  // "محادثة جديدة" button.
                  HesakSizes.pageBottomSafeSpace + 70,
                ),
                // On "الكل" the 24h notice is item 0, so it scrolls away.
                itemCount: visible.length + (isAllTab ? 1 : 0),
                separatorBuilder: (_, __) =>
                SizedBox(height: HesakSizes.sectionGap),
                itemBuilder: (_, index) {
                  if (isAllTab && index == 0) return _ChatsExpiryNotice();
                  final ChatsConversation conversation =
                  visible[isAllTab ? index - 1 : index];
                  return _ChatsConversationCard(
                    conversation: conversation,
                    onOpen: () => _openConversation(conversation),
                    onToggleSaved: () =>
                        _toggleConversationSaved(conversation),
                    onRename: () =>
                        _renameConversation(conversation),
                    onDelete: () =>
                        _deleteConversation(conversation),
                  );
                },
              ),
            ),
          ],
        ),
        Positioned(
          // Centred right above the "الإعدادات" tab of the bottom bar:
          // bar side padding 14 + half the 62px tab - half the 52px button.
          left: 19,
          // Sits just above the top edge of the bottom bar.
          // TODO: tweak by a few px on real devices (bigger = higher).
          bottom: 90,
          child: _ChatsNewConversationButton(onPressed: _startNewConversation),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Filter tabs: الكل / المحفوظة
// ---------------------------------------------------------------------------

/// Pill switch between all and saved conversations.
class _ChatsFilterTabs extends StatelessWidget {
  const _ChatsFilterTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final _ChatsFilterTab selectedTab;
  final ValueChanged<_ChatsFilterTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('chats_filter_tabs'),
      padding: EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HesakColors.navBar,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
      ),
      child: Row(
        children: <Widget>[
          _ChatsFilterTabButton(
            key: Key('chats_filter_all_tab'),
            label: 'الكل',
            isSelected: selectedTab == _ChatsFilterTab.all,
            onTap: () => onTabSelected(_ChatsFilterTab.all),
          ),
          SizedBox(width: 4),
          _ChatsFilterTabButton(
            key: Key('chats_filter_saved_tab'),
            label: 'المحفوظة',
            isSelected: selectedTab == _ChatsFilterTab.saved,
            onTap: () => onTabSelected(_ChatsFilterTab.saved),
          ),
        ],
      ),
    );
  }
}

/// One half of [_ChatsFilterTabs].
class _ChatsFilterTabButton extends StatelessWidget {
  const _ChatsFilterTabButton({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 180),
            height: 40, // 40 + 4 padding each side = 48 touch height
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? HesakColors.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: isSelected
                  ? <BoxShadow>[
                BoxShadow(
                  color: HesakColors.primary.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ]
                  : null,
            ),
            child: Text(
              label,
              style: HesakTextStyles.itemTitle.copyWith(
                color: isSelected
                    ? HesakColors.primaryDark
                    : HesakColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search + sort
// ---------------------------------------------------------------------------

/// Search by conversation title.
class _ChatsSearchBar extends StatelessWidget {
  const _ChatsSearchBar({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48, // matches the sort button
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
        boxShadow: _chatsCardShadow,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.search_rounded,
            size: HesakSizes.iconInChip + 3,
            color: HesakColors.textSecondary,
          ),
          SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: Key('chats_search_bar'),
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: HesakTextStyles.itemTitle
                  .copyWith(fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'ابحث بعنوان المحادثة…',
                hintStyle: HesakTextStyles.itemTitle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: HesakColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens a small menu: newest → oldest, or oldest → newest (by date).
class _ChatsSortButton extends StatelessWidget {
  const _ChatsSortButton({
    required this.selectedOrder,
    required this.onOrderSelected,
  });

  final _ChatsSortOrder selectedOrder;
  final ValueChanged<_ChatsSortOrder> onOrderSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatsSortOrder>(
      key: Key('chats_sort_button'),
      tooltip: 'ترتيب حسب التاريخ',
      onSelected: onOrderSelected,
      color: HesakColors.surface,
      elevation: 8,
      shadowColor: HesakColors.primary.withValues(alpha: 0.3),
      offset: Offset(0, 56), // opens just under the button
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: HesakColors.surfaceBorder),
      ),
      itemBuilder: (_) => <PopupMenuEntry<_ChatsSortOrder>>[
        PopupMenuItem<_ChatsSortOrder>(
          enabled: false,
          height: 32,
          child: Text('ترتيب حسب التاريخ', style: HesakTextStyles.caption
              .copyWith(color: HesakColors.textSecondary)),
        ),
        _buildSortItem(
          key: Key('chats_sort_newest_option'),
          order: _ChatsSortOrder.newestFirst,
          label: 'من الأحدث للأقدم',
        ),
        _buildSortItem(
          key: Key('chats_sort_oldest_option'),
          order: _ChatsSortOrder.oldestFirst,
          label: 'من الأقدم للأحدث',
        ),
      ],
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: HesakColors.surface,
          border: Border.all(color: HesakColors.surfaceBorder),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _chatsCardShadow,
        ),
        child: Icon(
          Icons.swap_vert_rounded,
          size: HesakSizes.iconInBox,
          color: HesakColors.primary,
        ),
      ),
    );
  }

  /// One option in the sort menu, with a check when selected.
  PopupMenuItem<_ChatsSortOrder> _buildSortItem({
    required Key key,
    required _ChatsSortOrder order,
    required String label,
  }) {
    final bool isSelected = order == selectedOrder;
    return PopupMenuItem<_ChatsSortOrder>(
      key: key,
      value: order,
      height: 48,
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label, style: HesakTextStyles.itemTitle)),
          if (isSelected)
            Icon(
              Icons.check_rounded,
              size: HesakSizes.iconInChip + 3,
              color: HesakColors.primaryMuted,
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notices
// ---------------------------------------------------------------------------

/// "المحادثات تُحذف بعد 24 ساعة" — shown on the "الكل" tab.
class _ChatsExpiryNotice extends StatelessWidget {
  const _ChatsExpiryNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('chats_expiry_note'),
      padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HesakColors.urgent.withValues(alpha: 0.05),
        border: Border.all(color: HesakColors.urgent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.info_outline_rounded,
            size: HesakSizes.iconInChip + 3,
            color: HesakColors.urgent,
          ),
          SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                // All the text is red, like the box (no full stop).
                style: HesakTextStyles.body.copyWith(
                  color: HesakColors.urgent,
                  height: 1.6,
                ),
                children: <InlineSpan>[
                  TextSpan(text: 'تُحذف المحادثات تلقائيًا بعد '),
                  TextSpan(
                    text: '24 ساعة',
                    style: HesakTextStyles.captionUrgent,
                  ),
                  TextSpan(text: '، احفظ ما يهمك بزر الحفظ'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Conversation card
// ---------------------------------------------------------------------------

/// One row in the list: icon, title, date, time, time left, (…) and save.
class _ChatsConversationCard extends StatelessWidget {
  const _ChatsConversationCard({
    required this.conversation,
    required this.onOpen,
    required this.onToggleSaved,
    required this.onRename,
    required this.onDelete,
  });

  final ChatsConversation conversation;
  final VoidCallback onOpen;
  final VoidCallback onToggleSaved;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final bool isSaved = conversation.isSaved;

    return Container(
      key: Key('chats_conversation_card_${conversation.id}'),
      decoration: BoxDecoration(
        // Lavender on the icon side, fading to light on the other side.
        gradient: LinearGradient(
          begin: AlignmentDirectional.centerStart,
          end: AlignmentDirectional.centerEnd,
          colors: HesakColors.chatsCardGradient,
        ),
        border: Border.all(color: HesakColors.chatsCardBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        boxShadow: _chatsCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              HesakSizes.cardPaddingHorizontal,
              HesakSizes.cardPaddingTop,
              6, // the (…) and save buttons already have their own padding
              HesakSizes.cardPaddingBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Dark purple circle with a light chat icon.
                Container(
                  width: HesakSizes.iconBox,
                  height: HesakSizes.iconBox,
                  decoration: BoxDecoration(
                    color: HesakColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.chat_outlined,
                    size: HesakSizes.iconInBox,
                    color: HesakColors.onHomeGlass,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        conversation.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: HesakTextStyles.cardTitle,
                      ),
                      SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: <Widget>[
                          _ChatsMetaItem(
                            icon: Icons.calendar_today_outlined,
                            text: chatsFormatDate(conversation.displayTime),
                          ),
                          _ChatsMetaItem(
                            icon: Icons.schedule_rounded,
                            text: chatsFormatTime(conversation.displayTime),
                          ),
                          if (!isSaved && conversation.hasStartedListening)
                            Text(
                              'تُحذف بعد ${chatsFormatTimeLeft(conversation.timeUntilAutoDelete)}',
                              style: HesakTextStyles.caption, // Grey, not red
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: <Widget>[
                    _ChatsCardMenuButton(
                      conversationTitle: conversation.title,
                      onRename: onRename,
                      onDelete: onDelete,
                    ),
                    IconButton(
                      key: Key('chats_card_save_button_${conversation.id}'),
                      tooltip: isSaved ? 'إلغاء حفظ المحادثة' : 'حفظ المحادثة',
                      onPressed: onToggleSaved,
                      icon: Icon(
                        isSaved
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_add_outlined,
                        size: HesakSizes.iconInBox,
                        color: isSaved
                            ? HesakColors.primaryMuted
                            : HesakColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small icon + text used for date and time on the card.
class _ChatsMetaItem extends StatelessWidget {
  const _ChatsMetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(icon, size: 14, color: HesakColors.textSecondary),
        SizedBox(width: 4),
        // textSecondary instead of textMuted: easier to read for our users.
        Text(text,
            style:
            HesakTextStyles.caption.copyWith(color: HesakColors.textSecondary)),
      ],
    );
  }
}

/// The (…) menu on a card: تعديل الاسم / حذف المحادثة.
class _ChatsCardMenuButton extends StatelessWidget {
  const _ChatsCardMenuButton({
    required this.conversationTitle,
    required this.onRename,
    required this.onDelete,
  });

  final String conversationTitle;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ChatsCardAction>(
      key: Key('chats_card_menu_button'),
      tooltip: 'خيارات المحادثة: $conversationTitle',
      icon: Icon(
        Icons.more_horiz_rounded,
        size: HesakSizes.iconInBox,
        color: HesakColors.primary,
      ),
      color: HesakColors.surface,
      elevation: 8,
      shadowColor: HesakColors.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: HesakColors.surfaceBorder),
      ),
      onSelected: (action) {
        switch (action) {
          case _ChatsCardAction.rename:
            onRename();
          case _ChatsCardAction.delete:
            onDelete();
        }
      },
      itemBuilder: (_) => <PopupMenuEntry<_ChatsCardAction>>[
        PopupMenuItem<_ChatsCardAction>(
          key: Key('chats_card_menu_rename'),
          value: _ChatsCardAction.rename,
          height: 48,
          child: Row(
            children: <Widget>[
              Icon(Icons.edit_outlined,
                  size: HesakSizes.iconInChip + 3, color: HesakColors.primary),
              SizedBox(width: 10),
              Text('تعديل الاسم', style: HesakTextStyles.itemTitle),
            ],
          ),
        ),
        PopupMenuDivider(height: 8),
        PopupMenuItem<_ChatsCardAction>(
          key: Key('chats_card_menu_delete'),
          value: _ChatsCardAction.delete,
          height: 48,
          child: Row(
            children: <Widget>[
              Icon(Icons.delete_outline_rounded,
                  size: HesakSizes.iconInChip + 3, color: HesakColors.urgent),
              SizedBox(width: 10),
              Text('حذف المحادثة',
                  style: HesakTextStyles.itemTitle
                      .copyWith(color: HesakColors.urgent)),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state + new conversation button
// ---------------------------------------------------------------------------

/// Shown when the filter / search returns nothing.
class _ChatsEmptyState extends StatelessWidget {
  const _ChatsEmptyState({required this.isSearching, required this.isAllTab});

  final bool isSearching;

  /// "الكل" = conversations of the last 24 hours (+ saved ones).
  final bool isAllTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        HesakSizes.pagePadding,
        40,
        HesakSizes.pagePadding,
        HesakSizes.pageBottomSafeSpace,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HesakColors.primaryLight,
              shape: BoxShape.circle,
              border: Border.all(color: HesakColors.primaryLightBorder),
            ),
            child: Icon(
              isSearching
                  ? Icons.search_rounded
                  : isAllTab
                  ? Icons.chat_bubble_outline_rounded
                  : Icons.bookmark_border_rounded,
              size: HesakSizes.iconInBox + 3,
              color: HesakColors.primaryMuted,
            ),
          ),
          SizedBox(height: 12),
          Text(
            isSearching
                ? 'لا توجد نتائج'
                : isAllTab
                ? 'لا توجد محادثات خلال 24 ساعة'
                : 'لا توجد محادثات محفوظة',
            style: HesakTextStyles.cardTitle,
          ),
          SizedBox(height: 6),
          Text(
            isSearching
                ? 'جرّب كلمة أخرى أو امسح البحث'
                : isAllTab
                ? 'ابدأ محادثة جديدة من زر الإضافة'
                : 'اضغط زر الحفظ في أي محادثة لتبقى محفوظة لديك',
            textAlign: TextAlign.center,
            style: HesakTextStyles.body.copyWith(height: 1.6),
          ),
        ],
      ),
    );
  }
}

/// Loading failed (e.g. no internet): message + "إعادة المحاولة".
class _ChatsLoadFailedState extends StatelessWidget {
  const _ChatsLoadFailedState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('chats_load_failed'),
      padding: EdgeInsets.fromLTRB(
        HesakSizes.pagePadding,
        40,
        HesakSizes.pagePadding,
        HesakSizes.pageBottomSafeSpace,
      ),
      child: Column(
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HesakColors.urgent.withValues(alpha: 0.07),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded,
                size: HesakSizes.iconInBox + 3, color: HesakColors.urgent),
          ),
          SizedBox(height: 12),
          Text('تعذّر تحميل المحادثات', style: HesakTextStyles.cardTitle),
          SizedBox(height: 6),
          Text(
            'تحقّق من اتصالك بالإنترنت ثم أعد المحاولة',
            textAlign: TextAlign.center,
            style: HesakTextStyles.body.copyWith(height: 1.6),
          ),
          SizedBox(height: 16),
          SizedBox(
            height: 46,
            child: TextButton.icon(
              key: Key('chats_retry_button'),
              onPressed: onRetry,
              style: TextButton.styleFrom(
                backgroundColor: HesakColors.primary,
                foregroundColor: HesakColors.onPrimary,
                shape: StadiumBorder(),
                padding: EdgeInsets.symmetric(horizontal: 22),
              ),
              icon: Icon(Icons.refresh_rounded, size: HesakSizes.iconInChip + 3),
              label: Text('إعادة المحاولة',
                  style: HesakTextStyles.itemTitle.copyWith(color: HesakColors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Round purple "+" button (same gradient as the bar's centre button).
/// No label on screen; the screen-reader label says "محادثة جديدة".
class _ChatsNewConversationButton extends StatelessWidget {
  const _ChatsNewConversationButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'محادثة جديدة',
      child: GestureDetector(
        key: Key('chats_new_button'),
        onTap: onPressed,
        child: Container(
          width: 52, // comfortable touch size
          height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[HesakColors.primaryMuted, HesakColors.primary],
            ),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primary.withValues(alpha: 0.3),
                blurRadius: 22,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Icon(Icons.add_rounded,
              size: HesakSizes.iconNavTab, color: HesakColors.onPrimary),
        ),
      ),
    );
  }
}
