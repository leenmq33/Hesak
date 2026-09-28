// ============================================================================
// NAMING RULES (Chats page)
// - Public classes shared between the chats files start with "Chats"
//   (e.g. ChatsConversation). Private classes start with "_Chats".
// - Top-level functions / constants start with "chats" (e.g. chatsFormatDate).
// - Keys follow page_element: chats_...
// - Colors, text styles and sizes come ONLY from lib/core/theme
//   (HesakColors / HesakTextStyles / HesakSizes). No Color(0x...) here.
// - Spelling: hesak (not heask).
// ============================================================================

/// Data models, sample data and small helpers for the Chats page.
///
/// Used by chats_screen.dart (the list) and
/// chats_conversation_screen.dart (one conversation).
library;

/// How long an unsaved conversation stays before it is deleted automatically.
const Duration chatsAutoDeleteAfter = Duration(hours: 24);

/// Which side a message comes from.
enum ChatsMessageKind {
  /// Someone around the user spoke; the app turned the speech into text.
  /// Shown on the LEFT.
  speechToText,

  /// The user typed text; the app turned it into speech (voice message).
  /// Shown on the RIGHT with the text under the voice player.
  textToSpeech,
}

/// One message inside a conversation.
class ChatsMessage {
  ChatsMessage({
    required this.id,
    required this.kind,
    required this.originalText,
    required this.sentAt,
    this.speakerLabel = 'شخص',
    this.enhancedText,
    this.isEnhancementAccepted = false,
    this.voiceDuration,
  });

  final String id;
  final ChatsMessageKind kind;

  /// The text exactly as it was heard / typed. Never replaced.
  final String originalText;

  final DateTime sentAt;

  /// Label shown above speech-to-text messages.
  final String speakerLabel;

  /// AI-improved version of [originalText] (null until requested).
  String? enhancedText;

  /// True after the user taps "قبول" in the enhancement sheet.
  bool isEnhancementAccepted;

  /// Length of the generated voice (text-to-speech messages only).
  final Duration? voiceDuration;

  /// The words of the original text, used for the spoken-word highlight.
  List<String> get originalWords =>
      originalText.trim().split(RegExp(r'\s+'));
}

/// One conversation in the list.
class ChatsConversation {
  ChatsConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    List<ChatsMessage>? messages,
    this.isSaved = false,
    this.startedAt,
  }) : messages = messages ?? <ChatsMessage>[];

  final String id;

  /// Can be renamed at any time (list menu or tapping the title).
  String title;

  final DateTime createdAt;
  final List<ChatsMessage> messages;

  /// Saved conversations are kept and never deleted automatically.
  bool isSaved;

  /// When the conversation really started: the first "بدء الاستماع" press
  /// or the first sent message. Null for a new conversation not started yet.
  DateTime? startedAt;

  /// False only for a brand-new conversation that was never started.
  /// Once true, the big "بدء الاستماع" card never shows again.
  bool get hasStartedListening => startedAt != null;

  /// Marks the start time once (later calls keep the first time).
  void markStarted() => startedAt ??= DateTime.now();

  /// Time shown on the card and in the chat: the start time.
  DateTime get displayTime => startedAt ?? createdAt;

  /// Time left before automatic deletion, counted from the start time
  /// (zero when already expired).
  Duration get timeUntilAutoDelete {
    final Duration left =
        displayTime.add(chatsAutoDeleteAfter).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }
}

// ---------------------------------------------------------------------------
// Formatting helpers (no intl package needed)
// ---------------------------------------------------------------------------

const List<String> _chatsArabicMonthNames = <String>[
  'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
  'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
];

/// "7 سبتمبر 2026"
String chatsFormatDate(DateTime date) =>
    '${date.day} ${_chatsArabicMonthNames[date.month - 1]} ${date.year}';

/// "10:14 ص" / "4:05 م"
String chatsFormatTime(DateTime date) {
  final int hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final String minutes = date.minute.toString().padLeft(2, '0');
  final String period = date.hour < 12 ? 'ص' : 'م';
  return '$hour12:$minutes $period';
}

/// Default name of a new conversation: 1 → "محادثة 01".
String chatsDefaultConversationTitle(int number) =>
    'محادثة ${number.toString().padLeft(2, '0')}';

