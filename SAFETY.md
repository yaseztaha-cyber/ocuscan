# OcuScan Safety Documentation (v0.2)

OcuScan is an **educational/research screening prototype**. Nothing in this
file, the app, or the research workspace changes that. Safety outranks
measurement quality, which outranks visual polish and feature count.

## 1. Intended use

- Guided, measurable screening observations of visible eye/facial signs and
  basic visual function on a smartphone.
- Tracking those measurements over time.
- Engineering research into measurement validity, repeatability, robustness,
  and failure detection (`/dev` workspace, `VALIDATION.md`).

## 2. Non-intended use (never)

- Diagnosis of any disease or condition.
- Ruling conditions out ("no disease", "healthy").
- Glasses prescriptions or prescription changes.
- Retinal examination with the normal front camera.
- Determining the cause of any finding.
- Emergency triage — see §5.
- Any use of a global "eye health score", "disease risk" percentage, or
  similar aggregate: these are prohibited and scanned for by automated tests.

## 3. Diagnostic limitations

- Every result is one of three states: **No obvious abnormality observed**,
  **Possible finding detected**, **Unable to assess reliably**.
- The vocabulary of the app never includes "you have X", probabilities of
  disease, or statements of health. `SafetyLanguage` centralizes banned
  phrases; tests fail the build if they appear in UI strings or the evidence
  database.
- Educational text comes from the curated local `medical_evidence.json`
  (authoritative overviews, never invented references). No generative model
  writes or overrides medical content.
- Experimental modules (lens, corneal, surface-growth, pupil-response) are
  badged as such and must never appear more reliable than other components.
- No accuracy, sensitivity, specificity, or approval claims exist anywhere:
  no "medical-grade", "doctor-approved", "clinically certified", or
  regulatory-approval language, and no invented percentages.

## 4. Uncertainty handling

- `QualityGate` LOW verdicts short-circuit every analyzer to
  unable-to-assess (`lowQualityShortCircuit`); poor input never becomes a
  confident result.
- Every analyzer returns confidence + limitations + "why flagged" text.
- Statistics show `n` always; n < 3 raises an insufficient-data banner.
- Unable-to-assess is a first-class metric (rate per test/device/lighting/
  distance/angle), reported as a performance characteristic — a lower rate
  is not automatically clinically better.

## 5. Emergency pathway

Camera screening is never the only route to emergency advice. The standalone
safety screen asks about sudden vision loss/change, severe eye pain, sudden
facial weakness, trouble speaking, severe headache, new double vision,
severe injury, and chemical exposure. Any selection shows: **do not rely on
OcuScan — seek emergency care promptly**, without attempting to diagnose the
emergency condition.

## 6. Privacy model

Camera → on-device processing → measurements → result → raw image deleted.
Defaults: raw-image storage OFF, cloud upload OFF, research mode OFF,
research captures OFF. Research captures (when explicitly acknowledged) are
local-only, deletable, and excluded from exports. No advertising, face
recognition, identity profiles, or biometric sale. Delete-all-data removes
consumer results, sessions, experiments, trials, reference labels, and
device profiles. Privacy engineering follows GDPR data-minimization and
erasure principles and the NIST Privacy Framework functions; safety
principles follow WHO guidance on ethics and governance of AI for health
(transparency, accountability, inclusiveness and equity).

## 7. Unsafe scenarios (must remain impossible)

- Silent image upload or external AI diagnosis calls.
- Turning LOW-quality input into confident findings.
- Experimental modules presented as validated.
- Research numbers (repeatability, agreement) presented to normal users or
  framed as clinical validation.
- Retinal disease classification on front-camera images (the retinal source
  refuses non-retinal input by design).
- Synthetic or downloaded images presented as clinical validation data.
