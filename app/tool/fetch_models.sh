#!/usr/bin/env bash
# Fetches the on-device segmentation model(s) into app/assets/models/.
#
# Phase 2.5 (D21): MediaPipe Selfie Multiclass — 16.37 MB Apache-2.0 .tflite
# published by Google. The asset is GITIGNORED (never in the repo); this
# script is the reproducible way to obtain it on any machine, pinned by
# SHA-256. Build-time fetch only: the app itself never downloads anything
# at runtime (D2: 100% offline).
#
# Usage:  bash app/tool/fetch_models.sh        (from the repo root)
#         bash tool/fetch_models.sh            (from app/)
#
# Windows note: some AV/TLS-intercepting proxies break curl's certificate
# revocation check - this script already passes --ssl-revoke-best-effort,
# which is harmless elsewhere.
#
# FAIL CLOSED (security audit Q2, 2026-10-01): whatever happens, the asset
# directory ends up holding either the pinned model or NO model — never an
# unverified file that `flutter build` would bundle into the APK. A stale or
# foreign file at the destination is deleted before downloading; the
# download goes to a temp file and is moved into place only after its size
# and SHA-256 match. Locked by cv_core/tests/test_model_fetch_lock.py.
set -euo pipefail

# Versioned URL (`float32/1/`), not the mutable `float32/latest/` alias: on
# 2026-10-01 both served the same object (same size + MD5 as the pinned file),
# but `latest/` may be repointed upstream at any time. The SHA-256 pin is what
# protects the build either way; the version only keeps the fetch reproducible.
MODEL_URL="https://storage.googleapis.com/mediapipe-models/image_segmenter/selfie_multiclass_256x256/float32/1/selfie_multiclass_256x256.tflite"
MODEL_SHA256="c6748b1253a99067ef71f7e26ca71096cd449baefa8f101900ea23016507e0e0"
MODEL_BYTES=16371837

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST_DIR="$SCRIPT_DIR/../assets/models"
DEST="$DEST_DIR/selfie_multiclass_256x256.tflite"

mkdir -p "$DEST_DIR"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | cut -d' ' -f1
  else
    shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

if [[ -f "$DEST" ]]; then
  if [[ "$(sha_of "$DEST")" == "$MODEL_SHA256" ]]; then
    echo "OK (already present): $DEST"
    exit 0
  fi
  rm -f "$DEST"
  echo "Existing model did not match the pin — deleted; re-fetching." >&2
fi

# Temp file OUTSIDE assets/models/ (that whole directory is bundled into the
# APK) but on the same filesystem, so the final move is a rename.
TMP="$(mktemp "$SCRIPT_DIR/.model-fetch.XXXXXX")"
trap 'rm -f "$TMP"' EXIT

echo "Fetching selfie_multiclass_256x256.tflite ($MODEL_BYTES bytes)..."
curl -fSL --ssl-revoke-best-effort -o "$TMP" "$MODEL_URL" \
  || curl -fSL -o "$TMP" "$MODEL_URL"

GOT_BYTES="$(wc -c < "$TMP" | tr -d ' ')"
GOT="$(sha_of "$TMP")"
if [[ "$GOT_BYTES" != "$MODEL_BYTES" || "$GOT" != "$MODEL_SHA256" ]]; then
  echo "Model rejected: got $GOT_BYTES bytes / SHA-256 $GOT," \
    "want $MODEL_BYTES / $MODEL_SHA256 — nothing installed." >&2
  exit 1
fi
mv -f "$TMP" "$DEST"
echo "OK: $DEST"
