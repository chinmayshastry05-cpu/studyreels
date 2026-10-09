#!/usr/bin/env bash
#
# StudyReels — push the Cactus model bundle to the phone (one-time).
#
# The app has no INTERNET permission by design, so the model bundle is
# fetched on a dev machine (scripts/download_model.sh) and pushed here
# into the app's private files dir:
#   /data/data/com.studyreels.app/files/models/qwen3-0.6b-int4/
#
# Requires a DEBUG build on the device (run-as only works on debuggable
# builds). For release builds the bundle must be packaged differently
# (planned).
#
# Usage:
#   ./scripts/push_model.sh <bundle-dir> [dest-dir-name]
# Example:
#   ./scripts/push_model.sh ~/.cactus/models/Cactus-Compute_Qwen3-0.6B qwen3-0.6b-int4
#   ./scripts/push_model.sh ~/.cactus/models/Cactus-Compute_whisper-base whisper-base
#
set -euo pipefail

PKG="com.studyreels.app"
BUNDLE_DIR="${1:-}"
# Default destination: the bundle dir's own name.
MODEL_DIR="${2:-$(basename "${BUNDLE_DIR:-model}")}"

if [[ -z "$BUNDLE_DIR" ]]; then
  echo "usage: $0 <bundle-dir> [dest-dir-name]" >&2
  exit 1
fi
if [[ ! -d "$BUNDLE_DIR" ]]; then
  echo "Not a directory: $BUNDLE_DIR" >&2
  exit 1
fi

echo "Pushing $BUNDLE_DIR to device tmp ..."
adb push "$BUNDLE_DIR" /data/local/tmp/studyreels_model

echo "Copying into $PKG private files (needs a debug build) ..."
adb shell "run-as $PKG mkdir -p files/models/$MODEL_DIR"
adb shell "run-as $PKG cp -r /data/local/tmp/studyreels_model/. files/models/$MODEL_DIR/"
adb shell "rm -rf /data/local/tmp/studyreels_model"

echo "Verifying ..."
adb shell "run-as $PKG ls -la files/models/$MODEL_DIR" | head -10
echo "OK: model installed at /data/data/$PKG/files/models/$MODEL_DIR/"
