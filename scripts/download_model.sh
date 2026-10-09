#!/usr/bin/env bash
#
# StudyReels — one-time model fetch (Phase 1).
#
# Fetches the prebuilt Cactus bundle for Qwen3-0.6B (int4, ~400 MB) with the
# Cactus CLI. Alternatives:
#   cactus download Cactus-Compute/Qwen3-0.6B --bits 8   # higher quality
#   cactus convert Qwen/Qwen3-0.6B --bits 4              # convert from HF
#   cactus convert Qwen/Qwen3-0.6B --bits 4 --lora <path>  # phase 2: merge
#                                                        # an Unsloth LoRA
#
# After downloading, push the bundle folder to the phone, e.g.:
#   adb push ~/.cactus/models/Cactus-Compute_Qwen3-0.6B \
#       /sdcard/StudyReels/models/qwen3-0.6b-int4/
# and pass that path to CactusLlmBackend.init().
#
# The model bundle itself is NEVER committed (see .gitignore).
#
set -euo pipefail

if ! command -v cactus >/dev/null 2>&1; then
  echo "The 'cactus' CLI is not installed." >&2
  echo "Install it (macOS): brew install cactus-compute/cactus/cactus" >&2
  echo "Then re-run this script. Docs: https://github.com/cactus-compute/cactus" >&2
  exit 1
fi

echo "Downloading prebuilt bundle: Cactus-Compute/Qwen3-0.6B (int4) ..."
cactus download Cactus-Compute/Qwen3-0.6B --bits 4

echo
echo "Done. Locate the bundle (usually ~/.cactus/models) and push it to the phone:"
echo "  adb push <bundle-dir> /sdcard/StudyReels/models/qwen3-0.6b-int4/"
