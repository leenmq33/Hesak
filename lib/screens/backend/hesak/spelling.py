# ============================================================
# HESAK backend — spelling.py : instant spelling fixes (no AI, no internet, < 1 ms)
# ------------------------------------------------------------
# Whisper usually HEARS the right word but WRITES it loosely: انا, مره, "ال مطعم", "ان شا الله".
# These rules fix only the WRITING of a word — they never change which word was said.
# Used on every text the user sees (live words AND final sentences), so it is fixed the moment it appears.
# Only safe, unambiguous fixes are listed. To add a word: put it in WORDS (wrong → right).
# ============================================================
import re

# 1) Fixed phrases (spelled many ways by the model)
PHRASES = [
    (r"\bان\s*شا+ء?\s*ا?لله\b|\bانشا+ء?\s*ا?لله\b|\bإن\s*شا\s*الله\b", "إن شاء الله"),
    (r"\bما\s*شا+ء?\s*ا?لله\b|\bماشا+ء?\s*ا?لله\b", "ما شاء الله"),
    (r"\bالحمدلله\b", "الحمد لله"),
    (r"\bجزاك\s*الله\s*خير\b", "جزاك الله خير"),
]

# 2) Whole words: wrong spelling → right spelling (only words that cannot mean something else)
WORDS = {
    # hamza at the start
    "انا": "أنا", "ادري": "أدري", "اذا": "إذا", "احد": "أحد", "اكيد": "أكيد", "احسن": "أحسن",
    "اول": "أول", "امس": "أمس", "اخوي": "أخوي", "اختي": "أختي", "امي": "أمي", "ابوي": "أبوي",
    "ابوك": "أبوك", "امك": "أمك", "اخوك": "أخوك", "اختك": "أختك", "اهلي": "أهلي", "اهلك": "أهلك",
    "الاهل": "الأهل", "اخبارك": "أخبارك", "اخبارج": "أخبارج", "الاكل": "الأكل", "الاسبوع": "الأسبوع",
    "اسبوع": "أسبوع", "الامس": "الأمس", "الان": "الآن", "الى": "إلى", "اللى": "اللي",
    "اعرف": "أعرف", "اقول": "أقول", "اروح": "أروح", "اشوف": "أشوف", "احب": "أحب", "اسوي": "أسوي",
    "اجي": "أجي", "اكلم": "أكلم", "انتظر": "أنتظر", "اصلا": "أصلاً", "ابدا": "أبداً", "ايش": "إيش",
    "اتاخر": "أتأخر", "تاخر": "تأخر", "تاخرت": "تأخرت", "تاخرنا": "تأخرنا", "متاخر": "متأخر",
    # taa marbuta / alif maqsura (ه at the end that is really ة)
    "مره": "مرة", "بكره": "بكرة", "سياره": "سيارة", "السياره": "السيارة", "ساعه": "ساعة",
    "الساعه": "الساعة", "شنطه": "شنطة", "الشنطه": "الشنطة", "قهوه": "قهوة", "القهوه": "القهوة",
    "مدرسه": "مدرسة", "المدرسه": "المدرسة", "السلامه": "السلامة", "سلامه": "سلامة",
    "العافيه": "العافية", "عافيه": "عافية", "شويه": "شوية", "حلوه": "حلوة", "طيبه": "طيبة",
    "زينه": "زينة", "كويسه": "كويسة", "تعبانه": "تعبانة", "جاهزه": "جاهزة", "دقيقه": "دقيقة",
    "الصلاه": "الصلاة", "صلاه": "صلاة", "الجامعه": "الجامعة", "جامعه": "جامعة", "الغرفه": "الغرفة",
    "غرفه": "غرفة", "الشركه": "الشركة", "شركه": "شركة", "حاجه": "حاجة",
    "مشكله": "مشكلة", "المشكله": "المشكلة", "مسوول": "مسؤول",
    "متي": "متى", "حتي": "حتى", "مستشفي": "مستشفى", "المستشفي": "المستشفى",
}

_PUNCT = ".,،؟?!:؛;\"'…"
_WORD_RE = re.compile(r"\S+")


def _fix_word(m):
    w = m.group(0)
    core = w.strip(_PUNCT)
    if not core:
        return w
    fixed = WORDS.get(core)
    if fixed is None or fixed == core:
        return w
    i = w.index(core)
    return w[:i] + fixed + w[i + len(core):]


def fix_spelling(text):
    """Instant, safe spelling fixes. Never adds, removes or reorders words."""
    if not text:
        return text
    t = text
    # 3) a lone prefix written apart from its word: "ال مطعم" → "المطعم", "و تعشوا" → "وتعشوا"
    t = re.sub(r"(?<!\S)(ال|و|ب|ل|ف)\s+(?=[ء-ي])", r"\1", t)
    for pat, good in PHRASES:
        t = re.sub(pat, good, t)
    return _WORD_RE.sub(_fix_word, t)