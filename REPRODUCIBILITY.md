# OcuScan Reproducibility Guide (v0.3)

Every number in the `/dev` workspace must be reproducible from the steps
below plus an exported CSV/JSON file. No step requires a server, an
account, or uploaded images.

## 0. Versions to record

OcuScan app version, per-module analyzer version (shown on every result and
experiment), evidence DB version (`References` page header), device label
and profile, camera, and conditions. Exports carry app + evidence versions
in the JSON envelope and per-trial analyzer versions in both formats.

## 1. Camera experiments

1. Settings → enable research mode (read the consent text).
2. `/dev` → Devices → register the instrument (anonymous label).
3. `/dev` → Experiments → New: one measurement key, fixed device, camera,
   configured distance (ruler), lighting level (+ meter lux when available),
   head-angle step, anonymous subject ID, fairness labels when agreed.
4. Record trial → Guided camera trial → verify Show Tracking → Capture →
   save as accepted / rejected / unable. Record failures; never
   recapture-until-pass. Minimum n = 10 per condition.

## 2. Lighting sweeps

Clone the experiment per level (very low → very bright), 10 trials each,
same device, distance, angle, subject. Compare per-test unable-rates and
measurement spread in `/dev` → Lighting.

## 3. Distance sweeps

One experiment per configured distance (20/30/40/50/60 cm, ruler-measured),
10 trials each. Distances are experiment settings, not clinical standards.

## 4. Facial-expression tests

Standardized protocol: neutral hold, brow raise, eyes closed, smile, cheek
puff — camera level, face centered, similar distance, controlled lighting,
~3 s per expression. Sample each expression in the screening flow; compare
left/right amplitudes across sessions in Repeatability.

## 5. Pupil repeatability

Stable even lighting, both pupils visible, head still. Guided trials record
the relative asymmetry index over ≥3 valid frames with discard reasons
(blur, reflection, occlusion, motion). Repeat to n ≥ 10; read mean/SD/CV
and the distribution in the experiment view.

## 6. Vision tests

Each Vision Lab test states distance, screen, lighting, eye, and
calibration status — reproduce those exact conditions, test each eye
separately, and repeat. Reference comparison: enter an independently
measured reference with its exact method (never called a gold standard
unless it qualifies); the workspace reports plain differences only.

## 7. Device comparisons

Repeat the identical protocol (same test key, analyzer version, conditions)
on each instrument. Compare within one analyzer version only; version
mismatches raise explicit warnings.
