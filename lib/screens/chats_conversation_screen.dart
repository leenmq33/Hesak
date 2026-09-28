// ============================================================================
// NAMING RULES (Chats page)
// - Private classes in this file start with "_Chats" (e.g. _ChatsComposerBar).
// - Public classes shared between the chats files start with "Chats".
// - Keys follow page_element: chats_... (see the Keys list in the guide).
// - Booleans start with "is" / "has". Functions describe what they do.
// - Colors / text styles / sizes come ONLY from lib/core/theme.
//   No Color(0x...) and no fontSize in this file.
// - Spelling: hesak (not heask).
// ============================================================================

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme/hesak_colors.dart';
import '../core/theme/hesak_sizes.dart';
import '../core/theme/hesak_text_styles.dart';
import 'chats_models.dart';

/// Body text of a chat bubble.
/// TODO: ask the team to add `HesakTextStyles.chatMessage` (14.5, w400,
/// height 1.7, textPrimary) and use it here instead of this copyWith.
final TextStyle _chatsMessageTextStyle = HesakTextStyles.itemTitle.copyWith(
  fontWeight: FontWeight.w400,
  height: 1.7,
);

/// Gradient of the bar's centre button, reused for the main chat actions.
const LinearGradient _chatsPrimaryGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: <Color>[HesakColors.primaryMuted, HesakColors.primary],
);

/// What the user chose in the leave-conversation warning.
enum _ChatsExitChoice { saveAndLeave, leaveWithoutSaving, stay }

/// What the user chose in the text-enhancement sheet.
enum _ChatsEnhancementChoice { accept, keepOriginal }

/// One conversation, full screen. The bottom bar is NOT shown here
/// (it is pushed on the root navigator from chats_screen.dart).
class ChatsConversationScreen extends StatefulWidget {
  const ChatsConversationScreen({super.key, required this.conversation});

  final ChatsConversation conversation;

  @override
  State<ChatsConversationScreen> createState() =>
      _ChatsConversationScreenState();
}

