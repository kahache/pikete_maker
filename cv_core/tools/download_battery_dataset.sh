#!/usr/bin/env bash
# Download the Fashionpedia val/test-2020 images used by the QA mass battery
# (issues #24/#23). These live in samples/g0/raw/test/ which is GITIGNORED, so
# a fresh clone / a different machine (e.g. moving from the Mac to the PC) has
# to re-fetch them before running cv_core/tools/mass_battery.py.
#
# Source: the images are hosted publicly by CVDF on S3 (the same URL recorded
# in samples/g0/MANIFEST.md). Only the images are needed — the battery is
# unsupervised and does not read the Fashionpedia annotations.
#
# LICENSING: individual images carry mixed Flickr/Unsplash licenses (some
# CC BY-NC-ND). This download is for INTERNAL QA evaluation only; do NOT
# redistribute the images. See samples/g0/MANIFEST.md for details.
#
# Idempotent: does nothing if the 3200 images are already present.
#
# Usage (from anywhere):  bash cv_core/tools/download_battery_dataset.sh
set -euo pipefail

URL="https://s3.amazonaws.com/ifashionist-dataset/images/val_test2020.zip"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"  # repo root
DEST="$ROOT/samples/g0/raw"
TEST_DIR="$DEST/test"
EXPECTED=3200

count() { ls "$TEST_DIR"/*.jpg 2>/dev/null | wc -l | tr -d ' '; }

if [ "$(count)" = "$EXPECTED" ]; then
  echo "Battery dataset already present ($EXPECTED images in $TEST_DIR). Nothing to do."
  exit 0
fi

mkdir -p "$DEST"
ZIP="$DEST/val_test2020.zip"

echo "Downloading Fashionpedia val/test-2020 (~226 MB) -> $ZIP ..."
if command -v curl >/dev/null 2>&1; then
  curl -fL --retry 3 -o "$ZIP" "$URL"
elif command -v wget >/dev/null 2>&1; then
  wget -O "$ZIP" "$URL"
else
  echo "ERROR: need curl or wget on PATH." >&2
  exit 1
fi

echo "Extracting ..."
if command -v unzip >/dev/null 2>&1; then
  unzip -q -o "$ZIP" -d "$DEST"
else
  # Fallback when unzip is absent (e.g. the snap sandbox): Python's zipfile.
  python3 -m zipfile -e "$ZIP" "$DEST"
fi
rm -f "$ZIP"

got="$(count)"
echo "Done: $got images in $TEST_DIR."
if [ "$got" != "$EXPECTED" ]; then
  echo "WARNING: expected $EXPECTED images, got $got." >&2
  exit 1
fi
echo "Now reproducible: cd cv_core && python tools/mass_battery.py --n 200  (seed 42)"
