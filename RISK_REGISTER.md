# OcuScan Risk Register (v0.3)

Severity: H high / M medium / L low. Probability: H/M/L. All mitigations
are implemented unless marked otherwise; residual risk remains because
screening can always be misread.

| Risk | Cause | Sev | Prob | Mitigation | Residual |
|---|---|---|---|---|---|
| False reassurance | Normal result read as “healthy” | H | M | Three fixed result states; code-enforced does-not-rule-out notice on every normal result; disclaimer on every screen | M — users may still skim |
| False positive alarm | Weak evidence turned into disease label | H | M | Conservative thresholds; low confidence → unable-to-assess; findings never name diseases | M |
| Poor image quality accepted | Pressure to produce a result | H | L | QualityGate LOW veto short-circuits all analyzers; failure codes recorded | L |
| Lighting variation | Pupil/color sensitivity to light | M | H | Stable-light requirements; calibration checklist; unable on failure; lighting sweeps in research | M |
| Device variability | Sensors, optics, auto-processing differ | M | H | Per-device profiles and comparison; no cross-device equivalence assumed; version-pinned analysis | M |
| Skin-tone bias | RGB pipelines, training-data skew | H | M | Fairness dimensions recorded; “Not evaluated” default; far-red/published bias evidence linked; no equality claims | M |
| Eye-color bias | Dark irides defeat RGB pupil detection | M | M | Frame-validity gating; published detection-failure rates linked; unable-to-assess path | M |
| Glasses/reflections | Occlusion and glare | M | M | Obstruction detection; glare listed as failure condition; repeat guidance | L |
| Movement | Head/eye motion during capture | M | M | Multi-frame consistency checks; stability requirements; motion discard reasons | L |
| Model drift | Analyzer changes invalidate old data | M | L | Version on every result, experiment, and export; mismatch warnings | L |
| Bad calibration | Color/distance assumptions wrong | M | M | Calibration checklists and gates; failed calibration → unable | L |
| Inappropriate user interpretation | Skipping limitations | H | M | §57 result structure; Evidence buttons; Learn; Methodology; no health scores | M |
| Privacy breach | Images leaving the device | H | L | On-device processing; default deletion; local-only research captures; audited delete-all | L |
| Unsafe emergency reliance | Using the app instead of urgent care | H | L | Standalone emergency pathway; sudden-symptom wording; no emergency diagnosis | L |
| Unsupported disease extrapolation | Appearance → disease leaps | H | M | cannot_conclude lists; banned-phrase tests; evidence tiers; audit page | M |