class _ChatsConversationScreenState extends State<ChatsConversationScreen>
    with SingleTickerProviderStateMixin {
  final ScrollController _messagesScrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  /// Drives the moving bars while listening.
  late final AnimationController _listeningBarsController =
      AnimationController(vsync: this, duration: const Duration(seconds: 1));

  bool _isListening = false;
  bool _isEditingTitle = false;

  /// The 24-hour warning shows only the first time the user presses back.
  bool _hasShownExitWarning = false;

  /// Accepted enhancements whose purple box is currently open.
  final Set<String> _openEnhancedMessageIds = <String>{};

  /// Voice playback (text-to-speech messages).
  String? _playingMessageId;
  int _playingWordIndex = 0;
  Timer? _playbackTimer;

  /// Demo only: fake incoming speech while listening.
  Timer? _demoTranscriptTimer;

  /// Scroll indicator + jump-to-end button state.
  double _scrollProgress = 1.0;
  double _visibleFraction = 1.0;
  bool _isAtBottom = true;

  ChatsConversation get _conversation => widget.conversation;

  bool get _hasComposerText => _composerController.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _messagesScrollController.addListener(_updateScrollIndicator);
    _composerController.addListener(() => setState(() {}));
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateScrollIndicator());
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _demoTranscriptTimer?.cancel();
    _listeningBarsController.dispose();
    _messagesScrollController.dispose();
    _composerController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Back / leave
  // -------------------------------------------------------------------------

  /// First back press on an unsaved conversation shows the 24h warning.
  Future<void> _handleBackPressed() async {
    if (_conversation.isSaved || _hasShownExitWarning) {
      Navigator.of(context).pop();
      return;
    }
    _hasShownExitWarning = true;
    final _ChatsExitChoice? choice = await showDialog<_ChatsExitChoice>(
      context: context,
      barrierColor: HesakColors.textPrimary.withValues(alpha: 0.38),
      builder: (_) => const _ChatsExitDialog(),
    );
    if (!mounted) return;
    switch (choice) {
      case _ChatsExitChoice.saveAndLeave:
        _conversation.isSaved = true;
        Navigator.of(context).pop();
      case _ChatsExitChoice.leaveWithoutSaving:
        Navigator.of(context).pop();
      case _ChatsExitChoice.stay:
      case null:
        break;
    }
  }

  /// Saves / un-saves this conversation from the header button.
  void _toggleConversationSaved() {
    setState(() => _conversation.isSaved = !_conversation.isSaved);
  }

  // -------------------------------------------------------------------------
  // Title editing (tap the title at any time)
  // -------------------------------------------------------------------------

  /// Turns the title into a text field.
  void _startEditingTitle() {
    _titleController.text = _conversation.title;
    setState(() => _isEditingTitle = true);
  }

  /// Applies the typed title (empty text keeps the old one).
  void _saveEditedTitle() {
    final String newTitle = _titleController.text.trim();
    setState(() {
      if (newTitle.isNotEmpty) _conversation.title = newTitle;
      _isEditingTitle = false;
    });
    // TODO: persist the new title.
  }

  // -------------------------------------------------------------------------
  // Listening (speech → text)
  // -------------------------------------------------------------------------

  /// Starts / stops listening. While listening, typing is disabled
  /// (the composer is replaced by the listening bar).
  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      _conversation.markStarted(); // start time + 24h countdown begin here
    });
    if (_isListening) {
      _listeningBarsController.repeat();
      _startDemoTranscript();
      // TODO: start the real speech-to-text service here and add each
      // result with _addIncomingMessage(text).
    } else {
      _listeningBarsController.stop();
      _demoTranscriptTimer?.cancel();
      // TODO: stop the real speech-to-text service.
    }
  }

  /// Demo only: adds one heard sentence after a short delay.
  void _startDemoTranscript() {
    _demoTranscriptTimer?.cancel();
    _demoTranscriptTimer = Timer(const Duration(milliseconds: 2600), () {
      if (!mounted || !_isListening) return;
      _addIncomingMessage('مرحبا كيف اقدر اساعدك اليوم');
    });
  }

  /// Adds heard speech (already turned into text) on the left.
  void _addIncomingMessage(String text) {
    setState(() {
      _conversation.messages.add(ChatsMessage(
        id: 'in_${DateTime.now().microsecondsSinceEpoch}',
        kind: ChatsMessageKind.speechToText,
        originalText: text,
        sentAt: DateTime.now(),
      ));
    });
    _scrollToEnd();
  }

  // -------------------------------------------------------------------------
  // Sending (text → speech)
  // -------------------------------------------------------------------------

  /// Sends the composer text as a voice message (text shown under it).
  /// Nothing is sent until the user presses this button.
  void _sendComposerText() {
    final String text = _composerController.text.trim();
    if (text.isEmpty || _isListening) return;
    final ChatsMessage message = ChatsMessage(
      id: 'out_${DateTime.now().microsecondsSinceEpoch}',
      kind: ChatsMessageKind.textToSpeech,
      originalText: text,
      sentAt: DateTime.now(),
      voiceDuration: chatsEstimateVoiceDuration(text),
    );
    setState(() {
      _conversation.messages.add(message);
      _conversation.markStarted();
      _composerController.clear();
    });
    _scrollToEnd();
    _togglePlayback(message); // speak it right away
  }

  // -------------------------------------------------------------------------
  // Voice playback with spoken-word highlight
  // -------------------------------------------------------------------------

  /// Plays / stops a voice message and moves the word highlight.
  void _togglePlayback(ChatsMessage message) {
    _playbackTimer?.cancel();
    if (_playingMessageId == message.id) {
      setState(() => _playingMessageId = null);
      // TODO: stop the text-to-speech engine.
      return;
    }
    final int wordCount = message.originalWords.length;
    final Duration duration =
        message.voiceDuration ?? chatsEstimateVoiceDuration(message.originalText);
    final Duration perWord = Duration(
        milliseconds: (duration.inMilliseconds / math.max(wordCount, 1)).round());

    setState(() {
      _playingMessageId = message.id;
      _playingWordIndex = 0;
    });
    // TODO: speak message.originalText with the text-to-speech engine and
    // move _playingWordIndex from its word-boundary callback instead.
    _playbackTimer = Timer.periodic(perWord, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_playingWordIndex + 1 >= wordCount) {
        timer.cancel();
        setState(() => _playingMessageId = null);
      } else {
        setState(() => _playingWordIndex++);
      }
    });
  }

  // -------------------------------------------------------------------------
  // AI enhancement
  // -------------------------------------------------------------------------

  /// For a heard message: original stays on top; if accepted, the enhanced
  /// text shows in a purple box under it.
  Future<void> _enhanceIncomingMessage(ChatsMessage message) async {
    message.enhancedText ??= await chatsEnhanceText(message.originalText);
    if (!mounted) return;
    final _ChatsEnhancementChoice? choice = await _showEnhancementSheet(
      originalText: message.originalText,
      enhancedText: message.enhancedText!,
      sourceLabel:
          'من رسالة ${message.speakerLabel} · ${chatsFormatTime(message.sentAt)}',
    );
    if (choice == _ChatsEnhancementChoice.accept) {
      setState(() {
        message.isEnhancementAccepted = true;
        _openEnhancedMessageIds.add(message.id);
      });
    }
  }

  /// For the composer: accept puts the enhanced text in the field;
  /// keep / ✕ leaves the user's text as it is. Nothing is sent.
  Future<void> _enhanceComposerText() async {
    final String original = _composerController.text.trim();
    if (original.isEmpty || _isListening) return;
    final String enhanced = await chatsEnhanceText(original);
    if (!mounted) return;
    final _ChatsEnhancementChoice? choice = await _showEnhancementSheet(
      originalText: original,
      enhancedText: enhanced,
      sourceLabel: 'نصك قبل الإرسال',
    );
    if (choice == _ChatsEnhancementChoice.accept) {
      _composerController.text = enhanced;
      _composerController.selection =
          TextSelection.collapsed(offset: enhanced.length);
    }
  }

  /// Opens the bottom sheet that shows original vs enhanced text.
  Future<_ChatsEnhancementChoice?> _showEnhancementSheet({
    required String originalText,
    required String enhancedText,
    required String sourceLabel,
  }) {
    return showModalBottomSheet<_ChatsEnhancementChoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: HesakColors.textPrimary.withValues(alpha: 0.16),
      builder: (_) => _ChatsEnhancementSheet(
        originalText: originalText,
        enhancedText: enhancedText,
        sourceLabel: sourceLabel,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Scrolling
  // -------------------------------------------------------------------------

  /// Updates the side indicator and the jump-to-end button.
  void _updateScrollIndicator() {
    if (!_messagesScrollController.hasClients) return;
    final ScrollPosition position = _messagesScrollController.position;
    final double total = position.maxScrollExtent + position.viewportDimension;
    setState(() {
      _visibleFraction = total <= 0
          ? 1.0
          : (position.viewportDimension / total).clamp(0.1, 1.0).toDouble();
      _scrollProgress = position.maxScrollExtent <= 0
          ? 1.0
          : (position.pixels / position.maxScrollExtent)
              .clamp(0.0, 1.0)
              .toDouble();
      _isAtBottom = position.pixels >= position.maxScrollExtent - 24;
    });
  }

  /// Smoothly scrolls to the newest message.
  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesScrollController.hasClients) return;
      _messagesScrollController.animateTo(
        _messagesScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
      );
    });
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isShowingStartCard = !_conversation.hasStartedListening &&
        _conversation.messages.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackPressed();
      },
      child: Scaffold(
        backgroundColor: HesakColors.background,
        body: SafeArea(
          child: Column(
            children: <Widget>[
              _ChatsConversationHeader(
                title: _conversation.title,
                isEditingTitle: _isEditingTitle,
                titleController: _titleController,
                isSaved: _conversation.isSaved,
                onBack: _handleBackPressed,
                onStartEditingTitle: _startEditingTitle,
                onSaveTitle: _saveEditedTitle,
                onToggleSaved: _toggleConversationSaved,
              ),
              Expanded(
                child: isShowingStartCard
                    ? Center(
                        child: _ChatsStartListeningCard(
                            onStart: _toggleListening),
                      )
                    : Stack(
                        children: <Widget>[
                          _buildMessagesList(),
                          _ChatsScrollIndicator(
                            progress: _scrollProgress,
                            visibleFraction: _visibleFraction,
                          ),
                          if (!_isAtBottom)
                            Positioned(
                              right: 16,
                              bottom: 12,
                              child: _ChatsJumpToEndButton(
                                  onPressed: _scrollToEnd),
                            ),
                        ],
                      ),
              ),
              _ChatsComposerBar(
                controller: _composerController,
                isListening: _isListening,
                hasText: _hasComposerText,
                listeningBars: _listeningBarsController,
                onEnhance: _enhanceComposerText,
                onSend: _sendComposerText,
                onToggleListening: _toggleListening,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Date separator + bubbles, or a hint when there are no messages yet.
  Widget _buildMessagesList() {
    final List<ChatsMessage> messages = _conversation.messages;

    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(HesakSizes.pagePadding),
          child: Text(
            _isListening
                ? 'جارٍ الاستماع… سيظهر الكلام من حولك هنا نصًا.'
                : 'اضغط زر الاستماع، أو اكتب نصًا ليتحوّل إلى كلام.',
            textAlign: TextAlign.center,
            style: _chatsMessageTextStyle.copyWith(
                color: HesakColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('chats_messages_list'),
      controller: _messagesScrollController,
      // 22 on the left leaves room for the scroll indicator.
      padding: const EdgeInsets.fromLTRB(22, 14, 20, 24),
      itemCount: messages.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, index) {
        if (index == 0) {
          return _ChatsDateSeparator(
              label: chatsFormatDate(_conversation.displayTime));
        }
        final ChatsMessage message = messages[index - 1];
        if (message.kind == ChatsMessageKind.speechToText) {
          return _ChatsIncomingBubble(
            message: message,
            isEnhancedTextOpen: _openEnhancedMessageIds.contains(message.id),
            onEnhance: () => _enhanceIncomingMessage(message),
            onToggleEnhancedText: () => setState(() {
              if (!_openEnhancedMessageIds.remove(message.id)) {
                _openEnhancedMessageIds.add(message.id);
              }
            }),
          );
        }
        return _ChatsOutgoingVoiceBubble(
          message: message,
          isPlaying: _playingMessageId == message.id,
          playingWordIndex: _playingWordIndex,
          onTogglePlayback: () => _togglePlayback(message),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header
// ---------------------------------------------------------------------------

/// Back chevron, editable title, save button, divider.
class _ChatsConversationHeader extends StatelessWidget {
  const _ChatsConversationHeader({
    required this.title,
    required this.isEditingTitle,
    required this.titleController,
    required this.isSaved,
    required this.onBack,
    required this.onStartEditingTitle,
    required this.onSaveTitle,
    required this.onToggleSaved,
  });

  final String title;
  final bool isEditingTitle;
  final TextEditingController titleController;
  final bool isSaved;
  final VoidCallback onBack;
  final VoidCallback onStartEditingTitle;
  final VoidCallback onSaveTitle;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              IconButton(
                key: const Key('chats_conversation_back_button'),
                tooltip: 'رجوع إلى المحادثات',
                onPressed: onBack,
                // Mirrors in RTL, so it points right (">") like the design.
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: HesakSizes.iconNavTab,
                  color: HesakColors.textPrimary,
                ),
              ),
              Expanded(
                child: isEditingTitle
                    ? _ChatsTitleEditor(
                        controller: titleController, onSave: onSaveTitle)
                    : _ChatsTitleButton(
                        title: title, onPressed: onStartEditingTitle),
              ),
              _ChatsCircleIconButton(
                key: const Key('chats_conversation_save_button'),
                tooltip: isSaved ? 'إلغاء حفظ المحادثة' : 'حفظ المحادثة',
                icon: isSaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_add_outlined,
                iconColor:
                    isSaved ? HesakColors.primaryMuted : HesakColors.primary,
                background:
                    isSaved ? HesakColors.primaryLight : HesakColors.surface,
                onPressed: onToggleSaved,
              ),
            ],
          ),
          const SizedBox(height: 10),
          const _ChatsFadingDivider(),
        ],
      ),
    );
  }
}

/// Title + small pencil. Tap to rename at any time.
class _ChatsTitleButton extends StatelessWidget {
  const _ChatsTitleButton({required this.title, required this.onPressed});

  final String title;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'اسم المحادثة: $title. اضغط لتعديله',
      child: InkWell(
        key: const Key('chats_conversation_title'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HesakTextStyles.greeting,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.edit_outlined,
                  size: HesakSizes.iconInChip, color: HesakColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

/// Inline text field + ✓ shown while renaming.
class _ChatsTitleEditor extends StatelessWidget {
  const _ChatsTitleEditor({required this.controller, required this.onSave});

  final TextEditingController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsetsDirectional.fromSTEB(12, 0, 4, 0),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: HesakColors.primaryMuted, width: 1.5),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const Key('chats_conversation_title_input'),
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => onSave(),
              style: HesakTextStyles.cardTitle
                  .copyWith(color: HesakColors.primaryDark),
              decoration: const InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
              ),
            ),
          ),
          Semantics(
            button: true,
            label: 'حفظ الاسم',
            child: GestureDetector(
              key: const Key('chats_conversation_title_save'),
              onTap: onSave,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: HesakColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: HesakSizes.iconInChip + 1,
                    color: HesakColors.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 44px round button with a border (save button in the header).
class _ChatsCircleIconButton extends StatelessWidget {
  const _ChatsCircleIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: background,
        shape: const CircleBorder(
            side: BorderSide(color: HesakColors.surfaceBorder)),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: HesakSizes.iconInChip + 4, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Same fading divider as HesakPageHeader (lavenderAccent, 1px).
class _ChatsFadingDivider extends StatelessWidget {
  const _ChatsFadingDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            HesakColors.lavenderAccent.withValues(alpha: 0),
            HesakColors.lavenderAccent,
            HesakColors.lavenderAccent.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Start card (only for a brand-new conversation, only once)
// ---------------------------------------------------------------------------

class _ChatsStartListeningCard extends StatelessWidget {
  const _ChatsStartListeningCard({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chats_start_card'),
      width: 300, // comfortable reading width on phones
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: HesakColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: HesakColors.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.mic_none_rounded,
                size: HesakSizes.iconInBox + 5, color: HesakColors.primary),
          ),
          const SizedBox(height: 12),
          Text('محادثة جديدة', style: HesakTextStyles.cardTitle),
          const SizedBox(height: 6),
          Text(
            'سيظهر الكلام من حولك هنا نصًا، وسيتحوّل ما تكتبه إلى كلام.',
            textAlign: TextAlign.center,
            style: HesakTextStyles.body.copyWith(height: 1.7),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton.icon(
              key: const Key('chats_start_listening_button'),
              onPressed: onStart,
              style: TextButton.styleFrom(
                backgroundColor: HesakColors.primary,
                foregroundColor: HesakColors.onPrimary,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.mic_none_rounded,
                  size: HesakSizes.iconInChip + 3),
              label: Text('بدء الاستماع',
                  style: HesakTextStyles.itemTitle
                      .copyWith(color: HesakColors.onPrimary)),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Messages
// ---------------------------------------------------------------------------

/// "7 سبتمبر 2026" pill between lines.
class _ChatsDateSeparator extends StatelessWidget {
  const _ChatsDateSeparator({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Expanded(child: Divider(color: HesakColors.listDivider)),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 10),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: HesakColors.navBar,
            border: Border.all(color: HesakColors.surfaceBorder),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label, style: HesakTextStyles.modeLabel),
        ),
        const Expanded(child: Divider(color: HesakColors.listDivider)),
      ],
    );
  }
}

/// Heard speech turned into text. Always on the physical LEFT, with a tail
/// at the bottom-left. Label "شخص" above the bubble.
class _ChatsIncomingBubble extends StatelessWidget {
  const _ChatsIncomingBubble({
    required this.message,
    required this.isEnhancedTextOpen,
    required this.onEnhance,
    required this.onToggleEnhancedText,
  });

  final ChatsMessage message;
  final bool isEnhancedTextOpen;
  final VoidCallback onEnhance;
  final VoidCallback onToggleEnhancedText;

  @override
  Widget build(BuildContext context) {
    final bool isAccepted = message.isEnhancementAccepted;

    // Physical left on purpose: the design fixes heard speech on the left
    // and the user's voice on the right, whatever the text direction.
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 230, maxWidth: 290),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 8, bottom: 5),
                child: Text(message.speakerLabel,
                    style: HesakTextStyles.chipLabel
                        .copyWith(color: HesakColors.primaryMuted)),
              ),
              _ChatsBubbleWithTail(
                color: HesakColors.surface,
                isTailOnLeft: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    // The original text always stays on top.
                    Text(message.originalText, style: _chatsMessageTextStyle),
                    if (isAccepted && isEnhancedTextOpen) ...<Widget>[
                      const SizedBox(height: 6),
                      _ChatsEnhancedTextBox(text: message.enhancedText ?? ''),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (!isAccepted)
                          _ChatsEnhanceChip(onPressed: onEnhance)
                        else ...<Widget>[
                          const _ChatsEnhancedTag(),
                          TextButton(
                            key: Key('chats_toggle_enhanced_${message.id}'),
                            onPressed: onToggleEnhancedText,
                            style: TextButton.styleFrom(
                              foregroundColor: HesakColors.primary,
                              minimumSize: const Size(0, 36),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                            ),
                            child: Text(
                              isEnhancedTextOpen
                                  ? 'إخفاء النص المحسّن'
                                  : 'عرض النص المحسّن',
                              style: HesakTextStyles.chipLabel.copyWith(
                                  decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                        const Spacer(),
                        Text(chatsFormatTime(message.sentAt),
                            style: HesakTextStyles.caption
                                .copyWith(color: HesakColors.textSecondary)),
                      ],
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

/// Purple box with the accepted AI text, under the original.
class _ChatsEnhancedTextBox extends StatelessWidget {
  const _ChatsEnhancedTextBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight,
        border: Border.all(color: HesakColors.primaryLightBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded,
                  size: 12, color: HesakColors.primary),
              const SizedBox(width: 4),
              Text('النص المحسّن',
                  style: HesakTextStyles.caption.copyWith(
                      color: HesakColors.primary,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 2),
          Text(text, style: _chatsMessageTextStyle),
        ],
      ),
    );
  }
}

/// "✦ تحسين النص" chip inside the bubble.
class _ChatsEnhanceChip extends StatelessWidget {
  const _ChatsEnhanceChip({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        key: const Key('chats_message_enhance_chip'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: HesakColors.primaryLight,
            border: Border.all(color: HesakColors.primaryLightBorder),
            borderRadius: BorderRadius.circular(HesakSizes.radiusChip),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded,
                  size: HesakSizes.iconInChip - 2, color: HesakColors.primary),
              const SizedBox(width: 6),
              Text('تحسين النص', style: HesakTextStyles.chipLabel),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small "✦ محسّن" tag shown after accepting.
class _ChatsEnhancedTag extends StatelessWidget {
  const _ChatsEnhancedTag();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: HesakColors.primaryLight,
        border: Border.all(color: HesakColors.primaryLightBorder),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.auto_awesome_rounded,
              size: 13, color: HesakColors.primary),
          const SizedBox(width: 4),
          Text('محسّن',
              style: HesakTextStyles.caption.copyWith(
                  color: HesakColors.primary, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// The user's typed text turned into speech. Always on the physical RIGHT.
/// Player on top, text under it; words light up while spoken.
class _ChatsOutgoingVoiceBubble extends StatelessWidget {
  const _ChatsOutgoingVoiceBubble({
    required this.message,
    required this.isPlaying,
    required this.playingWordIndex,
    required this.onTogglePlayback,
  });

  final ChatsMessage message;
  final bool isPlaying;
  final int playingWordIndex;
  final VoidCallback onTogglePlayback;

  @override
  Widget build(BuildContext context) {
    final List<String> words = message.originalWords;
    final double progress =
        isPlaying ? (playingWordIndex + 1) / words.length : 1.0;

    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: SizedBox(
          width: 282, // fits the player comfortably on 360px phones
          child: _ChatsBubbleWithTail(
            color: HesakColors.primaryLight,
            isTailOnLeft: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Media controls keep left-to-right order.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: <Widget>[
                      _ChatsPlayButton(
                        key: Key('chats_voice_play_${message.id}'),
                        isPlaying: isPlaying,
                        onPressed: onTogglePlayback,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ChatsVoiceWaveform(
                          seed: message.id.hashCode,
                          progress: progress,
                          isPlaying: isPlaying,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        chatsFormatVoiceDuration(message.voiceDuration ??
                            chatsEstimateVoiceDuration(message.originalText)),
                        style: HesakTextStyles.modeLabel.copyWith(
                            color: HesakColors.primary,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Container(height: 0.8, color: HesakColors.primaryLightBorder),
                const SizedBox(height: 8),
                Semantics(
                  label: message.originalText,
                  excludeSemantics: true,
                  child: Wrap(
                    spacing: 4,
                    runSpacing: 2,
                    children: <Widget>[
                      for (int i = 0; i < words.length; i++)
                        _ChatsSpokenWord(
                          word: words[i],
                          state: !isPlaying
                              ? _ChatsWordState.idle
                              : i == playingWordIndex
                                  ? _ChatsWordState.current
                                  : i < playingWordIndex
                                      ? _ChatsWordState.spoken
                                      : _ChatsWordState.upcoming,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    Text(chatsFormatTime(message.sentAt),
                        style: HesakTextStyles.caption
                            .copyWith(color: HesakColors.primaryMuted)),
                    const SizedBox(width: 4),
                    const Icon(Icons.done_all_rounded,
                        size: 16, color: HesakColors.primaryMuted),
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

/// Highlight state of one word while a voice message plays.
enum _ChatsWordState { idle, spoken, current, upcoming }

/// One word of a voice message, highlighted while it is spoken.
class _ChatsSpokenWord extends StatelessWidget {
  const _ChatsSpokenWord({required this.word, required this.state});

  final String word;
  final _ChatsWordState state;

  @override
  Widget build(BuildContext context) {
    final bool isCurrent = state == _ChatsWordState.current;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        color: isCurrent ? HesakColors.primary : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        word,
        style: _chatsMessageTextStyle.copyWith(
          color: switch (state) {
            _ChatsWordState.current => HesakColors.onPrimary,
            _ChatsWordState.upcoming => HesakColors.iconInactive,
            _ => HesakColors.textPrimary,
          },
          fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }
}

/// 40px round play / pause button.
class _ChatsPlayButton extends StatelessWidget {
  const _ChatsPlayButton({
    super.key,
    required this.isPlaying,
    required this.onPressed,
  });

  final bool isPlaying;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: isPlaying ? 'إيقاف مؤقت' : 'تشغيل الرسالة الصوتية',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: HesakColors.primary,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primary.withValues(alpha: 0.25),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: HesakSizes.iconInBox,
            color: HesakColors.onPrimary,
          ),
        ),
      ),
    );
  }
}

/// Decorative waveform; the played part is darker.
/// TODO: draw the real amplitude of the generated audio.
class _ChatsVoiceWaveform extends StatelessWidget {
  const _ChatsVoiceWaveform({
    required this.seed,
    required this.progress,
    required this.isPlaying,
  });

  final int seed;
  final double progress;
  final bool isPlaying;

  static const int _barCount = 30;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List<Widget>.generate(_barCount, (i) {
          final double height =
              7 + (math.sin((seed % 97 + 1) * 12.9898 + i * 1.7).abs() * 22);
          final bool isPlayed = !isPlaying || i < (_barCount * progress).round();
          return Container(
            width: 3,
            height: height,
            decoration: BoxDecoration(
              color: isPlaying
                  ? (isPlayed ? HesakColors.primary : HesakColors.lavenderAccent)
                  : HesakColors.primaryMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }
}

/// Bubble body with a stretched tail at the bottom corner.
class _ChatsBubbleWithTail extends StatelessWidget {
  const _ChatsBubbleWithTail({
    required this.color,
    required this.isTailOnLeft,
    required this.child,
  });

  final Color color;
  final bool isTailOnLeft;
  final Widget child;

  static const double _tailWidth = 12;
  static const double _tailHeight = 18;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: HesakColors.primary.withValues(alpha: 0.10),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isTailOnLeft ? 4 : 18),
                bottomRight: Radius.circular(isTailOnLeft ? 18 : 4),
              ),
            ),
            child: child,
          ),
          Positioned(
            bottom: 0,
            left: isTailOnLeft ? -7 : null,
            right: isTailOnLeft ? null : -7,
            child: CustomPaint(
              size: const Size(_tailWidth, _tailHeight),
              painter: _ChatsBubbleTailPainter(
                  color: color, isTailOnLeft: isTailOnLeft),
            ),
          ),
        ],
      ),
    );
  }
}

/// Draws the curved tail that stretches out of the bubble corner.
class _ChatsBubbleTailPainter extends CustomPainter {
  const _ChatsBubbleTailPainter({
    required this.color,
    required this.isTailOnLeft,
  });

  final Color color;
  final bool isTailOnLeft;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    // Drawn for the left side, then mirrored for the right side.
    final Path path = Path()
      ..moveTo(w, 0)
      ..lineTo(w, h)
      ..lineTo(w * 0.13, h)
      ..cubicTo(w * 0.04, h, 0, h * 0.94, w * 0.08, h * 0.89)
      ..cubicTo(w * 0.5, h * 0.61, w * 0.87, h * 0.33, w, 0)
      ..close();
    if (!isTailOnLeft) {
      canvas.translate(w, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ChatsBubbleTailPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isTailOnLeft != isTailOnLeft;
}

// ---------------------------------------------------------------------------
// Scroll helpers
// ---------------------------------------------------------------------------

/// Slim bar on the left edge showing where you are in the conversation.
class _ChatsScrollIndicator extends StatelessWidget {
  const _ChatsScrollIndicator({
    required this.progress,
    required this.visibleFraction,
  });

  final double progress;
  final double visibleFraction;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 6,
      top: 10,
      bottom: 10,
      width: 4,
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (_, constraints) {
            final double trackHeight = constraints.maxHeight;
            final double thumbHeight =
                math.max(44.0, trackHeight * visibleFraction);
            return Stack(
              children: <Widget>[
                Container(
                  decoration: BoxDecoration(
                    color: HesakColors.listDivider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Positioned(
                  top: (trackHeight - thumbHeight) * progress,
                  left: 0,
                  right: 0,
                  height: thumbHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: HesakColors.primaryMuted,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// ↓ button that appears when the user scrolls up.
class _ChatsJumpToEndButton extends StatelessWidget {
  const _ChatsJumpToEndButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'الانتقال إلى آخر المحادثة',
      child: GestureDetector(
        key: const Key('chats_jump_to_end_button'),
        onTap: onPressed,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: HesakColors.surface,
            shape: BoxShape.circle,
            border: Border.all(color: HesakColors.primaryLightBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primaryDark.withValues(alpha: 0.16),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.arrow_downward_rounded,
              size: HesakSizes.iconInBox, color: HesakColors.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Composer
// ---------------------------------------------------------------------------

/// Bottom bar: text field + ✦, and the mic (empty) or send (has text).
/// While listening the whole bar becomes the listening bar.
class _ChatsComposerBar extends StatelessWidget {
  const _ChatsComposerBar({
    required this.controller,
    required this.isListening,
    required this.hasText,
    required this.listeningBars,
    required this.onEnhance,
    required this.onSend,
    required this.onToggleListening,
  });

  final TextEditingController controller;
  final bool isListening;
  final bool hasText;
  final Animation<double> listeningBars;
  final VoidCallback onEnhance;
  final VoidCallback onSend;
  final VoidCallback onToggleListening;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: const BoxDecoration(
        color: HesakColors.background,
        border: Border(top: BorderSide(color: HesakColors.surfaceBorder)),
      ),
      child: isListening
          ? _ChatsListeningBar(
              bars: listeningBars, onStop: onToggleListening)
          : Row(
              children: <Widget>[
                Expanded(
                  child: _ChatsComposerField(
                    controller: controller,
                    hasText: hasText,
                    onEnhance: onEnhance,
                  ),
                ),
                const SizedBox(width: 10),
                hasText
                    ? _ChatsSendButton(onPressed: onSend)
                    : _ChatsListenButton(onPressed: onToggleListening),
              ],
            ),
    );
  }
}

/// "اكتب نصًا ليتحوّل إلى كلام…" + the ✦ enhance button inside.
class _ChatsComposerField extends StatelessWidget {
  const _ChatsComposerField({
    required this.controller,
    required this.hasText,
    required this.onEnhance,
  });

  final TextEditingController controller;
  final bool hasText;
  final VoidCallback onEnhance;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 6, 0),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        border: Border.all(color: HesakColors.surfaceBorder),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: TextField(
              key: const Key('chats_message_input'),
              controller: controller,
              textInputAction: TextInputAction.newline,
              minLines: 1,
              maxLines: 3,
              style: HesakTextStyles.itemTitle
                  .copyWith(fontWeight: FontWeight.w400),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'اكتب نصًا ليتحوّل إلى كلام…',
                hintStyle: HesakTextStyles.itemTitle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: HesakColors.textSecondary,
                ),
              ),
            ),
          ),
          // Works only when there is text; otherwise faded and not tappable.
          Semantics(
            button: true,
            enabled: hasText,
            label: hasText
                ? 'تحسين النص المكتوب بالذكاء الاصطناعي'
                : 'تحسين النص، اكتب نصًا أولًا',
            child: GestureDetector(
              key: const Key('chats_ai_enhance_button'),
              onTap: hasText ? onEnhance : null,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 150),
                opacity: hasText ? 1.0 : 0.45,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color:
                        hasText ? HesakColors.primary : HesakColors.primaryLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: HesakColors.primaryLightBorder),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: HesakSizes.iconInChip + 3,
                    color:
                        hasText ? HesakColors.onPrimary : HesakColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty field: round purple mic button (no label; the screen-reader
/// label explains it).
class _ChatsListenButton extends StatelessWidget {
  const _ChatsListenButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'استماع: تحويل الكلام من حولك إلى نص',
      child: GestureDetector(
        key: const Key('chats_listen_button'),
        onTap: onPressed,
        child: Container(
          width: 52, // same size as the send button it turns into
          height: 52,
          decoration: BoxDecoration(
            gradient: _chatsPrimaryGradient,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(Icons.mic_none_rounded,
              size: HesakSizes.iconInBox + 1, color: HesakColors.onPrimary),
        ),
      ),
    );
  }
}

/// Has text: round send button.
class _ChatsSendButton extends StatelessWidget {
  const _ChatsSendButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'إرسال وتحويل النص إلى كلام',
      child: GestureDetector(
        key: const Key('chats_send_button'),
        onTap: onPressed,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            gradient: _chatsPrimaryGradient,
            shape: BoxShape.circle,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: HesakColors.primary.withValues(alpha: 0.28),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // send_rounded mirrors in RTL so it points the reading way.
          child: const Icon(Icons.send_rounded,
              size: HesakSizes.iconInChip + 5, color: HesakColors.onPrimary),
        ),
      ),
    );
  }
}

/// Whole-width bar while listening: stop button, moving bars, "يستمع…".
class _ChatsListeningBar extends StatelessWidget {
  const _ChatsListeningBar({required this.bars, required this.onStop});

  final Animation<double> bars;
  final VoidCallback onStop;

  static const int _barCount = 22;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('chats_listening_bar'),
      height: 52,
      padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
      decoration: BoxDecoration(
        gradient: _chatsPrimaryGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: HesakColors.primary.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: <Widget>[
            Semantics(
              button: true,
              label: 'إيقاف الاستماع',
              child: GestureDetector(
                key: const Key('chats_listening_stop_button'),
                onTap: onStop,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: HesakColors.onPrimary,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: HesakColors.primary,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExcludeSemantics(
                child: AnimatedBuilder(
                  animation: bars,
                  builder: (_, __) {
                    final double t = bars.value * 2 * math.pi;
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List<Widget>.generate(_barCount, (i) {
                        final double height = 5 +
                            (math.sin(t + i * 0.9) * math.cos(i * 0.35))
                                    .abs() *
                                22;
                        return Container(
                          width: 3,
                          height: height,
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          decoration: BoxDecoration(
                            color: HesakColors.onPrimary.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        );
                      }),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text('يستمع…',
                style: HesakTextStyles.itemTitle
                    .copyWith(color: HesakColors.onPrimary)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sheets & dialogs
// ---------------------------------------------------------------------------

/// Bottom sheet: original on top, enhanced under it,
/// "قبول النص المحسّن" / "إبقاء الأصلي". ✕ = keep original.
class _ChatsEnhancementSheet extends StatelessWidget {
  const _ChatsEnhancementSheet({
    required this.originalText,
    required this.enhancedText,
    required this.sourceLabel,
  });

  final String originalText;
  final String enhancedText;
  final String sourceLabel;

  @override
  Widget build(BuildContext context) {
    void closeWith(_ChatsEnhancementChoice choice) =>
        Navigator.of(context).pop(choice);

    return Container(
      key: const Key('chats_enhance_sheet'),
      padding: EdgeInsets.fromLTRB(
          20, 10, 20, 24 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: HesakColors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: HesakColors.primaryDark.withValues(alpha: 0.12),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(
                color: HesakColors.primaryLightBorder,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              const Icon(Icons.auto_awesome_rounded,
                  size: HesakSizes.iconInChip + 3,
                  color: HesakColors.primaryMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text('تحسين النص', style: HesakTextStyles.cardTitle),
                    Text(sourceLabel,
                        style: HesakTextStyles.caption
                            .copyWith(color: HesakColors.textSecondary)),
                  ],
                ),
              ),
              IconButton(
                key: const Key('chats_enhance_close'),
                tooltip: 'إغلاق',
                onPressed: () => closeWith(_ChatsEnhancementChoice.keepOriginal),
                icon: const Icon(Icons.close_rounded,
                    size: HesakSizes.iconInChip + 3,
                    color: HesakColors.iconInactive),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ChatsSheetTextBlock(
            label: 'النص الأصلي',
            text: originalText,
            isEnhanced: false,
          ),
          const SizedBox(height: 14),
          _ChatsSheetTextBlock(
            label: 'النص المحسّن',
            text: enhancedText,
            isEnhanced: true,
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 52,
            child: TextButton(
              key: const Key('chats_enhance_accept'),
              onPressed: () => closeWith(_ChatsEnhancementChoice.accept),
              style: TextButton.styleFrom(
                backgroundColor: HesakColors.primaryMuted,
                foregroundColor: HesakColors.onPrimary,
                shape: const StadiumBorder(),
              ),
              child: Text('قبول النص المحسّن',
                  style: HesakTextStyles.itemTitle
                      .copyWith(color: HesakColors.onPrimary)),
            ),
          ),
          SizedBox(
            height: 44,
            child: TextButton(
              key: const Key('chats_enhance_keep_original'),
              onPressed: () => closeWith(_ChatsEnhancementChoice.keepOriginal),
              style: TextButton.styleFrom(
                foregroundColor: HesakColors.primary,
                shape: const StadiumBorder(),
              ),
              child: Text('إبقاء الأصلي',
                  style: HesakTextStyles.itemTitle
                      .copyWith(color: HesakColors.primary)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft block in the enhancement sheet (grey = original, purple = enhanced).
class _ChatsSheetTextBlock extends StatelessWidget {
  const _ChatsSheetTextBlock({
    required this.label,
    required this.text,
    required this.isEnhanced,
  });

  final String label;
  final String text;
  final bool isEnhanced;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isEnhanced
            ? HesakColors.primaryLight.withValues(alpha: 0.6)
            : HesakColors.background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              if (isEnhanced) ...<Widget>[
                const Icon(Icons.auto_awesome_rounded,
                    size: 12, color: HesakColors.primaryMuted),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: HesakTextStyles.caption.copyWith(
                  color: isEnhanced
                      ? HesakColors.primaryMuted
                      : HesakColors.iconInactive,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            text,
            style: _chatsMessageTextStyle.copyWith(
              color: isEnhanced
                  ? HesakColors.textPrimary
                  : HesakColors.textSecondary,
              fontWeight: isEnhanced ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// First back press on an unsaved conversation:
/// "ستُحذف المحادثة بعد 24 ساعة".
class _ChatsExitDialog extends StatelessWidget {
  const _ChatsExitDialog();

  @override
  Widget build(BuildContext context) {
    void closeWith(_ChatsExitChoice choice) => Navigator.of(context).pop(choice);

    return Dialog(
      key: const Key('chats_exit_dialog'),
      backgroundColor: HesakColors.surface,
      insetPadding: const EdgeInsets.all(HesakSizes.pagePadding),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HesakSizes.radiusCard),
        side: const BorderSide(color: HesakColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: HesakColors.urgent.withValues(alpha: 0.07),
                shape: BoxShape.circle,
                border: Border.all(
                    color: HesakColors.urgent.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.schedule_rounded,
                  size: HesakSizes.iconInBox + 5, color: HesakColors.urgent),
            ),
            const SizedBox(height: 12),
            Text('ستُحذف المحادثة بعد 24 ساعة',
                textAlign: TextAlign.center, style: HesakTextStyles.cardTitle),
            const SizedBox(height: 6),
            Text(
              'هل تريد حفظها في المحفوظات للرجوع إليها لاحقًا؟',
              textAlign: TextAlign.center,
              style: HesakTextStyles.itemTitle.copyWith(
                  fontWeight: FontWeight.w400,
                  color: HesakColors.textSecondary),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: TextButton.icon(
                key: const Key('chats_exit_save_button'),
                onPressed: () => closeWith(_ChatsExitChoice.saveAndLeave),
                style: TextButton.styleFrom(
                  backgroundColor: HesakColors.primary,
                  foregroundColor: HesakColors.onPrimary,
                  shape: const StadiumBorder(),
                ),
                icon: const Icon(Icons.bookmark_rounded,
                    size: HesakSizes.iconInChip + 3),
                label: Text('حفظ في المحفوظات',
                    style: HesakTextStyles.itemTitle
                        .copyWith(color: HesakColors.onPrimary)),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                key: const Key('chats_exit_leave_button'),
                onPressed: () => closeWith(_ChatsExitChoice.leaveWithoutSaving),
                style: OutlinedButton.styleFrom(
                  foregroundColor: HesakColors.primary,
                  side: const BorderSide(
                      color: HesakColors.primaryLightBorder, width: 1.5),
                  shape: const StadiumBorder(),
                ),
                child: Text('الخروج دون حفظ',
                    style: HesakTextStyles.itemTitle
                        .copyWith(color: HesakColors.primary)),
              ),
            ),
            TextButton(
              key: const Key('chats_exit_stay_button'),
              onPressed: () => closeWith(_ChatsExitChoice.stay),
              style: TextButton.styleFrom(
                foregroundColor: HesakColors.textSecondary,
                minimumSize: const Size(0, 44),
              ),
              child: Text('البقاء في المحادثة',
                  style: HesakTextStyles.itemTitle.copyWith(
                      color: HesakColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}