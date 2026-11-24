# OcuScan v0.7 — Final Product Audit

Creator: **Yassen Taha Hussainy Elnasher**, **G11 — STEM Gharbiya**.
Date (UTC): 2026-09-27. Verdicts: `PASS` / `FAIL` (→fixed) / `BLOCKED` / `EXPERIMENTAL`.
No certification of any kind is claimed anywhere in this document or the app.

## Architecture

Acquire → check input → localize → measure → check quality → estimate
uncertainty → screen (3 states) → explain → cite evidence → guide.
Single camera pipeline, single database (v5), single analyzer registry
(19 pinned). See SYSTEM_ARCHITECTURE.md.

## Camera

Staged machine (idle → … → processing + 6 distinct failure states);
preview/analysis split; fallback configs (medium/nv21 → low → yuv420);
resolution escalation after 150 faceless flowing frames; stale-stream
rebuild; watchdog (8 s); observed-layout ML input with truncation
rejection; latest-frame strategy; FPS/latency/drop counters; recorded
errors/events; front/rear/best sources with clean switching.
Verdict on hardware: BLOCKED (creator TEST 1–8).

## Frame pipeline

Per-frame record (index, size, format, planes, stride, rotation,
declared layout, quality). Truncated buffers rejected loudly, never fed
to ML Kit. Grayscale ML-input view + Save First Frame for inspection.

## Face

Minimal `/face-test` (raw boxes, count, PASS/FAIL, both cameras, no
tracker); still face test with explicit readout; per-attempt fail log;
largest-face forwarding with `multipleFaces` refusal; all boxes visible
in research. Thresholds normalized and lenient; strictness lives in
analyzer gates. Verdict on hardware: BLOCKED.

## Eyes

EyeTracker unchanged in core (12 states incl. multipleFaces, EMA,
5-frame loss budget, 5-frame lock); fully observable (stable/lost,
EMA vs last-valid, countdown); bounded recovery ladder; snapshot
fallback with temporal modules honestly unable. Verdict: BLOCKED.

## ML

ML Kit face detector (accurate; landmarks + classification + tracking;
contours OFF as unused) + 12 deterministic analyzers. No custom
disease models, no downloaded weights, no training data. Adding one
requires dataset provenance, validation plan, model card, and risk
analysis first. TFLite/NNAPI/GPU notes are future-only documentation.

## Vision Lab

Adaptive staircases (acuity, contrast), leveled color plates, catch-trial
peripheral with reaction times, sequential central grids, guided cover,
intros/restarts/structured results/test index, real text-scale check,
conditions recorded per row. No prescriptions, no game feel.

## Medical capabilities

70-entry `detection_catalog.json` (face 10, eye 8, pupil 5, surface 9,
vision 9, retina 8, skin 6, genetic 12, endocrine 3) with separated
implementation/evidence/validation/clinical/risk statuses; validation
NOT IMPLEMENTED everywhere; clinical status research-only everywhere;
CURRENT entries all carry real references. Explorer UI with filters +
detail pages + live evidence. Research tracks (13) separate from the
validated registry (19 pinned). No classifiers beyond the 12
deterministic analyzers.

## Retinal

Sources refuse non-retinal input by design; `RetinalQualityGate`
(focus/illumination/field/artifacts/motion/contrast/visibility →
gradable/ungradable, tested); 8 FUTURE tracks; attachment profile
documented as future. No retinal analysis runs on selfies.

## Privacy

Local-first; raw deletion by default; opt-in captures; row-only
exports; no network clients; no prints/logs of imagery; temp stills
deleted; diagnostic files explicit. Grep audits clean.

## Security

Permissions: CAMERA needed; RECORD_AUDIO/storage/INTERNET are plugin
manifest merges never requested at runtime. DB local; exports via
system share; no deep links; /dev gated by research mode; diagnosis
strings banned by test.

## Arabic

~200 AppStrings + DevStrings; full consumer + research + dev chrome;
canonical codes for filters; records stay canonical English by design;
Tajawal bundled (OFL, credited); RTL chevrons/arrows; physical L/R
never swapped (tested). 19-route walkthrough incl. new screens.

## Accessibility

Text scaling respected (+ real scaling warning in acuity); high
contrast; 48px+ targets; icon+text statuses; reduced-motion lock ring;
focus default. Screen reader: BLOCKED (no device).

## UI

Clinical-technology direction kept: OCUSCAN command center, 5-stage
screening, status pills, lock countdown, observation-first results,
vision previews + index, capability explorer, labeled loaders, empty
states, help, Learn-why links. No gradients/neon/gamification.

## UX

Onboarding → guided screening → staged eye positioning → specific
guidance → lock → measurements → structured summary → history/trends/
report → retest. Recovery bounded everywhere; snapshot escape
explicit; emergency path camera-independent.

## Performance

Live FPS/latency/drop/age metrics; latest-frame sampling; single
concat buffer; dev-only ML preview; stills on demand. No profiling
numbers invented — budgets TBD on hardware.

## Evidence

27 entries / 40 refs, tiers, audit page (+ catalog-orphan section),
references library with filters/search/DOI/PMID/used-for/evidence-type.
Published numbers never presented as OcuScan performance. Every
registry key mapped (tested); every CURRENT catalog entry referenced
(tested); reference IDs validated (tested).

## Validation

Engineering verification (tests) only. Repeatability/device/reference
infrastructure exists in research mode; no clinical validation started
or claimed. See VALIDATION_PLAN.md.

## Risk

17-row register (tested schema) + /dev Risk tab. Critical hazards
(emergency misuse, light stimulation, retinal misrouting) carry
high-safety mitigations with negligible/low residual.

## Physical-device testing

BLOCKED (no device attached; emulator offline). Creator protocol:
TEST 1–8 + condition matrix + per-test vision runs + capabilities/
trends/report walkthrough. Diagnostic export carries hit rates,
versions, stages, and errors for remote triage.

## Remaining limitations

- Face/eye/lock unproven on hardware (the one load-bearing unknown).
- FPS cost of accurate mode, thresholds, shaping, reader, profiling:
  need hardware.
- Snapshot mode cannot do temporal measurements by construction.
- Stereopsis, voice, gait, hand, retinal models: future only.
- `RECORD_AUDIO` manifest hardening deferred to an on-device pass.
