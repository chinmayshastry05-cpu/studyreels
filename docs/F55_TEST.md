# StudyReels — Round-2 test plan (Galaxy F55 5G)

Target device: Galaxy F55 5G (Snapdragon 7 Gen 1). Everything below is
100% on-device; the app has no INTERNET permission by design.

## 0. Prerequisites

- Galaxy F55 with **USB debugging** enabled, connected to your computer
  (`adb devices` shows it).
- The Cactus CLI on the computer (for model downloads).
- A lecture video already in the phone's gallery (Hindi, English, or
  Kannada — 5–15 min is ideal for round 2).

## 1. Install the APK

Download from the release page (see the release notes for the link +
SHA-256), then:

```bash
adb install studyreels-debug-arm64.apk
```

## 2. Verify the model-missing screen (before pushing models)

Launch the app. You should see **"Model not found on this device"** with
the expected path and a Recheck button. This is the fail-closed gate —
the app refuses to run inference without a local bundle.

## 3. Push both model bundles

```bash
# One-time downloads (~400 MB Qwen + ~150 MB whisper-base)
./scripts/download_model.sh
./scripts/download_transcriber.sh

# Push into the app's private files (needs the DEBUG build)
./scripts/push_model.sh <qwen-bundle-dir> qwen3-0.6b-int4
./scripts/push_model.sh <whisper-bundle-dir> whisper-base
```

Expected on-device locations:

- `/data/data/com.studyreels.app/files/models/qwen3-0.6b-int4/`
- `/data/data/com.studyreels.app/files/models/whisper-base/`

Relaunch the app — the missing-model screen must be gone.

## 4. Import a gallery video

Import tab → pick the lecture video from the gallery (system picker, no
storage permission prompt). Watch the pipeline stages:

`extract → transcribe → chunk → segment → save`

Note the wall-clock time for transcription (per minute of audio).

## 5. What to check

- **Feed**: vertical swipe; each reel loops the ORIGINAL video over its
  `[start, end]`; captions overlay; tap toggles play/pause; only the
  visible reel plays.
- **Segmentation quality**: do reel boundaries split topics/problems
  sensibly? Note 2–3 good splits and 2–3 bad ones with timestamps.
- **Transcription**: spot-check captions for errors (Hindi / English /
  Kannada / mixed). Rough word-error impression is enough for round 2.
- **Save to gallery**: download button on a reel → **Save clip (fast)**.
  Expect a "Saved to Movies/StudyReels" snackbar; open the system gallery
  → Movies/StudyReels → the clip must play, starting near the reel start
  (keyframe-aligned: may begin up to ~1 keyframe interval early).
  The "with burned-in captions" option is intentionally not built yet —
  it shows an explanatory message.
- **Library**: reels grouped by chapter → topics / problems.
- **Crashes**: note exact steps to reproduce.

## 6. How to report back

For each tested clip, send:

1. Language, clip duration, transcription wall time.
2. Segmentation: timestamps of good/bad boundaries.
3. Save-to-gallery: success/fail; clip plays? starts near reel start?
4. Any crash or wrong behavior, with steps.

A short WhatsApp message with these points is enough.

## 7. Known unproven (do not assume)

- Qwen3 0.6B inference speed/quality on the Snapdragon 7 Gen 1.
- Transcription accuracy and timestamp drift on real lecture audio.
- Segmentation quality on real lectures (the eval harness in
  `assets/eval/` is for scoring this systematically later).
- Caption burn-in export (needs a re-encode pipeline — not built).
