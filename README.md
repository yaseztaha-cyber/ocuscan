# OcuScan — Safety-First Smartphone Eye & Vision Screening (Prototype)

**OcuScan turns an ordinary smartphone into a guided, measurable screening
instrument for observable ocular/facial signs and basic visual function,
while explicitly communicating uncertainty and limitations.**

> Educational/research screening prototype — **not a diagnostic medical
> device**. No diagnoses. No regulatory approvals claimed. No accuracy
> statistics claimed.

## Safety principles (non-negotiable)

- Every result is one of: **No obvious abnormality observed in this
  screening** · **Possible finding detected** · **Unable to assess reliably**.
- The app never says "you have X", never gives a glasses prescription, and
  never shows a health score or disease probability.
- `LOW` image quality never produces a confident result.
- Unvalidated/experimental modules report `unable-to-assess` instead of
  guessing (pupil light-response, lens opacity).
- Emergency symptoms route to **"Do not rely on OcuScan — seek emergency
  care"**, never to a camera result.
- All medical wording is guarded by `SafetyLanguage` + automated tests that
  scan the evidence DB and UI strings for banned diagnostic/regulatory
  phrases.

## Run

```powershell
flutter pub get
flutter analyze
flutter test
flutter run            # Android device / emulator (camera required for live flow)
flutter build apk --release
```

iOS architecture is kept possible (standard `ios/` runner, no
Android-only APIs in Dart code); camera/ML Kit plugins used here both ship
iOS implementations.

## Architecture

```text
Camera (camera plugin)
  ↓ on-device face detection (google_mlkit_face_detection)
CameraService (live preview + FaceFrame stream, graceful fallback)
  ↓ still capture → package:image decode → ImageUtils.computeStats
QualityGate (lighting/exposure/blur/geometry/color-light vetoes → HIGH/MEDIUM/LOW)
  ↓ LOW short-circuits to Unable-to-assess
12 modular analyzers (lib/features/analyzers/*.dart)
  each: INPUT → QUALITY → MEASUREMENT → RULE LAYER → UNCERTAINTY
        → FINDING → LIMITATIONS → ACTION  (ScreeningResult)
  ↓ measurements only persisted (sqflite); raw image deleted by default
History / Learn (curated assets/medical_evidence.json) / Settings / Emergency
```

Rule layers are deterministic and unit-tested (`test/analyzers_test.dart`).
Pixel/color math is pure Dart and tested without a camera
(`test/quality_gate_test.dart`). Safety phrasing and the evidence DB are
scanned for banned language (`test/safety_vision_test.dart`).

## Measurement pipeline per feature

| Module | Real input | Conservative behavior |
|---|---|---|
| Quality gate | luminance, exposure fractions, Laplacian sharpness, resolution, face geometry | LOW vetoes all downstream results |
| Facial asymmetry | per-expression landmark amplitudes, head yaw | needs ≥2 regions ≥30% + frontal head |
| Eyelid | left/right opening, gaze pitch | 20% threshold, rejects off-axis gaze |
| Eye alignment | gaze deltas + cover/uncover shift ÷ IPD | low confidence cap, never "strabismus" |
| Pupil symmetry | ≥3 valid frames, relative index `|l−r|/avg` | never mm; rejects unstable light |
| Pupil response | hardware safety gate | **disabled** in this build → unable-to-assess |
| Surface growth | vascular/shape/encroachment cues + seg. confidence | no severity grades |
| Redness | scleral `r/(r+g+b)` + spread + white-balance gate | never names a cause |
| Scleral color | lighting-calibration gate first | unable-to-assess unless neutral light |
| Corneal / lens | opacity cue + confidence / close-up protocol gate | conservative; lens = experimental |
| Blink | 10 s openness series → rate + incomplete fraction | never diagnoses dry eye |
| Nystagmus | zero-crossing freq + sustained-window check | indeterminate → unable-to-assess |
| Vision Lab | randomized optotypes, generated color triplets, contrast ladder, Amsler-style grid, peripheral trials, cover steps | per-eye, distance/brightness recorded, no zoom |

## Privacy

`Camera → on-device processing → measurements → result → raw image deleted.`
Defaults: raw-image storage **OFF**, cloud upload **OFF**, history **ON**
(local measurements only). Settings offers **Delete all data** and export.
No advertising, face recognition, identity profiles, or biometric sale.

## Project map

- `lib/core/models/screening_result.dart` — result schema
- `lib/core/pipeline/{quality_gate,analyzer}.dart` — gates + contracts
- `lib/core/safety/safety_language.dart` — banned-phrase guard
- `lib/core/evidence/` + `assets/medical_evidence.json` — curated education
- `lib/features/analyzers/` — 12 screening modules
- `lib/features/vision_lab/vision_logic.dart` — test logic
- `lib/features/camera/camera_service.dart` — camera + ML Kit
- `lib/ui/screens/` — Splash → Welcome → Consent → Home → Screening /
  Vision Lab / History / Learn / Settings / About / Emergency (+ hidden `/dev`)
- `lib/core/localization/app_strings.dart` — English + Arabic (MSA,
  Egyptian-friendly health wording; English terms kept in Learn details)
- `test/` — 495 tests, all passing; `flutter analyze` clean

## Definition of done (status)

- [x] Camera pipeline with permission + failure handling (no crashes)
- [x] Quality evaluated before every screening; LOW blocks results
- [x] Real measurements (pixel stats, multi-frame indices, interactive tests)
- [x] "Unable to assess" is first-class everywhere
- [x] No disease claims anywhere (tested); limitations + evidence attached
- [x] Offline core; no image upload by default; delete supported
- [x] "Why was this flagged?" on every result
- [x] No fake accuracy/doctors/certifications/partnerships
- [x] Modular architecture ready for clinical validation + future optical
      attachment work (front camera is never presented as a retinal camera)
