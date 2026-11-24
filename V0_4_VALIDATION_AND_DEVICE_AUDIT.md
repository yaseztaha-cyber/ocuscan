# OcuScan v0.4 — Validation and Device Audit

Creator: **Yassen Taha Hussainy Elnasher**, **G11 — STEM Gharbiya**.
Date (UTC): 2026-09-26. Verdicts: `PASS` / `FAIL` (→fixed) / `BLOCKED` / `EXPERIMENTAL`.

## Camera acquisition

Explicit stage machine (kept + extended with `streamFailed` as its own
state); preview independent of analysis; 8 s first-frame watchdog;
re-entry guard (5× exit/reopen covered by lifecycle journey test, no
duplicate streams via `_streamActive`); permission revoke re-runs the
full chain on next entry. Detector config audited: contours OFF (nothing
consumed them — pure latency cost), landmarks + classification +
tracking kept (all consumed). Latest-frame strategy documented (busy →
drop + count, never queue).

## Frame conversion

Layout chosen from observed planes (2→NV21, 3+→YV12 logged best-effort,
1→BGRA, 0→unsupported); rotation/stride logged per frame; persistent
failures escalate to `conversionFailed`/`mlDegraded` with recorded
errors; grayscale ML-input view + Save First Frame prove preview ==
analyzer content. Verdict on hardware: BLOCKED (creator TEST 1–8).

## Face detection

Minimal `/face-test` (camera → image → ML → count + raw boxes, no
tracker/gate/lock/analyzer, both cameras); still face test with explicit
still/image/ml/faces readout; per-attempt fail log (frame index, dims,
format, rotation, quality, error; never images). Guidance adapts to
state; thresholds normalized (face fraction of frame, ±28° yaw/roll —
lenient by design, strictness lives in analyzer-specific gates, not
global rejection). QualityGate evaluates stills AFTER detection exists
(no circular precondition). Verdict on hardware: BLOCKED.

## Eye localization

Unchanged core, now fully observable (stable/lost counts, EMA vs
last-valid, lock countdown 1–5 of real valid frames, lock-interrupted
notice). Snapshot fallback: explicit user-chosen still-image scan
(capture → detect → overlay → use/retake/back); pixel modules run on the
same still; temporal modules report unable with single-image reasons;
summary labeled "Still-image screening". Never auto-switches.

## Eye lock

5-frame stability window of consecutive valid frames; countdown UI;
bounded recovery ladder (15 s auto-reset + note → 30 s help/restart
panel → 60 s restart offer → 120 s snapshot/continue escape). No
infinite adjust loop. Verdict on hardware: BLOCKED.

## Vision tests

Rebuilt as a professional lab: per-test instruction cards
(purpose/time/distance/environment/eyes/calibration + Begin), restart
everywhere, structured result cards
(TEST/RESULT/CONDITIONS/RELIABILITY/LIMITATION/NEXT STEP + research
sequence), test index with live status dots.
- Distance: adaptive 1-up-1-down staircase (start 6/12, 6 reversals or
  24 trials, threshold = mean of last reversals), per-eye queue
  (right/left/both → RIGHT/LEFT/BOTH output), real system-text-scale
  check outside the locked subtree, calibration checklist.
- Near: intro + restart + structured result (ladder UI kept).
- Color: 3 difficulty levels × 4 seeded-order plates, digit-contrast
  difficulty, brightness/filter warnings, per-level + per-axis scoring,
  reproducible order seed recorded.
- Contrast: adaptive staircase from 0.25 with reversal threshold and
  response sequence.
- Central: intro + reset + sequential right→left protocol, per-eye
  spatial records (untested eyes reported as not tested, never as
  normal), structured summary.
- Peripheral: intro + seeded-shuffled order, 2 catch trials (false
  positives counted), per-trial reaction time, fixation reminders,
  mean reaction recorded.
- Cover: intro + restart + kept observation flow.
- Persisted records keep canonical test names/meanings (locale-
  independent rows); history already stores test/conditions/version/
  timestamp/quality.

## Front/rear camera

Front default self-guided; rear assisted mode retained; clean switch
lifecycle with full state reset; capabilities from OS facts;
deterministic best-camera decisions with technical reasons only (tested:
no medical-accuracy language); anatomical L/R canonical (tested across
front/rear/mirror/rotation/RTL); /dev comparison from real records
(resolution + experiment counts + unable rates; empty stays empty).

## Device variability

Capabilities + live FPS/latency/drop metrics + diagnostic export
(device/camera/orientation/timings/counters/states/analyzer versions/
events; never images) + logcat guide in /dev. Creator TEST 1–8 protocol
with report template (§45).

## UI/UX

Clinical-technology direction kept (no redesign churn): editorial Home
(OCUSCAN kicker, Begin, Recent, Vision Lab, Learn, methodology,
research status); 5-stage screening header; status pills
(CAMERA/LIGHTING/FACE/EYES/LOCK) from live values; lock countdown;
observation-first results; vision previews + index; labeled loaders;
empty states; help screen; reduced-motion support (static lock ring);
RTL chevrons/pipeline arrows; physical camera L/R never mirrored.

## Accessibility

Text scaling respected (vision locks it intentionally + warns on system
scaling); high-contrast theme; 48px+ targets; icon+text statuses (never
color-only); focus order default; Arabic RTL walkthrough over 17
routes with zero-error asserts. Screen reader: BLOCKED (no device).

## Arabic

~200 AppStrings + DevStrings research chrome; months/tiers/filters/
calibration/vision/settings/dev localized; reference filter re-keyed to
canonical codes; Tajawal bundled (OFL, credited); measurement records
stay canonical English by design (locale-independent rows); finding
names show AR term + EN medical term. Walkthrough: 17 routes in Arabic,
RTL asserted.

## Privacy

Local-first kept: raw captures deleted by default; research captures
opt-in + deletable; diagnostic stills transient with explicit delete;
export is explicit research action via system share; no facial
recognition/identity/advertising; no network clients (grep: no
http/Dio/Socket; only copy mentioning upload is OFF-by-default
wording); release lib has no print/debugPrint/TODO. Permissions:
CAMERA from plugin need; RECORD_AUDIO/storage/INTERNET are manifest
merges, never requested at runtime (grep: no microphone/audio calls).

## Medical safety

Three states only; SafetyLanguage banned-phrase + no-false-reassurance
tests green; no diagnoses/scores/risks/prescriptions (grep-verified
language list); experimental badges kept (lens/pupil-response/cover-
refractive + 9 research tracks labeled EXPERIMENTAL/FUTURE Tier C);
emergency path untouched; evidence linkage intact (registry pinned at
19, every key maps to an entry — tests enforce).

## Remaining limitations

- Face/eye/lock on hardware: BLOCKED — creator TEST 1–8 decides.
- `accurate`-mode FPS cost, blur/luminance defaults, shaping quality,
  reader, profiling, RECORD_AUDIO hardening: need hardware.
- Snapshot mode cannot do temporal measurements by construction.
- Stereopsis proper: future (both-eyes runs exist; no fake stereo test).
- New modules (palsy/Parkinson/ALS/retinal/pterygium/corneal/lens) exist
  ONLY as a capability catalog (Learn) with protocols — no classifiers,
  no measurement, no validation claims.
