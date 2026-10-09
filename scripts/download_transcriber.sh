#!/usr/bin/env bash
#
# StudyReels — fetch the on-device transcription model (one-time, dev machine).
#
# whisper-base (Cactus-Compute/whisper-base): smallest Cactus transcription
# model with usable Hindi + English. whisper-tiny exists but its Hindi is
# poor; moonshine/parakeet are English-only and parakeet gives no timestamps.
# Language is auto-detected per lecture (mixed Hindi/English works).
#
# Afterwards push it to the phone:
#   ./scripts/push_model.sh <bundle-dir> whisper-base
#
set -euo pipefail

if ! command -v cactus >/dev/null 2>&1; then
  echo "The Cactus CLI is required: https://github.com/Cactus-Compute/cactus" >&2
  echo "(used only on the dev machine; the app itself never touches the network)" >&2
  exit 1
fi

cactus download Cactus-Compute/whisper-base
echo "OK: whisper-base bundle downloaded. Push it with:"
echo "  ./scripts/push_model.sh <bundle-dir> whisper-base"
