# OcuScan Validation Documentation (v0.2)

OcuScan is an **educational/research screening prototype** — not a diagnostic
medical device. This document describes how to evaluate whether its
smartphone-based **measurements** are accurate, repeatable, and robust. It
does not claim disease detection, clinical validation, regulatory approval,
or certified accuracy. All numbers shown in the `/dev` workspace come from
trials a researcher actually records; empty states stay empty.

Research question:

> When OcuScan produces a measurement, how stable is that measurement, under
> what conditions does it fail, and how do device and environment affect it?

## 1. Measurement definitions

Each `AnalyzerRegistry` entry defines input, features, output, quality
requirements, failure conditions, limitations, and version. Summary:

| Key | Output (screening only) | Version |
|---|---|---|
| `facial_asymmetry` | relative movement asymmetry per expression region | v1 |
| `eyelid` | relative eyelid-openness-probability asymmetry | v2 |
| `eye_alignment` | relative alignment-change estimate | v1 |
| `pupil` | relative pupil-size asymmetry index (never mm) | v1 |
| `pupil_response` | disabled unless stimulus is safe + reproducible | v1 (experimental) |
| `surface_growth` | surface-growth appearance flag, no grade | v1 (experimental) |
| `redness` | eye-region ROI redness proxy + distribution, never a cause | v2 |
| `scleral` | color screening only when calibration valid | v1 |
| `corneal` | conservative flag only | v1 (experimental) |
| `lens` | flag only under supported capture | v1 (experimental) |
| `blink` | rate + completeness description | v1 |
| `nystagmus` | sustained-oscillation flag or unable | v1 |
| `va_distance` / `va_near` | screening acuity level, not a prescription | v1 |
| `color` | generated-plate screening suggestion | v1 |
| `contrast` | threshold under recorded conditions | v1 |
| `amsler` | self-reported distortion map | v1 |
| `peripheral` | per-region detection record | v1 |
| `cover` | observed cover-state movement | v1 |

Pupil asymmetry index: `|L − R| / mean(|L|, |R|)` over ≥3 valid frames.

## 2. Experiment protocols

Create an **Experiment** (`/dev` → Experiments) for one measurement key with
fixed: anonymous device label, camera, configured distance, lighting level
(+ optional meter lux), head-angle step, anonymous subject ID, analyzer
version. Then record repeated **Trials**:

- **Guided camera trial**: live tracking check → capture → real `ImageStats`
  → real `QualityGate` verdict → failure codes. LOW suggests `rejected`.
- **Manual entry**: a value from a documented instrument (e.g. a consumer-app
  screening run); instrument goes in notes.
- **Reference entry**: paired OcuScan value + manually entered reference with
  its exact method. A reference is a comparison point, never an automatic
  gold standard. Never fabricate reference data.

See `RESEARCH_PROTOCOL.md` for the step-by-step repeatability procedure.

## 3. Variables

Recorded per trial: `inputQuality`, `value` + `unit`, `confidence`,
`status` (accepted/rejected/unable), `failureReason`, optional
`referenceValue` + `referenceMethod`, condition snapshot (lighting, lux,
distance, head angle, device, subject, test type), quality snapshot
(luminance, sharpness, exposure), notes, `hasCapture` flag (never a path).

## 4. Data schema

SQLite file `ocuscan.db`, version 2 (same file as consumer history):

- `experiments(id, name, description, testType, deviceLabel, camera,
  targetDistanceCm, distanceNote, lightingLevel, lux, screenBrightness,
  headAngleDeg, subjectId, environmentalNotes, operatorNotes,
  analyzerVersion, createdAt)`
- `trials(id, experimentId, timestamp, inputQuality, value, unit,
  measurementLabel, confidence, status, failureReason, referenceValue,
  referenceMethod, lightingLevel, lux, distanceCm, headAngleDeg,
  deviceLabel, subjectId, testType, notes, hasCapture, luminance,
  sharpness, exposureBadFraction)`
- `reference_labels(...)` — researcher-documented only; no bundled datasets.
- `device_profiles(deviceLabel, manufacturer, model, osVersion,
  runtimeVersion, camera, resolution, orientation, screen sizes)`

## 5. Statistics

Pure-Dart (`statistics.dart`), always with `n`:

- `describe`: n, mean, median, sample SD (n−1; null when n<2), min, max,
  range, CV (null when mean = 0 or n<2).
- `agreement`: paired (OcuScan, reference) mean |diff|, bias (mean diff),
  SD of diff, mean relative diff. Plain differences — not accuracy.
- `histogram`: fixed equal-width bins over observed [min, max].
- `unableRate`: unable / total (null when total = 0).
- **Gate**: n < 3 → "Insufficient data for reliable statistical
  interpretation." Raw values remain visible.
- Sensitivity/specificity are **never** computed: no labelled reference
  outcomes exist in this system.

## 6. Limitations

- Phone optics, auto-exposure, and auto-white-balance vary by device; color
  values are not transferable across phones without testing.
- Front camera cannot examine the retina or replace slit-lamp optics.
- Configured test distances are experiment settings, not clinical standards.
- Paired test–retest comparison matches ordered accepted values and is valid
  only for same-protocol repeats (method stated in UI).
- Small samples are flagged, never hidden.

## 7. Privacy

Research captures: OFF by default, explicit acknowledgment required,
local-only (`research_captures/` under app documents), deletable per
experiment and via delete-all-data, never exported, never uploaded, never
sent to any API. Exports (CSV/JSON) carry measurement rows only. Subject and
device IDs are anonymous labels (`R001…`, `Device A…`).

## 8. Reproducibility

An experiment is reproducible from: test key + analyzer version, device
label + profile, camera, configured distance, lighting level + lux,
head-angle step, subject ID, and the trial table (exportable CSV/JSON with
the schema in §4). Analyzer versions pin the algorithm; version mismatches
raise explicit warnings in comparison views.

## 9. Known weaknesses (v0.2)

- Landmark-dependent modules inherit ML Kit tracker's limits; the tracking
  overlay exists to verify lock before trusting frames.
- Pupil light-response has no safe reproducible phone stimulus and stays
  disabled; corneal/lens/surface-growth models are experimental.
- No normative ranges for uncalibrated displays; contrast/acuity results are
  condition-bound.
- Desktop test builds cannot exercise the camera; camera trials require a
  real device.
