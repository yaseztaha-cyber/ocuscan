# OcuScan Intended Use (v0.3)

## Intended purpose

Research and screening support: guided smartphone measurement of observable
ocular, facial, and visual-function characteristics, with uncertainty,
evidence links, and structured research data collection for measurement
validation. Not diagnosis.

## Intended users

- General users performing non-diagnostic self-screening and learning.
- Researchers collecting measurement-validation data (repeatability,
  robustness, failure analysis) with the guarded `/dev` workspace.

## Intended environment

Smartphones with a working camera, used under the supported conditions
stated per test: adequate lighting, stated distance, stable head position,
full screen brightness, night mode and color filters off for color tests.
Core screening works offline.

## Limitations (summary; full list in-app and in SAFETY.md)

- Front camera cannot examine the retina, measure millimeters without
  calibration, assess nerve function, or determine causes.
- Many conditions are invisible from outside; normal screens never mean
  healthy and flags never name diseases.
- Color, pupil, and landmark measurements vary across devices, lighting,
  skin tones, eye colors, ages, glasses, and head angles; unevaluated
  groups are labeled “Not evaluated”.
- Experimental modules are not clinically validated; future catalog items
  are not implemented; retinal analysis needs hardware that does not exist
  in this build.

## Non-intended uses

Diagnosis or exclusion of disease; emergency triage; glasses prescriptions
or prescription changes; autonomous treatment decisions; inferring
laboratory values (blood, hormones, liver function) from faces; retinal
disease analysis on selfie images; any use of aggregate health scores or
disease-risk percentages.

## Verification ≠ validation ≠ clearance

Software verification (the app runs as specified) is not measurement
validation (the numbers are stable and robust), which is not clinical
validation (screening performance against clinical outcomes), which is not
regulatory clearance. OcuScan provides research infrastructure for the
first two and claims neither of the last two. Intended-use language is kept
conservative and explicit, consistent with FDA clinical-decision-support
guidance that functionality and intended use drive regulatory treatment.
