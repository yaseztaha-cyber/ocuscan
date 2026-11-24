# OcuScan Risk Management (v0.5)

ISO 14971-**style** structured thinking. **Not an ISO certification
claim.** Machine-readable register: `assets/risk_management.json`
(schema-tested). Each entry: feature, hazard, cause, possible harm,
severity (negligible/minor/serious/critical), probability
(rare/occasional/frequent), risk level, mitigation, residual risk,
verification method, safety relevance.

## Top risks and mitigations

| Hazard | Mitigation | Residual |
|---|---|---|
| False reassurance from normal screen | Conservative wording; code-enforced does-not-rule-out notice; disclaimers everywhere | low-medium |
| Emergency misuse (screening instead of urgent care) | Independent symptom-based emergency path; emergency banners; explicit do-not-rely wording | low-medium |
| Wrong measurement from bad image | Observed-layout ML input; computed rotation; QualityGate veto; unable instead of guessing | low-medium |
| Neurological self-diagnosis from research wording | Catalog-only tracks; pattern-outside-distribution wording; never-diagnose statements; badges | low-medium |
| Privacy breach (images/uploads) | Local-first; deletion by default; opt-in captures; row-only exports; no network clients | low |
| Unsafe light stimulation | Pupil-response module hard-disabled without controlled safe stimulus; no flash ever | negligible |
| Retinal misrouting (selfie as fundus) | `RetinalCameraSource.require` throws for non-retinal sources by design | negligible |

## Process rules

- New analyzers require the §96 safety gate (rationale, modality,
  evidence, provenance, risk analysis, failure conditions, uncertainty,
  reference labels, validation plan, safe wording) or stay FUTURE.
- Residual risk is re-reviewed when: algorithm version changes, new
  hardware support lands, or a device-specific failure is reported.
- `/dev` Risk tab renders the register for researcher review.
