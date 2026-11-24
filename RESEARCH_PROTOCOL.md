# OcuScan Research Protocol (v0.2)

Recommended procedure for collecting repeatability data. Follow it exactly
so experiments stay comparable. This protocol measures **instruments**, not
people: recruit stable, cooperative adult test sessions, use anonymous IDs,
and stop on any discomfort or symptom.

## 0. Prerequisites

- A real Android device with camera (camera trials cannot run on emulators
  or desktop builds).
- Research mode enabled in Settings (explicit acknowledgment).
- "Save research capture" left OFF unless the session plan requires images
  (requires a second explicit acknowledgment; local-only; deletable).
- A tape measure / ruler, and a light meter app or handheld meter if lux
  will be recorded (lux is optional; lighting level labels are still required).

## 1. Register the instrument (`/dev` → Devices)

1. Enter an anonymous label (`Device A`, `Device B`, …).
2. Record camera (`front`/`rear`) and resolution.
3. Tap "Record instrument profile" — manufacturer, model, OS, and runtime
   are captured automatically; missing fields stay empty, never guessed.

## 2. Create the experiment (`/dev` → Experiments → New)

1. Name: `<measurement> <condition> S<session>` (e.g. `Pupil repeatability S1`).
2. Measurement: one registry key (e.g. `pupil`); version fills automatically.
3. Device label must match the registered instrument.
4. Configured distance: 20/30/40/50/60 cm measured with the ruler. Note that
   this is a **configured test distance**, not a clinical standard.
5. Lighting: one of very low / low / moderate / bright / very bright /
   controlled; enter meter lux when available.
6. Head angle: 0° for repeatability baselines; 5/10/15/20° only for
   angle-robustness experiments.
7. Subject: anonymous ID (`R001`, `R002`, …). Never names.

## 3. Repeatability session (minimum n = 10 trials)

1. Fix the setup; do not move the phone, lamp, or chair mid-session.
2. Open the experiment → Record trial → Guided camera trial.
3. Check **Show Tracking**: face found, yaw ≈ 0°, centered, both eyes open.
   If tracking is wrong, fix the setup — do not record anyway.
4. Capture. Read the quality verdict (luminance, sharpness, failure codes).
5. Attach the observed numeric value when the protocol defines one
   (e.g. asymmetry index read from the tracker/analyzer readout); otherwise
   leave the value empty and record quality + status.
6. Save: `accepted` (measurement produced), `rejected` (LOW quality), or
   `unable` (analyzer unable). **Record failures; never recapture-until-pass.**
7. Repeat to n ≥ 10 under identical conditions.

## 4. Condition sweeps (one variable at a time)

- **Lighting**: clone the experiment per level (very low → very bright),
  10 trials each, same device/distance/angle/subject.
- **Distance**: one experiment per distance (20–60 cm), 10 trials each.
- **Head angle**: one experiment per step (0/5/10/15/20°), verifying with
  the tracker's yaw readout.
- **Device**: same protocol on Device A, B, C…; compare within one analyzer
  version only.

## 5. Test–retest (Repeat Screening)

Run the identical protocol as Session 1 and Session 2 (same test key,
version, device, conditions). In `/dev` → Repeatability, select both
sessions: the workspace pairs ordered accepted values by index and reports
mean |difference|, bias, SD of differences, and mean relative difference.
n < 3 raises the insufficient-data banner.

## 6. Reference comparison (optional, honest)

Only when a real reference procedure is available (e.g. clinic chart,
standardized plate set): use the Reference tab, enter the reference value
plus the exact method. The workspace reports plain differences — never
sensitivity/specificity, never "gold standard" unless the method qualifies.
Never fabricate reference data.

## 7. Failure accounting

Every rejected capture keeps its failure codes
(`LOW_ILLUMINATION`, `OVEREXPOSURE`, `BLUR`, `LOW_RESOLUTION`,
`BAD_FACE_GEOMETRY`, `EYE_NOT_VISIBLE`, `OTHER`). Review
`/dev` → Failure Analysis for attempted/accepted/rejected splits and
unable-to-assess rates per test, device, and lighting.

## 8. Export and reporting

- Per-experiment Report screen: counts, mean/SD, unable rate, conditions,
  notes → Export CSV / JSON (measurement rows only; captures never export).
- File quote: "measurement evaluation — not clinical validation."
- Deleting an experiment deletes its trials and local captures. Settings →
  Delete all data removes everything, including research tables.

## 9. Stop rules

Stop the session on eye discomfort, headache, dizziness, or any symptom —
and use the app's emergency pathway (never the camera) for urgent symptoms.
