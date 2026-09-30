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
import '../widgets/hesak_page_header.dart';
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
    return Column(
      children: <Widget>[
        // Same shared header as the Home page (logo, waves, title, divider).
        // TODO: if HesakPageHeader names its title parameter differently,
        // copy the exact line used in home_screen.dart.
        HesakPageHeader(title: 'المحادثات'),
        const Expanded(child: _ChatsPageContent()),
      ],
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
final List<BoxShadow> _chatsCardShadow = <BoxShadow>[
  BoxShadow(
    color: HesakColors.primary.withValues(alpha: 0.06),
    blurRadius: 16,
    offset: const Offset(0, 4),
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

  final TextEditingController _searchController = TextEditingController();

  _ChatsFilterTab _selectedFilterTab = _ChatsFilterTab.all;
  _ChatsSortOrder _selectedSortOrder = _ChatsSortOrder.newestFirst;
  String _searchQuery = '';

  /// Number for the next new conversation: "محادثة 01", "محادثة 02", ...
  /// Set from the number of loaded conversations.
  int _nextConversationNumber = 1;

  /// Ticks every second so the "تُحذف بعد 17:20:30" countdown stays exact.
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _countdownTimer = Timer.periodic(
      const Duration(seconds: 1),
          (_) => _refreshCountdowns(),
    );
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  /// Loads the user's conversations from Firestore.
  Future<void> _loadConversations() async {
    final List<ChatsConversation> loaded =
    await ConversationService.instance.loadConversations();
    if (!mounted) return;
    setState(() {
      _conversations
        ..clear()
        ..addAll(loaded);
      _nextConversationNumber = loaded.length + 1;
      _isLoading = false;
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
  }

  /// Opens the rename dialog and applies the new title.
  Future<void> _renameConversation(ChatsConversation conversation) async {
    final String? newTitle = await showDialog<String>(
      context: context,
      barrierColor: HesakColors.textPrimary.withValues(alpha: 0.38),
      builder: (_) => _ChatsRenameDialog(currentTitle: conversation.title),
    );
    if (newTitle == null || newTitle.trim().isEmpty) return;
    setState(() => conversation.title = newTitle.trim());
    ConversationService.instance.saveConversation(conversation);
  }

  /// Asks for confirmation, then removes the conversation.
  Future<void> _deleteConversation(ChatsConversation conversation) async {
    final bool? isConfirmed = await showDialog<bool>(
      context: context,
      barrierColor: HesakColors.textPrimary.withValues(alpha: 0.38),
      builder: (_) => _ChatsDeleteDialog(title: conversation.title),
    );
    if (isConfirmed != true) return;
    ConversationService.instance.deleteConversation(conversation.id);
    setState(() => _conversations.remove(conversation));
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
      if (!conversation.hasStartedListening && conversation.messages.isEmpty) {
        _conversations.remove(conversation);
        // Give its number back so the next one reuses it.
        _nextConversationNumber--;
      }
    });
    // Save everything that happened inside the conversation.
    if (conversation.hasStartedListening || conversation.messages.isNotEmpty) {
      ConversationService.instance.saveConversation(conversation);
    }
  }

  /// Creates an empty conversation and opens it (shows the start card).
  void _startNewConversation() {
    final ChatsConversation conversation = ChatsConversation(
      id: ConversationService.instance.newConversationId(),
      // Auto name until the user renames it.
      // TODO: AI suggests a name after a few messages.
      title: chatsDefaultConversationTitle(_nextConversationNumber++),
      createdAt: DateTime.now(),
    );
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
              padding: const EdgeInsets.fromLTRB(
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
                  const SizedBox(height: HesakSizes.sectionGap),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ChatsSearchBar(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _ChatsSortButton(
                        selectedOrder: _selectedSortOrder,
                        onOrderSelected: (order) =>
                            setState(() => _selectedSortOrder = order),
                      ),
                    ],
                  ),
                  const SizedBox(height: HesakSizes.sectionGap),
                  // The 24h notice shows on "الكل" only; "المحفوظة" has none.
                  if (isAllTab) const _ChatsExpiryNotice(),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : visible.isEmpty
                  ? _ChatsEmptyState(isSearching: _searchQuery.isNotEmpty)
                  : ListView.separated(
                key: const Key('chats_conversations_list'),
                padding: const EdgeInsets.fromLTRB(
                  HesakSizes.pagePadding,
                  16,
                  HesakSizes.pagePadding,
                  // Bar space + room so the last card clears the
                  // "محادثة جديدة" button.
                  HesakSizes.pageBottomSafeSpace + 70,
                ),
                itemCount: visible.length,
                separatorBuilder: (_, __) =>
                const SizedBox(height: HesakSizes.sectionGap),
                itemBuilder: (_, index) {
                  final ChatsConversation conversation =
                  visible[index];
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
      key: const Key('chats_filter_tabs'),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: HesakColors.navBar,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
      ),
      child: Row(
        children: <Widget>[
          _ChatsFilterTabButton(
            key: const Key('chats_filter_all_tab'),
            label: 'الكل',
            isSelected: selectedTab == _ChatsFilterTab.all,
            onTap: () => onTabSelected(_ChatsFilterTab.all),
          ),
          const SizedBox(width: 4),
          _ChatsFilterTabButton(
            key: const Key('chats_filter_saved_tab'),
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
            duration: const Duration(milliseconds: 180),
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
                  offset: const Offset(0, 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
        boxShadow: _chatsCardShadow,
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.search_rounded,
            size: HesakSizes.iconInChip + 3,
            color: HesakColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('chats_search_bar'),
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
      key: const Key('chats_sort_button'),
      tooltip: 'ترتيب حسب التاريخ',
      onSelected: onOrderSelected,
      color: HesakColors.surface,
      elevation: 8,
      shadowColor: HesakColors.primary.withValues(alpha: 0.3),
      offset: const Offset(0, 56), // opens just under the button
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: HesakColors.surfaceBorder),
      ),
      itemBuilder: (_) => <PopupMenuEntry<_ChatsSortOrder>>[
        PopupMenuItem<_ChatsSortOrder>(
          enabled: false,
          height: 32,
          child: Text('ترتيب حسب التاريخ', style: HesakTextStyles.caption
              .copyWith(color: HesakColors.textSecondary)),
        ),
        _buildSortItem(
          key: const Key('chats_sort_newest_option'),
          order: _ChatsSortOrder.newestFirst,
          label: 'من الأحدث للأقدم',
        ),
        _buildSortItem(
          key: const Key('chats_sort_oldest_option'),
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
        child: const Icon(
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
            const Icon(
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
      key: const Key('chats_expiry_note'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: HesakColors.urgent.withValues(alpha: 0.05),
        border: Border.all(color: HesakColors.urgent.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.info_outline_rounded,
            size: HesakSizes.iconInChip + 3,
            color: HesakColors.urgent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: HesakTextStyles.body.copyWith(
                  color: HesakColors.textPrimary,
                  height: 1.6,
                ),
                children: <InlineSpan>[
                  const TextSpan(text: 'تُحذف المحادثات تلقائيًا بعد '),
                  TextSpan(
                    text: '24 ساعة',
                    style: HesakTextStyles.captionUrgent,
                  ),
                  const TextSpan(text: '. احفظ ما يهمك بزر الحفظ.'),
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
        color: HesakColors.surface,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        boxShadow: _chatsCardShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              HesakSizes.cardPaddingHorizontal,
              HesakSizes.cardPaddingTop,
              6, // the (…) and save buttons already have their own padding
              HesakSizes.cardPaddingBottom,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: HesakSizes.iconBox,
                  height: HesakSizes.iconBox,
                  decoration: BoxDecoration(
                    color: HesakColors.primaryLight,
                    borderRadius:
                    BorderRadius.circular(HesakSizes.radiusIconBox),
                  ),
                  child: const Icon(
                    Icons.chat_outlined,
                    size: HesakSizes.iconInBox,
                    color: HesakColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
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
                      const SizedBox(height: 6),
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
                              '· تُحذف بعد ${chatsFormatTimeLeft(conversation.timeUntilAutoDelete)}',
                              style: HesakTextStyles.captionUrgent,
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
        const SizedBox(width: 4),
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
      key: const Key('chats_card_menu_button'),
      tooltip: 'خيارات المحادثة: $conversationTitle',
      icon: const Icon(
        Icons.more_horiz_rounded,
        size: HesakSizes.iconInBox,
        color: HesakColors.primary,
      ),
      color: HesakColors.surface,
      elevation: 8,
      shadowColor: HesakColors.primary.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: HesakColors.surfaceBorder),
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
          key: const Key('chats_card_menu_rename'),
          value: _ChatsCardAction.rename,
          height: 48,
          child: Row(
            children: <Widget>[
              const Icon(Icons.edit_outlined,
                  size: HesakSizes.iconInChip + 3, color: HesakColors.primary),
              const SizedBox(width: 10),
              Text('تعديل الاسم', style: HesakTextStyles.itemTitle),
            ],
          ),
        ),
        const PopupMenuDivider(height: 8),
        PopupMenuItem<_ChatsCardAction>(
          key: const Key('chats_card_menu_delete'),
          value: _ChatsCardAction.delete,
          height: 48,
          child: Row(
            children: <Widget>[
              const Icon(Icons.delete_outline_rounded,
                  size: HesakSizes.iconInChip + 3, color: HesakColors.urgent),
              const SizedBox(width: 10),
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
  const _ChatsEmptyState({required this.isSearching});

  final bool isSearching;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
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
              isSearching ? Icons.search_rounded : Icons.bookmark_border_rounded,
              size: HesakSizes.iconInBox + 3,
              color: HesakColors.primaryMuted,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching ? 'لا توجد نتائج' : 'لا توجد محادثات محفوظة',
            style: HesakTextStyles.cardTitle,
          ),
          const SizedBox(height: 6),
          Text(
            isSearching
                ? 'جرّب كلمة أخرى أو امسح البحث.'
                : 'اضغط زر الحفظ في أي محادثة لتبقى محفوظة لديك.',
            textAlign: TextAlign.center,
            style: HesakTextStyles.body.copyWith(height: 1.6),
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
        key: const Key('chats_new_button'),
        onTap: onPressed,
        child: Container(
          width: 52, // comfortable touch size
          height: 52,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[HesakColors.primaryMuted, HesakColors.primary],
            ),
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primary.withValues(alpha: 0.3),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.add_rounded,
              size: HesakSizes.iconNavTab, color: HesakColors.onPrimary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dialogs
// ---------------------------------------------------------------------------

/// "تعديل اسم المحادثة" — returns the new title, or null when cancelled.
class _ChatsRenameDialog extends StatefulWidget {
  const _ChatsRenameDialog({required this.currentTitle});

  final String currentTitle;

  @override
  State<_ChatsRenameDialog> createState() => _ChatsRenameDialogState();
}

class _ChatsRenameDialogState extends State<_ChatsRenameDialog> {
  late final TextEditingController _titleController =
  TextEditingController(text: widget.currentTitle);

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  void _submitNewTitle() => Navigator.of(context).pop(_titleController.text);

  @override
  Widget build(BuildContext context) {
    return _ChatsDialogFrame(
      key: const Key('chats_rename_dialog'),
      children: <Widget>[
        Text('تعديل اسم المحادثة', style: HesakTextStyles.cardTitle),
        const SizedBox(height: 14),
        TextField(
          key: const Key('chats_rename_input'),
          controller: _titleController,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submitNewTitle(),
          style: HesakTextStyles.itemTitle.copyWith(fontWeight: FontWeight.w400),
          decoration: InputDecoration(
            filled: true,
            fillColor: HesakColors.surface,
            contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                  color: HesakColors.primaryLightBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
              const BorderSide(color: HesakColors.primaryMuted, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: <Widget>[
            Expanded(
              child: _ChatsDialogButton(
                key: const Key('chats_rename_save'),
                label: 'حفظ',
                isPrimary: true,
                onPressed: _submitNewTitle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChatsDialogButton(
                key: const Key('chats_rename_cancel'),
                label: 'إلغاء',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// "حذف المحادثة؟" — returns true when the user confirms.
class _ChatsDeleteDialog extends StatelessWidget {
  const _ChatsDeleteDialog({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return _ChatsDialogFrame(
      key: const Key('chats_delete_dialog'),
      isCentered: true,
      children: <Widget>[
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: HesakColors.urgent.withValues(alpha: 0.07),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline_rounded,
              size: HesakSizes.iconInBox, color: HesakColors.urgent),
        ),
        const SizedBox(height: 10),
        Text('هل تريد حذف «$title»؟',
            textAlign: TextAlign.center, style: HesakTextStyles.cardTitle),
        const SizedBox(height: 6),
        Text(
          'ستُحذف المحادثة نهائيًا ولا يمكن استعادتها.',
          textAlign: TextAlign.center,
          style: HesakTextStyles.itemTitle.copyWith(
            fontWeight: FontWeight.w400,
            color: HesakColors.textSecondary,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: _ChatsDialogButton(
                key: const Key('chats_delete_confirm'),
                label: 'حذف',
                isPrimary: true,
                isDestructive: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ChatsDialogButton(
                key: const Key('chats_delete_cancel'),
                label: 'إلغاء',
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Card-style frame shared by the list dialogs.
class _ChatsDialogFrame extends StatelessWidget {
  const _ChatsDialogFrame({
    super.key,
    required this.children,
    this.isCentered = false,
  });

  final List<Widget> children;
  final bool isCentered;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: HesakColors.surface,
      insetPadding: const EdgeInsets.all(HesakSizes.pagePadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        side: const BorderSide(color: HesakColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
          isCentered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

/// 48-high rounded button used in the list dialogs.
class _ChatsDialogButton extends StatelessWidget {
  const _ChatsDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isPrimary = false,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final Color background = isPrimary
        ? (isDestructive ? HesakColors.urgent : HesakColors.primary)
        : HesakColors.primaryLight;
    final Color foreground =
    isPrimary ? HesakColors.onPrimary : HesakColors.primary;

    return SizedBox(
      height: 48,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          shape: const StadiumBorder(),
        ),
        child: Text(label,
            style: HesakTextStyles.itemTitle.copyWith(color: foreground)),
      ),
    );
  }
}