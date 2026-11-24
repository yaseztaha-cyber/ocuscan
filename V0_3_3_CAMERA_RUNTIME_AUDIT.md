# OcuScan v0.3.3 — Camera Runtime Audit

Creator: **Yassen Taha Hussainy Elnasher**, **G11 — STEM Gharbiya**.
Date (UTC): 2026-09-26. Verdicts: `PASS` / `FAIL` (→fixed) / `BLOCKED` / `EXPERIMENTAL`.

The v0.3.2 APK still stuck at "Starting camera" on the creator's phone.
This iteration assumes nothing and proves the complete physical-device path.

## 1. Camera state machine

`CameraStage`: idle → requestingPermission → initializing / switching →
previewReady → streamStarting → firstFrame → processing, plus distinct
failure states: permissionDenied, initFailed, streamFailed, noFirstFrame
(via watchdog), conversionFailed, mlDegraded. Preview progress and
analysis progress are independent predicates (`previewUp` /
`analysisFlowing`): a working preview with dead analysis reads exactly
that way. Implemented in `camera_service.dart`, rules in
`camera_pipeline.dart`, tested in `camera_pipeline_test.dart`.

## 2. Real frame pipeline

`availableCameras` (lens list recorded) → controller init → previewReady
→ `startImageStream` → first frame (size/format/planes/stride/rotation
recorded) → per-frame ML input built from the OBSERVED plane layout
(2-plane NV21, 3+-plane YV12 best-effort, 1-plane BGRA; 0-plane =
unsupported, never corrupt-guessed) → detector → geometry → tracker.
Every stage transition, lens choice, stream start/release/switch/restart
is timestamped in a 60-event ring; every failure is a `CameraError`
(stage, type, message, stack, time), full detail in /dev only.
_ML input layout is the prime suspect for "preview perfect, detection
dead": declaring NV21 over planar YUV corrupts detector input
silently — now chosen dynamically and logged per frame._

## 3. ML input pipeline

Bytes concatenated per observed layout; rotation from sensor + device
orientation; `bytesPerRow` from plane 0; format/stride/rotation logged in
`ML_INPUT` events and the frame log. Detector created once (accurate,
landmarks + contours + classification + tracking), closed once with a
guarded async close. Consecutive-error counters escalate to
`conversionFailed` (≥5, zero processed) / `mlDegraded` (≥10, zero
processed); transient errors never kill the pipeline. Latest-frame
strategy: busy analyzer drops + counts obsolete frames, never queues.

## 4. Coordinate transforms

Single authority: `EyeCoords.imageToPreview` (raw → rotate → mirror →
cover-fit) plus `eyeRegion` crops and `mlKitRotationDeg` (standard
compensation formula). Canonical internal representation is the
subject's physical eye; the overlay may mirror the selfie, analyzer data
never swaps. Pinned by 31 tests (portrait/landscape/mirrored/direct,
resolutions, clamping) + 2 anatomical-side tests (front/rear/rotation/RTL
independence). Still-space (`analyzeStill`) is labeled as a different
space (rotation 0, unmirrored).

## 5. Eye tracking

Unchanged v0.3.2 core (12 diagnostic states, EMA smoothing, 5-frame loss
budget with stale-marking, 5-frame lock window, per-analyzer
`meetsNeed`). New in v0.3.3: full observability — stable/lost frame
counts, EMA vs last-valid positions and lock state visible in the Eyes
UI countdown and /dev pipeline card; recovery ladder (auto tracker reset
once at 15 s stuck with an honest note; help/restart panel at 30 s;
restart offer at 60 s; explicit continue-without-lock at 120 s, which
downstream records as unable-to-assess). Never loops forever.

## 6. Device compatibility

Capabilities per physical camera (lens, sensor orientation, name;
preview size post-init) from the OS list — never assumed. Best-camera
decision is deterministic with technical reasons only (self-guided →
front for visible preview; high-detail → higher measured preview
resolution, else honest "not yet measured"); ties/unknowns default to
front, stated. No medical-accuracy claims anywhere (tested: reason
strings contain no diagnosis/accuracy language). Front/rear/best
selector on the Eyes stage; clean switch lifecycle (stop → release →
recreate → preview → first frame → state reset, one controller alive,
switching state distinct from initializing); rear assisted mode (stable
surface guidance, large distance/direction cues); retinal sources still
refuse non-retinal input by design.

## 7. Failure modes (each with exact UI)

Permission denied → dialog + settings route; init failure → calm error
banner, flow reports unable; no first frame in 8 s → watchdog panel
("couldn't start the camera stream", Retry, help); conversion/ML
persistent failure → "Camera ready / trouble analyzing" panel, camera
stays active; face missing → "move into frame"; eyes missing →
side-specific guidance; unstable → hold-still; lock interrupted →
explicit notice (not silent restart); 120 s stuck → continue-without-lock
escape. Normal users never see stack traces; /dev shows type, message,
stack, stage, timestamp.

## 8. Recovery system

Startup watchdog (8 s, UI-polled, pure-function core), stuck-state
ladder (§5), hard camera restart (stop → dispose → 400 ms settle →
recreate), tracker reset, 5× re-entry lifecycle (covered by existing
lifecycle journey test: exit/re-enter without crash, no duplicate
streams via `_streamActive` guard), permission revoke → prepare()
re-runs the full chain on next entry.

## 9. Performance

Measured live in /dev: frames received/processed/dropped, arrival FPS,
processing FPS, last latency, last-frame age, per-frame luminance/blur.
Memory: single concat buffer per frame + optional single retained
grayscale ML preview (dev-only flag); stills decoded on demand only.
Isolate offload and 60-second profiling deferred to on-device runs
(BLOCKED here).

## 10. Privacy

Diagnostic report contains device/camera/orientation/timings/counters/
states/versions/events — never images (ML preview is grayscale bytes
shown on-device only; stills deleted on exit; diagnostic frame has an
explicit delete). Export is research-mode only via system share sheet.
No network calls added (grep-clean).

## 11. Physical-device verification

BLOCKED in this environment (`adb devices` empty; emulator offline).
NOT claimed. Creator protocol (Tests A–I per spec §44) ships in-app via
/eye-debug (Test A–F observable: camera info, frame inspector, pipeline
card, lock UI, analyzer summary, release/re-entry) plus the v0.3.2
condition matrix (distance/lighting/angle/glasses with exact guidance
text). Report template: stage reached, frame counts, rotation/sensor
readout, failure state + guidance shown.

## 12. Tests

- `camera_pipeline_test.dart` (17): stage predicates, format choice incl.
  3-plane→YV12 and 0-plane→unsupported, watchdog idle/waiting/ok/timeout,
  ladder escalation bounds, best-camera decisions + no-medical-claims,
  anatomical sides.
- Full suite: 168/168 PASS (151 baseline + 17 new), 0 regressions.
- Journeys extended: camera selector + help presence on the Eyes stage;
  AR walkthrough now covers 16 routes incl. `/camera-help`, `/eye-debug`.

## 13. APK details

- Path: `D:\YASEZ_HOME\projects\medical eye app\build\app\outputs\flutter-apk\app-release.apk`
- Size: 85.5 MB. `aapt`: `com.ocuscan.ocuscan` versionName `0.3.3` versionCode `3`, minSdk 24 / targetSdk 36.
- Pipeline: clean → pub → analyze EXIT 0 → test 168/168 EXIT 0 → build EXIT 0.
- Physical-device install/test: BLOCKED here (no device attached) — NOT claimed.
