# OcuScan v0.3.4 — Face Detection Audit

Creator: **Yassen Taha Hussainy Elnasher**, **G11 — STEM Gharbiya**.
Date (UTC): 2026-09-26. Verdicts: `PASS` / `FAIL` (→fixed) / `BLOCKED` / `EXPERIMENTAL`.

Device report: camera screen opens, face never detected ("Starting
camera" persists). v0.3.2's rotation fix did not resolve it on hardware.
This iteration stops assuming and proves each stage.

## Root Cause

No single root cause is proven without hardware. The honest finding is a
**diagnostic gap, not a threshold bug**: v0.3.3 and earlier collapsed
permission → init → preview → stream → first frame → conversion → ML →
face → eyes → lock into one "Starting camera" state with silently
swallowed per-frame exceptions, so the first failing box was
unidentifiable. Candidate first-failure boxes, in pipeline order:

1. No image-stream frames arrive (preview uses a separate path and can
   look perfect while analysis starves).
2. `InputImage` built with the wrong layout (NV21 declared over planar
   YUV, wrong stride/rotation) — corrupt ML input, zero faces, no error.
3. ML Kit detector failing on-device (services/model/device behavior) —
   exceptions were swallowed by `catch (_)`.
4. Tracker/UI never receiving success (state plumbing).

v0.3.4 instruments every box (§2–§11 below) and adds a minimal
tracker-free face test plus a still-image path that separates stream
problems (Case A) from detector problems (Case B). The creator's run
decides between them.

## Camera Pipeline

Explicit `CameraStage` machine (v0.3.3, kept): idle →
requestingPermission → initializing/switching → previewReady →
streamStarting → firstFrame → processing, with permissionDenied,
initFailed, streamFailed, noFirstFrame (8 s watchdog), conversionFailed,
mlDegraded. Preview and analysis are independent predicates. Every
transition, lens choice, release, switch, and restart is timestamped in
a 60-event ring; every failure is a recorded `CameraError`
(stage/type/message/stack/time), full detail in /dev only. Detector
created once, closed once (guarded). Latest-frame strategy (busy →
drop + count).

## Frame Pipeline

Per-frame record: monotonic `frameIndex`, timestamp, width, height,
format group, plane count, row stride, rotation, declared ML layout,
luminance, blur. Watchdog: first frame within 8 s or the exact failed
stage is shown with Retry. Counters: received/processed/dropped,
arrival FPS, processing FPS, latency, last-frame age — all live in the
Camera Health panel and /dev frame inspector. Failed attempts logged
with frame index + facts, never images.

## ML Kit Input

Layout chosen from OBSERVED planes (2→NV21, 3+→YV12 best-effort logged,
1→BGRA, 0→unsupported, never corrupt-guessed); rotation from sensor +
device orientation; stride from plane 0. ML errors counted
consecutively (≥10 with zero processed → `mlDegraded`); conversion
errors likewise (≥5 → `conversionFailed`). Transient errors never kill
the pipeline. Grayscale ML-input view (rotation-corrected) plus Save
First Frame (still + ML view persisted locally, explicit delete) make
preview-vs-analyzer content directly comparable.

## Face Detection

Minimal `/face-test` screen (from /dev): live preview, RAW ML Kit boxes
overlaid unmodified, face count, PASS/FAIL, box coords, rotation, image
size, FPS, ML-ready flag, front/rear selector. No tracker, gate, lock,
or analyzer. Still face test in /dev with explicit
still/image/ml/faces readout. Face-fail log per attempt. Guidance
adapts to state (no-face / too small / too large / angled /
detected→finding-eyes); thresholds normalized (fraction of frame, ±28°
yaw/roll), analyzer-specific strictness only where a module needs it.
QualityGate runs on stills AFTER detection exists — never as a
face-existence precondition (no circular dependency).

## Coordinate System

One authority (`EyeCoords.imageToPreview`: raw → rotate → mirror →
cover-fit) plus still-space labeling; anatomical L/R canonical
(subject's physical eye, never swapped for RTL/mirror). Covered by
transform tests; face-test overlay draws raw boxes through the same
mapping.

## Front Camera

Default self-guided path: mirrored preview, live overlay, staged
positioning, lock gate. Face test proves the same pipeline per lens.

## Rear Camera

Selector + clean switch lifecycle (stop → release → recreate → preview →
first frame → full state reset, one controller, distinct switching
state) + assisted mode (stable-surface guidance, large distance /
direction cues) + comparison table (preview resolution + experiment
counts + unable rates from real records only) + research experiments
groupable by recorded camera field.

## Snapshot Fallback

Explicit, never automatic: recovery ladder (15 s auto tracker-reset +
note → 30 s help/restart panel → 60 s restart offer → 120 s
continue-without-lock) and the analysis-blocked panel both offer the
still-image scan. SnapshotScanView: capture → detect → overlay →
Use/Retake/Back-to-live; stills transient (deleted on exit). Accepted
snapshot feeds pixel analyzers (redness, scleral, eyelid via still
openness) from the SAME still; temporal modules (movement, blink,
response) report unable with single-image reasons; summary labeled
"Still-image screening". Modules never silently substitute
incompatible measurements.

## Eye Detection

Unchanged core (gated behind proven face detection per spec §38); now
fully observable (stable/lost counts, EMA vs last-valid, lock state in
UI countdown + /dev). Recovery bounded; camera never restarted for
downstream failures.

## Performance

Live FPS/latency/drop metrics in /dev (real data only); single concat
buffer per frame; dev-only single-frame ML grayscale retention;
stills decoded on demand. Isolate offload + 60 s profiling deferred to
on-device runs (BLOCKED here).

## Privacy

Diagnostic report = device/camera/orientation/timings/counters/states/
versions/events — never images. ML preview is on-device grayscale;
stills deleted on exit; diagnostic frame has explicit delete; export is
research-only via system share. No network calls added.

## Physical Device Verification

BLOCKED here (`adb devices` empty; emulator offline) — NOT claimed.
Creator protocol: TEST 1 face-test count>0 → TEST 2 box follows face →
TEST 3/4 distance guidance → TEST 5 head-angle state → TEST 6/7
front↔rear switch recovery → TEST 8 still face test (still/image/ml +
faces). Report template (§45): device, front/rear, preview, frames,
still capture, face detection, face overlay, eye detection/lock
(PASS/FAIL/NOT TESTED). The failing box + /dev readouts decide the next
iteration — no guessing, no threshold tuning blind.

## Remaining Limitations

- First failing box unknown until the creator runs TEST 1–8.
- `accurate`-mode FPS cost, blur/luminance defaults, Arabic shaping
  quality, screen reader, profiling: need hardware.
- Snapshot mode cannot do temporal measurements by construction.
- `RECORD_AUDIO` manifest hardening still deferred to an on-device pass.