/// Exact countdown "17:20:30" (hours:minutes:seconds) — used in
/// "تُحذف بعد ...". Updated every second by the list page.
String chatsFormatTimeLeft(Duration left) {
  final int hours = left.inHours;
  final String minutes = (left.inMinutes % 60).toString().padLeft(2, '0');
  final String seconds = (left.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}

/// "0:05" — voice message length.
String chatsFormatVoiceDuration(Duration duration) {
  final int minutes = duration.inMinutes;
  final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Rough speaking time for typed text (about 2 words per second).
Duration chatsEstimateVoiceDuration(String text) {
  final int words = text.trim().split(RegExp(r'\s+')).length;
  final int seconds = (words / 2).ceil().clamp(2, 600).toInt();
  return Duration(seconds: seconds);
}

// ---------------------------------------------------------------------------
// AI text enhancement
// ---------------------------------------------------------------------------

/// Returns an improved version of [text].
///
/// TODO: connect to the real AI service. This local version only fixes a
/// few common colloquial words and adds final punctuation, so the UI can be
/// tested now.
Future<String> chatsEnhanceText(String text) async {
  String result = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  const Map<String, String> replacements = <String, String>{
    'ابي اعرف': 'أودّ أن أعرف',
    'متى نسلم': 'متى موعد تسليم',
    'ابي': 'أريد',
    'ابغى': 'أريد',
    'اعرف': 'أعرف',
    'عشان': 'لكي',
    'انا': 'أنا',
    'انت': 'أنت',
    'انتم': 'أنتم',
    'راح': 'سوف',
    'شوي': 'قليلًا',
    'الحين': 'الآن',
    'اقدر': 'أستطيع',
    'ارتب': 'أرتّب',
  };
  replacements.forEach((String from, String to) {
    result = result.replaceAllMapped(
      RegExp('(^|\\s)$from(?=\\s|\$)'),
      (Match m) => '${m[1]}$to',
    );
  });
  if (!RegExp(r'[.؟!،]$').hasMatch(result)) {
    final bool isQuestion =
        RegExp(r'^(هل|متى|كيف|لماذا|وين|أين|ما|من)\s').hasMatch(result);
    result += isQuestion ? '؟' : '.';
  }
  return result;
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

/// Demo conversations so the page can be tested before real storage exists.
///
/// TODO: replace with the real conversations source (local DB / backend) and
/// delete unsaved conversations older than [chatsAutoDeleteAfter].
List<ChatsConversation> chatsSampleConversations() {
  final DateTime now = DateTime.now();
  final DateTime meetingStart = now.subtract(const Duration(hours: 6));

  return <ChatsConversation>[
    ChatsConversation(
      id: 'chats_demo_1',
      title: 'اجتماع التدريب',
      createdAt: meetingStart,
      startedAt: meetingStart,
      messages: <ChatsMessage>[
        ChatsMessage(
          id: 'm1',
          kind: ChatsMessageKind.speechToText,
          sentAt: meetingStart,
          originalText:
              'السلام عليكم ورحمة الله وبركاته اليوم… عندنا اجتماع لمشروع التخرج… هل انتم مستعدة ومتجهزة للاجتماع',
        ),
        ChatsMessage(
          id: 'm2',
          kind: ChatsMessageKind.speechToText,
          sentAt: meetingStart.add(const Duration(minutes: 1)),
          originalText:
              'نعم نحتاج نحدد المهام لكل واحد و نتفق على الجدول الزمني',
        ),
        ChatsMessage(
          id: 'm3',
          kind: ChatsMessageKind.textToSpeech,
          sentAt: meetingStart.add(const Duration(minutes: 3)),
          originalText: 'تمام، أنا جاهزة ونقدر نبدأ بمناقشة التفاصيل الآن.',
          voiceDuration: const Duration(seconds: 5),
        ),
        ChatsMessage(
          id: 'm4',
          kind: ChatsMessageKind.speechToText,
          sentAt: meetingStart.add(const Duration(minutes: 4)),
          originalText: 'ممتاز راح ارسل لكم الملفات بعد شوي',
        ),
      ],
    ),
    ChatsConversation(
      id: 'chats_demo_2',
      title: 'محاضرة التصميم التفاعلي',
      createdAt: now.subtract(const Duration(hours: 8)),
      startedAt: now.subtract(const Duration(hours: 8)),
    ),
    ChatsConversation(
      id: 'chats_demo_3',
      title: 'موعد العيادة',
      createdAt: now.subtract(const Duration(days: 1, hours: 2)),
      isSaved: true,
      startedAt: now.subtract(const Duration(days: 1, hours: 2)),
    ),
    ChatsConversation(
      id: 'chats_demo_4',
      title: 'في المقهى',
      createdAt: now.subtract(const Duration(hours: 21)),
      startedAt: now.subtract(const Duration(hours: 21)),
    ),
    ChatsConversation(
      id: 'chats_demo_5',
      title: 'اجتماع فريق المشروع',
      createdAt: now.subtract(const Duration(days: 2, hours: 1)),
      isSaved: true,
      startedAt: now.subtract(const Duration(days: 2, hours: 1)),
    ),
  ];
}