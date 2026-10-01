"""Supply-chain lock (security audit Q2, 2026-10-01): the model fetch FAILS CLOSED.

``app/tool/fetch_models.sh`` is the only way the on-device segmentation model
enters a build, and ``app/assets/models/`` is bundled WHOLE into the APK. So
the rule is: after the script runs, that directory holds the pinned model or
NO model — never an unverified file — whatever the network or the upstream
bucket does. These tests run a copy of the real script against tiny local
``file://`` sources (no network, no 16 MB model), with only the three pin
variables rewritten, and break the build if:

- a tampered, truncated or unreachable source leaves any model in place
  (including the pre-2026-10-01 hole: a foreign file already at the
  destination survived a failed download);
- a temp file is left behind;
- the real script goes back to the mutable ``latest/`` URL or loses its pin;
- the model fetched on this machine does not match the pin (when present).

Needs ``bash`` + ``curl`` (CI ubuntu: yes; Windows: Git Bash). Skipped
otherwise, with the reason printed.
"""

import hashlib
import os
import re
import shutil
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]
SCRIPT = REPO_ROOT / "app" / "tool" / "fetch_models.sh"
REAL_MODEL = (
    REPO_ROOT / "app" / "assets" / "models" / "selfie_multiclass_256x256.tflite"
)
MODEL_NAME = "selfie_multiclass_256x256.tflite"

PIN_VARS = ("MODEL_URL", "MODEL_SHA256", "MODEL_BYTES")
GOOD_PAYLOAD = b"pinned-model-bytes " * 64
SCRIPT_TIMEOUT_S = 60


def _find_bash() -> str | None:
    """A POSIX bash. On Windows, Git Bash only — never WSL's System32 bash,
    which would not understand the Windows paths handed to it."""
    if os.name == "nt":
        git = shutil.which("git")
        if git is None:
            return None
        for candidate in (
            Path(git).resolve().parents[1] / "bin" / "bash.exe",
            Path(git).resolve().parents[2] / "bin" / "bash.exe",
        ):
            if candidate.is_file():
                return str(candidate)
        return None
    return shutil.which("bash")


BASH = _find_bash()

pytestmark = pytest.mark.skipif(
    BASH is None or shutil.which("curl") is None,
    reason="needs bash + curl (Git Bash on Windows)",
)


def _sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _real_pin() -> dict[str, str]:
    text = SCRIPT.read_text(encoding="utf-8")
    pins = {}
    for var in PIN_VARS:
        matches = re.findall(rf'^{var}="?([^"\n]+)"?$', text, re.MULTILINE)
        assert len(matches) == 1, f"{var} must be assigned exactly once in {SCRIPT}"
        pins[var] = matches[0]
    return pins


def _install_script(root: Path, source: Path, payload: bytes) -> Path:
    """Copy the real script into ``root/app/tool/`` with the pin pointed at a
    local file that would be ``payload``. Everything else stays byte-identical."""
    text = SCRIPT.read_text(encoding="utf-8")
    replacements = {
        "MODEL_URL": f'"{source.as_uri()}"',
        "MODEL_SHA256": f'"{_sha256(payload)}"',
        "MODEL_BYTES": str(len(payload)),
    }
    for var, value in replacements.items():
        text, n = re.subn(
            rf"^{var}=.*$", lambda _m, v=var, val=value: f"{v}={val}", text, flags=re.M
        )
        assert n == 1, f"could not rewrite {var}: the lock no longer matches the script"
    tool = root / "app" / "tool"
    tool.mkdir(parents=True)
    script = tool / "fetch_models.sh"
    script.write_text(text, encoding="utf-8", newline="\n")
    return script


def _run(script: Path) -> subprocess.CompletedProcess[str]:
    assert BASH is not None
    return subprocess.run(
        [BASH, script.as_posix()],
        capture_output=True,
        text=True,
        timeout=SCRIPT_TIMEOUT_S,
        check=False,
    )


def _dest(root: Path) -> Path:
    return root / "app" / "assets" / "models" / MODEL_NAME


def _leftovers(root: Path) -> list[str]:
    tool_dir = root / "app" / "tool"
    models_dir = root / "app" / "assets" / "models"
    names = [p.name for p in tool_dir.iterdir() if p.name != "fetch_models.sh"]
    if models_dir.is_dir():
        names += [p.name for p in models_dir.iterdir() if p.name != MODEL_NAME]
    return names


def _scenario(tmp_path: Path, source_bytes: bytes | None, preexisting: bytes | None):
    src = tmp_path / "src" / "upstream.tflite"
    src.parent.mkdir()
    if source_bytes is not None:
        src.write_bytes(source_bytes)
    root = tmp_path / "repo"
    script = _install_script(root, src, GOOD_PAYLOAD)
    if preexisting is not None:
        _dest(root).parent.mkdir(parents=True)
        _dest(root).write_bytes(preexisting)
    return root, _run(script)


def test_pinned_source_installs_the_model(tmp_path):
    root, proc = _scenario(tmp_path, GOOD_PAYLOAD, preexisting=None)
    assert proc.returncode == 0, proc.stderr
    assert _dest(root).read_bytes() == GOOD_PAYLOAD
    assert _leftovers(root) == []


def test_matching_model_already_present_is_kept_without_fetching(tmp_path):
    # Source unreachable: proves the happy path does not touch the network.
    root, proc = _scenario(tmp_path, None, preexisting=GOOD_PAYLOAD)
    assert proc.returncode == 0, proc.stderr
    assert _dest(root).read_bytes() == GOOD_PAYLOAD


@pytest.mark.parametrize(
    ("label", "source_bytes", "preexisting"),
    [
        ("tampered source", GOOD_PAYLOAD[:-1] + b"X", None),
        ("truncated source", GOOD_PAYLOAD[: len(GOOD_PAYLOAD) // 2], None),
        ("tampered source over a foreign file", b"evil" * 10, b"stale"),
        # The pre-2026-10-01 hole: download fails, foreign file survived.
        ("unreachable source over a foreign file", None, b"stale model"),
        ("unreachable source, nothing present", None, None),
    ],
)
def test_any_unverified_outcome_leaves_no_model(
    tmp_path, label, source_bytes, preexisting
):
    root, proc = _scenario(tmp_path, source_bytes, preexisting)
    assert proc.returncode != 0, f"{label}: script must fail"
    assert not _dest(root).exists(), f"{label}: an unverified model was left in assets"
    assert _leftovers(root) == [], f"{label}: temp files left behind"


def test_real_script_uses_a_versioned_url_and_a_full_pin():
    pins = _real_pin()
    assert pins["MODEL_URL"].startswith(
        "https://storage.googleapis.com/mediapipe-models/"
    )
    assert "/latest/" not in pins["MODEL_URL"], "mutable latest/ alias is back"
    assert re.fullmatch(r"[0-9a-f]{64}", pins["MODEL_SHA256"])
    assert int(pins["MODEL_BYTES"]) > 0


@pytest.mark.skipif(not REAL_MODEL.exists(), reason="model not fetched on this machine")
def test_model_on_this_machine_matches_the_pin():
    pins = _real_pin()
    data = REAL_MODEL.read_bytes()
    assert len(data) == int(pins["MODEL_BYTES"])
    assert _sha256(data) == pins["MODEL_SHA256"], (
        "app/assets/models holds a model that is NOT the pinned one — it would be "
        "bundled into the next APK. Delete it and run app/tool/fetch_models.sh."
    )
