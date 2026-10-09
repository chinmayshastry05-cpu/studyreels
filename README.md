# StudyReels

A fully local study app: import a lecture video, split it into reels
(1 topic = 1 reel, 1 problem = 1 reel) with captions, swipe through them
TikTok-style, saved organized by chapter/topic. **All on-device, no cloud
calls — at inference the phone never touches the network.**

## Locked product principles

1. **The LLM stays VERY TINY.** Qwen3 0.6B is the target. It will be
   fine-tuned into a *specialist* for exactly one job — lecture transcript
   → topic/problem boundaries (JSON). Master of one, not jack of all.
2. **100% local inference.** No cloud APIs, no paid services, no analytics,
   no telemetry. The app does not even request the INTERNET permission.
3. **Reels are timestamp-based**: original video + start/end + overlay
   captions. Never re-rendered clips.

## NOTICE — Cactus license (source-available, NOT open source)

StudyReels runs its on-device LLM through [Cactus](https://github.com/cactus-compute/cactus)
(Copyright © 2025 Cactus Compute, Inc.), referenced as a git submodule under
`third_party/cactus` with its LICENSE intact. Only the documented Flutter
binding file (`lib/cactus/cactus.dart`, verbatim + attribution header) is
vendored.

Cactus is **source-available**, not OSI open-source. The free grant covers:

- individuals using it for personal, educational, research, or
  non-commercial purposes;
- organizations with **under $2M USD total funding AND under $2M USD gross
  annual revenue**;
- educational institutions, students, and registered non-profits.

Anyone else needs a commercial license from Cactus Compute
(founders@cactuscompute.com). If a qualifying org later exceeds either $2M
threshold, the grant terminates and a commercial license is due within 30 days.
Read `third_party/cactus/LICENSE` for the full terms.

## 100% local rules (enforced in code)

- Every `cactusComplete` call passes `{"auto_handoff": false}`.
- Never set a Cactus cloud API key. Never enable telemetry.
- Every engine response is asserted to have `cloud_handoff == false`
  (fail closed — a missing field counts as a violation and throws).
- Covered by unit tests: `test/cactus_local_only_test.dart`.

## JSON enforcement (no GBNF in Cactus)

Cactus completion options have no grammar support, so constrained decoding
is replaced by three layers:

1. a strict prompt demanding JSON-only output (`assets/prompts/segmentation_prompt.md`),
2. a Dart-side parser + boundary validator
   (`SegmentationService.parseAndValidate`: schema, sorted, non-overlapping,
   within chunk range),
3. retry with a repair prompt (default 2 retries).

## Repo layout

```
studyreels/
├── lib/
│   ├── main.dart                    # app shell + bottom nav
│   ├── cactus/cactus.dart           # vendored Cactus Dart FFI binding (see NOTICE)
│   ├── data/
│   │   ├── models/                  # segment.dart, reel.dart, chapter.dart
│   │   └── services/
│   │       ├── llm_service.dart     # CactusLlmBackend (FFI) + test fakes
│   │       ├── segmentation_service.dart  # prompt + validate + retry
│   │       ├── video_import_service.dart  # phase-1 stub
│   │       └── library_store.dart   # in-memory library by chapter
│   └── ui/
│       ├── screens/                 # feed (vertical swipe), library, import
│       └── widgets/reel_card.dart
├── test/
│   ├── segmentation_test.dart       # schema/boundary rules + retry
│   ├── cactus_local_only_test.dart  # auto_handoff + cloud_handoff asserts
│   └── models_test.dart
├── android/                         # standard Flutter android tree
│   └── app/src/main/
│       ├── jniLibs/arm64-v8a/       # ← put libcactus_engine.so here (built, not committed)
│       └── java/com/studyreels/app/MainActivity.java
├── third_party/cactus               # git submodule (LICENSE intact)
├── assets/
│   ├── prompts/segmentation_prompt.md
│   └── samples/sample_transcript.txt
├── scripts/download_model.sh        # one-time model fetch via cactus CLI
└── README.md
```

## Phase 1 — build steps

Prerequisites:

- Flutter **3.47.7** stable (Dart bundled). `flutter doctor` should be clean
  for the `flutter` tool; Android toolchain needed only for APK builds.
- Android Studio + **Android NDK r26 or newer** (for `cactus build --android`).
- Cactus CLI: `brew install cactus-compute/cactus/cactus` (macOS; see the
  Cactus repo for other platforms).
- Target device: Galaxy F55 5G (Snapdragon 7 Gen 1, Android, arm64-v8a).

Steps:

```bash
# 1. Clone with the Cactus submodule
git clone --recurse-submodules https://github.com/chinmayshastry05-cpu/studyreels.git
cd studyreels

# 2. Build the engine for Android (needs NDK r26+)
cactus build --android
# → copy android/libcactus_engine.so to
#   studyreels/android/app/src/main/jniLibs/arm64-v8a/

# 3. Fetch the tiny model bundle (one-time, dev machine only)
./scripts/download_model.sh
# → prebuilt Cactus-Compute/Qwen3-0.6B int4 bundle (~400 MB)

## Transcription (phase 2C)

Lecture audio → timestamped transcript, 100% on-device:

1. **Audio extraction** — `AudioExtractor` (Android `MediaExtractor` +
   `MediaCodec`, platform channel `com.studyreels.app/audio`) decodes the
   video's audio track to a 16 kHz mono 16-bit WAV in one streaming pass
   (constant memory, no network).
2. **ASR model** — whisper-base (`Cactus-Compute/whisper-base`), the smallest
   Cactus transcription model with usable Hindi + English. whisper-tiny's
   Hindi is poor; moonshine/parakeet are English-only and parakeet returns
   no timestamps. Language is auto-detected per lecture.
3. **Transcribe** — `TranscriptionService` calls `cactus_transcribe` with
   `{"timestamps":true}` and parses `{start, end, text}` segments.
   `cloud_handoff` is asserted false (fail closed).
4. **Chunk** — `TranscriptChunker` groups segments into 1,200–2,000-token
   windows using the segmentation model's own tokenizer
   (`cactus_tokenize`), ready for the topic-boundary LLM.

```bash
./scripts/download_transcriber.sh          # fetch whisper-base (dev machine)
./scripts/push_model.sh <bundle-dir> whisper-base   # push to the phone
```

Status: services + chunker + tests are in; on-device transcription speed /
accuracy not yet measured (needs a real phone run).

## Feed, playback & library (phase 2D)

- **Import tab**: pick a local video (`file_picker`), name the chapter, and run
  the full on-device pipeline — audio extraction, whisper transcription in a
  background isolate (the UI thread never blocks), 1.2K–2K token chunking,
  tiny-LLM topic/problem segmentation, reels saved to the library.
- **Reels tab**: TikTok-style vertical swipe feed. Each reel plays the
  ORIGINAL video file with `video_player`, looping its `[start, end]` range —
  never a re-rendered clip. Transcript captions overlay the video; tap toggles
  play/pause; only the visible page plays.
- **Library tab**: reels persisted as local JSON (`library.json` in the app
  documents dir), grouped by chapter, split into topics/problems. Tapping a
  reel opens it in the full-screen player.

Status: UI + pipeline + persistence are in; playback and the end-to-end
import flow are not yet run on a real device.

# 4. Push the bundle into the app's private files (debug build on device)
./scripts/push_model.sh <bundle-dir>
# → /data/data/com.studyreels.app/files/models/qwen3-0.6b-int4/
# If the bundle is missing, the app shows a "model missing" screen with the
# exact expected path instead of crashing.

# 5. Dart side
flutter pub get
flutter analyze
flutter test

# 6. Build & install (Android Studio or CLI)
flutter build apk --release
flutter install
```

In the app, pass `/sdcard/StudyReels/models/qwen3-0.6b-int4/` to
`CactusLlmBackend.init()` on first launch (wiring the settings/path UI is
still phase-1 work).

### Engine parameters (locked)

- Context: 4K. Transcript windows: 1.2K–2K tokens per chunk.
- Thinking disabled via `/no_think` in the prompt (Qwen3).
- Temperature 0.2, `max_tokens` 512 per segmentation call.

## What is verified vs untested (honest, 2026-10-09)

**Verified in this environment (Flutter 3.47.7, Linux):**

- `flutter analyze` — output recorded below.
- `flutter test` — all tests pass (segmentation schema/boundary rules,
  retry logic, local-only policy asserts, model round-trips).
- Cactus Flutter binding integration steps verified against the Cactus repo
  README/docs (`bindings/flutter`): copy `cactus.dart`, add `ffi` to
  pubspec, `cactus build --android`, `.so` into `jniLibs/arm64-v8a/`.
- `cactus download` / `cactus convert` / `--lora` / `--bits` flags verified
  against Cactus CLI docs.
- `Cactus-Compute/Qwen3-0.6B` bundle listing verified on Hugging Face
  (`weights/qwen3-0.6b-int4.zip`, `weights/qwen3-0.6b-int8.zip`).
- Cactus license terms verified from the repo LICENSE file.
- Cactus submodule pinned at commit `2cfcdb8` (v2.2.2, shallow clone).

**NOT verified / untested:**

- `libcactus_engine.so` was **not** built here (no Android NDK in this
  environment). The Dart FFI service code is written against the documented
  binding API but is **UNTESTED** against a real engine build.
- `flutter build apk` was **not** run here.
- On-device inference (segmentation quality, speed, RAM on Snapdragon 7 Gen 1)
  is untested — that happens on the Galaxy F55 5G.
- Transcription (whisper/moonshine/parakeet via Cactus) is built into Cactus
  for later phases; not wired yet.
- YouTube import via yt-dlp: planned, not implemented.

## Phase 2 — fine-tune plan (documented, NOT started)

Goal: turn Qwen3 0.6B into a **specialist** that does one job extremely well
— transcript → topic/problem boundary JSON — instead of a generalist.

1. **Training data.** Generate segmentations of real lecture transcripts
   (with timestamps) using big free models; curate into
   prompt → boundary-JSON pairs. Keep transcripts the student has the right
   to use.
2. **Fine-tune.** QLoRA fine-tune of Qwen3 0.6B with **unsloth** on **free
   Colab**. No paid services. (The phone cannot train — training happens
   once on Colab; inference stays 100% on-device forever.)
3. **Save permanently.** Store the trained model in two places: his 05
   Google Drive, and as a GitHub release **or** a Hugging Face repo under
   his account.
4. **Merge into the app.** `cactus convert Qwen/Qwen3-0.6B --bits 4 --lora <path>`
   merges the Unsloth LoRA into a Cactus bundle; drop it into the app's
   model dir.
5. **Stay tiny.** When choosing the fine-tune base, also evaluate
   **SmolLM2 135M and 360M** — if either handles the boundary-JSON job,
   prefer the smaller one. After fine-tuning, try quantizing further
   (e.g. int4 → int2/int3); keep the smaller quant only if segmentation
   quality holds on a held-out lecture set.

## Model provenance

- Phase-1 base: `Cactus-Compute/Qwen3-0.6B` (int4 bundle) via `cactus download`.
- Quality fallback path: `cactus convert Qwen/Qwen3-0.6B --bits 4`
  (or `--bits 8`).
- Weights are fetched at build time and never committed.
