# ============================================================
# HESAK — modal_app.py : runs server.py on a real GPU server (Modal), with a FIXED link
# ------------------------------------------------------------
#   📱 Flutter ──wss://…modal.run/ws──► Modal (L4 GPU) ──► server.py (the SAME code as Colab)
#
#   • The server wakes up by itself when the phone connects, and sleeps when nobody uses it
#     (you pay only while it is awake).
#   • The link and the token never change → env.json is set ONCE.
#   • Nothing here changes server.py or the hesak/ code. It only builds the same setup as the Colab cell.
#
#   Deploy (from D:\dev\Hesak\backend):   python -m modal deploy modal_app.py
#   Demo day (stay awake, no first wait):  $env:HESAK_KEEP_WARM="1"; python -m modal deploy modal_app.py
#   Back to normal (sleep when unused):    $env:HESAK_KEEP_WARM="0"; python -m modal deploy modal_app.py
# ============================================================
import os
import pathlib

import modal

BACKEND_DIR = pathlib.Path(__file__).parent          # the local backend/ folder
MODEL_DIR = "/models/ct2-hesak-dialect"              # your model inside the Modal volume
KEEP_WARM = int(os.environ.get("HESAK_KEEP_WARM", "0"))  # 0 = sleep when unused, 1 = always awake (costs more)

# ---- 1) the server "computer": same packages as the Colab cell ----
PY = "3.11"
SITE = f"/usr/local/lib/python{PY}/site-packages"
image = (
    modal.Image.debian_slim(python_version=PY)
    .apt_install("git", "curl", "build-essential", "pkg-config", "libsndfile1")
    .pip_install("torch", "torchaudio")                                  # installed together → versions match
    .pip_install_from_requirements(str(BACKEND_DIR / "requirements.txt"))
    # DeepFilterNet3 (noise cancellation): needs Rust to build its fast part
    .run_commands(
        "curl -sSf https://sh.rustup.rs | sh -s -- -y -q",
        "PATH=$HOME/.cargo/bin:$PATH PYO3_USE_ABI3_FORWARD_COMPATIBILITY=1 "
        "pip install --no-deps deepfilterlib deepfilternet",
        "pip install loguru appdirs requests",
    )
    # DeepFilterNet imports a torchaudio part that new torchaudio removed → patch that one line (same as Colab)
    .run_commands(
        "python -c \"import importlib.util, pathlib, re; "
        "d = pathlib.Path(importlib.util.find_spec('df').submodule_search_locations[0]); "
        "[p.write_text(re.sub(r'^from torchaudio\\.backend\\.common import (\\w+).*$', "
        "r'\\1 = object  # patched', p.read_text(), flags=re.M)) for p in d.glob('*.py')]\""
    )

        # remove old compiled copies so Python reads the PATCHED files, then check DeepFilterNet imports
    .run_commands(
        "find /usr/local/lib/python3.11/site-packages/df -name '__pycache__' -prune -exec rm -rf {} +",
        "python -c \"import df.enhance; print('DeepFilterNet import OK')\"",
    )
    .env({
        # let faster-whisper find the CUDA-12 libraries that pip installed
        "LD_LIBRARY_PATH": f"{SITE}/nvidia/cublas/lib:{SITE}/nvidia/cudnn/lib",
        # the same settings as the Colab cell
        "HESAK_LIVE_MODEL": MODEL_DIR,
        "HESAK_FINAL_MODEL": MODEL_DIR,
        "HESAK_DENOISE": "deepfilter",       # "deepfilter" / "spectral" / "off"
        "HESAK_DENOISE_LIMIT_DB": "12",      # the most the noise is lowered (dB)
        "HESAK_LIVE_BEAM": "5",              # live words quality (1 = fastest, 5 = like the final text)
    })
    # your backend code (server.py + hesak/) — copied fresh on every deploy
    .add_local_dir(BACKEND_DIR, remote_path="/root/backend",
                   ignore=["tests", "**/__pycache__", "*.wav", "*.log", ".pytest_cache", "modal_app.py"])
)

app = modal.App("hesak-stt", image=image)
models = modal.Volume.from_name("hesak-models")          # your model lives here (uploaded once from Colab)


# ---- 2) the server itself ----
@app.function(
    	gpu=["L4", "A10", "T4"],                                # same GPU as Colab
    volumes={"/models": models},
    secrets=[modal.Secret.from_name("hesak-secret")],   # HESAK_TOKEN (not in the code, not in GitHub)
    min_containers=KEEP_WARM,                 # 0 = sleeps when unused
    max_containers=1,                         # never more than ONE GPU → no surprise bill
    scaledown_window=1200,                # stays awake 5 min after the last chat, then sleeps
    timeout=3 * 60 * 60,                      # one conversation can last up to 3 hours
)
@modal.concurrent(max_inputs=20)              # many connections share the same loaded models
@modal.asgi_app()
def web():
    import sys
    os.chdir("/root/backend")
    sys.path.insert(0, "/root/backend")
    import server                             # YOUR server.py, unchanged

    ctl, info = server.make_system(fake=False)          # loads Silero + Whisper + DeepFilterNet once
    return server.create_app(ctl, info, token=os.environ.get("HESAK_TOKEN") or None)