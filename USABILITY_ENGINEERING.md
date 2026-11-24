# OcuScan Usability Engineering (v0.5)

IEC 62366-1-**style** usability-risk thinking. **Not a certification
claim.** For each critical task: expected behavior, possible use error,
severity, prevention, recovery, verification.

## Critical tasks

### Eye positioning
- Expected: follow staged guidance (face → position → eyes → hold still).
- Use error: user cannot understand where to move.
- Severity: medium (abandoned screening).
- Prevention/mitigation: specific directional instruction per tracker
  state (never generic "adjust"); live overlay; stage strip; lock
  countdown of real frames.
- Recovery: bounded ladder (auto-reset → help → restart → snapshot →
  continue-unable); camera help screen.
- Verification: journey tests; Arabic walkthrough; (device: creator
  protocol).

### Visual acuity
- Expected: hold calibrated distance, answer optotypes.
- Use error: user changes distance; system scaling active; night mode on.
- Severity: medium (wrong numbers presented as precise).
- Prevention: pre-test instruction + calibration checklist; REAL
  system-text-scale detection with warning; uncalibrated results marked
  unable/unreliable; conditions recorded with every result.
- Recovery: restart; repeat guidance.
- Verification: calibration-gate tests; staircase unit tests.

### Emergency screen
- Expected: urgent symptoms → seek care, never screen.
- Use error: user interprets screening as emergency clearance.
- Severity: high.
- Prevention: independent symptom path (no camera dependency); explicit
  do-not-rely wording; emergency banners in consent/movement flows.
- Verification: wording review; journey coverage.

### Research data entry
- Expected: correct experiment/trial metadata.
- Use error: mislabeled conditions invalidate comparisons.
- Severity: low-medium.
- Prevention: structured forms; canonical codes; seeded orders recorded.
- Verification: model round-trip tests.

### Language switching
- Expected: full UI follows language immediately and persists.
- Use error: mixed-language screen confuses safety instruction.
- Severity: medium.
- Prevention: ~200-key coverage + coverage tests; canonical codes for
  filters; records stay canonical English.
- Verification: localization tests; 17-route Arabic walkthrough.
