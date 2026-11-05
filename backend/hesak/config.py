# ============================================================
# HESAK backend — config.py : EVERY setting in one place  (was: notebook Cell 1 + Whisper settings)
# ------------------------------------------------------------
# Only numbers live here: no code runs, nothing is loaded.
# Change a number → restart the server.
# ============================================================

# ---- [1] Audio format ----
# Fixed by the models (Silero and Whisper expect 16 kHz). Do not change.
SR = 16000                    # Hz, mono, float32 in [-1, 1]
# Fixed by Silero (it only accepts 512 samples at 16 kHz). Do not change.
FRAME = 512                   # 32 ms — the common grid for Gate and Silero
# Audio piece size used by the tests (the phone may send any size).
BROWSER_CHUNK = 4096          # 256 ms

# ---- [2] Shared buffer ----
# Keeps the last 30 s. Must be longer than the longest clip we cut (15 s + padding).
RING_SECONDS = 30.0

# ---- [3] Activity Gate (cheap "is there any sound?" check, frames the audio for Silero) ----
GATE_BG_SECONDS = 3.0         # background memory (also the warm-up time)
GATE_BG_FRAMES = int(round(GATE_BG_SECONDS * SR / FRAME))      # 94 frames
GATE_BG_PERCENTILE = 20       # robust noise-floor estimate
GATE_BG_UPDATE_FRAMES = 8     # recompute floor every 256 ms
GATE_OPEN_DB = 6.0            # open when level ≥ floor + 6 dB
GATE_CLOSE_DB = 3.0           # stay open while level ≥ floor + 3 dB
GATE_HOLD_MS = 300            # close only after 300 ms below the close level
GATE_MIN_DBFS = -70.0         # absolute minimum level that can count as activity
GATE_REBASELINE_S = 20.0      # a sound lasting longer becomes the new background

# ---- [3] Environment requests (YAMNet) — kept so the tests match the notebook ----
ENV_PREROLL_S = 0.5           # audio kept before the gate opened
ENV_WINDOW_S = 1.0            # audio per request (YAMNet needs ≥ 0.975 s)
ENV_ONGOING_EVERY_S = 3.0     # during a long activity: one request every 3 s
ENV_IDLE_CHECK_S = 10.0       # gate closed: one check every 10 s (None = off)

# ---- [4] Conversation path : Silero ----
VAD_THRESHOLD = 0.5
# True: while a conversation is open, Silero hears EVERY frame (quiet / far speech is not lost).
CONV_ALWAYS_LISTEN = True
VAD_MIN_SILENCE_MS = 500      # a pause this long ends a sentence
VAD_SPEECH_PAD_MS = 30
VAD_PREROLL_S = 0.5           # audio from before the Gate opened that Silero also sees
STT_PRE_PAD_S = 0.30          # audio kept before Silero's start
STT_POST_PAD_S = 0.25         # audio kept after Silero's end
STT_MAX_SEGMENT_S = 15.0      # longer speech is split (Whisper works best < 30 s)
STT_MIN_SEGMENT_S = 0.30      # shorter pieces are not sent
SPEECH_BLOCKS_YAMNET = True   # a window with speech goes to Whisper only, not to YAMNet

# ---- [5] Hand-off queues + event history ----
HANDOFF_MAX = 50              # waiting YAMNet requests (oldest dropped when full)
EVENT_HISTORY_MAX = 2000
WHISPER_INBOX_MAX = 200       # a finished sentence must never be dropped

# ---- [6] Whisper ----
STT_PARTIAL_MIN_S = 0.5       # first live words after 0.5 s of speech
STT_PARTIAL_EVERY_S = 0.4     # then new live words every 0.4 s
WHISPER_LANG = "ar"           # fixed language: short sentences are often mis-detected
WHISPER_PROMPT_CHARS = 200    # earlier text kept per conversation (used only if WHISPER_USE_CONTEXT)
WHISPER_USE_CONTEXT = False   # OFF: context makes Whisper repeat old sentences on unclear audio
WHISPER_STYLE_PROMPT = ""     # OFF: a prompt makes Whisper copy words from it (invented text)
# Models: "auto" = GPU → large-v3-turbo (live) + large-v3 (final) | CPU → small for both.
import os  # the server can override the models without editing this file:
WHISPER_LIVE_MODEL = os.environ.get("HESAK_LIVE_MODEL", "auto")     # e.g. HESAK_FINAL_MODEL=large-v3-turbo
WHISPER_FINAL_MODEL = os.environ.get("HESAK_FINAL_MODEL", "auto")
WHISPER_GPU_BEAM = 5
WHISPER_CPU_BEAM = 1
# The whole sentence is dropped only if Whisper itself says "no speech" with low confidence:
WHISPER_NO_SPEECH = 0.6
WHISPER_MIN_LOGPROB = -1.0
# A PART of a sentence is dropped (not the whole sentence) when Whisper doubts it:
WHISPER_SEG_NO_SPEECH = 0.6
WHISPER_SEG_MIN_LOGPROB = -1.0
WHISPER_SEG_MAX_COMPRESSION = 2.4   # the same words repeated in a loop → invented
# Quiet / far speech is made louder before Whisper (never quieter, never clipped).
WHISPER_TARGET_DBFS = -20.0
WHISPER_MAX_GAIN_DB = 20.0
# Phrases Whisper invents on silence / noise — cut OUT of the text.
HALLUCINATIONS = ("اشتركوا في القناة", "اشترك في القناة", "لا تنسوا الاشتراك", "لا تنسى الاشتراك",
                  "شكرا للمشاهدة", "شكراً للمشاهدة", "شكرا على المشاهدة", "شكراً على المشاهدة",
                  "شكرا لكم على المشاهدة", "شكراً لكم على المشاهدة", "ترجمة نانسي قنقر", "نانسي قنقر",
                  "Thank you for watching", "Thanks for watching", "Subtitles by", "Amara.org")

# Tiny number so log(0) never happens on pure silence.
_EPS = 1e-10


def s2t(samples):
    """samples → seconds (display only; all logic uses samples)."""
    return None if samples is None else samples / SR