# OcuScan Algorithm Cards (v0.5)

Generated from `AnalyzerRegistry` (19 pinned entries). Each card:
input → features → output → quality requirements → failure conditions →
limitations → version → threshold basis. In-app equivalent: Methodology
cards + /dev Analyzer cards + `analyzer_info_screen.dart`.

| Key | Title | Version | Output | Experimental |
|---|---|---|---|---|
| facial_asymmetry | Facial movement symmetry | v1 | Relative movement asymmetry per region (no diagnosis) | no |
| eyelid | Eyelid position | v2 | Relative eyelid-openness-probability asymmetry (not a ptosis diagnosis) | no |
| eye_alignment | Eye alignment | v1 | (not measured in this build → unable) | no |
| pupil | Pupil symmetry | v1 | (no segmentation in this build → unable) | no |
| pupil_response | Pupil light response | v1 | Disabled safely → unable | no |
| surface_growth | Ocular surface | v1 | (no segmentation → unable) | no |
| redness | Eye redness | v2 | Eye-region ROI redness proxy + distribution (not segmented sclera) | no |
| scleral | Scleral color | v1 | Calibrated yellowness (valid calibration only) | no |
| corneal | Corneal clarity | v1 | (no segmentation → unable) | no |
| lens | Lens clarity | v1 | (no method → unable) | YES |
| blink | Blink pattern | v1 | Rate from ≥30 tracked samples, else unable | no |
| nystagmus | Eye movement stability | v1 | (no gaze tracking → unable) | no |
| (+7 vision-test procedures: staircase acuity, leveled color, adaptive contrast, grid central, catch-trial peripheral, guided cover, experimental refractive) |

Threshold basis: prototype engineering thresholds unless a literature
citation states otherwise (cited on the card). No clinical diagnostic
thresholds are claimed anywhere.
