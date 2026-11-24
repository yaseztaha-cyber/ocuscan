# OcuScan v0.3.2 — UI / Camera / Arabic Audit

Creator: **Yassen Taha Hussainy Elnasher**, **G11 — STEM Gharbiya**.
Date (UTC): 2026-09-26. Verdicts: `PASS` / `FAIL` (→fixed) / `BLOCKED` / `EXPERIMENTAL`.

## 1. UI problems found

| Observed | Root cause | Affected |
|---|---|---|
| Generic Material look: every screen ListView + Card + SectionTitle | No design-token depth; one Card/SectionTitle primitive reused everywhere | All consumer screens |
| Home was a flat button stack; research status buried | No editorial hierarchy | `home_screen.dart` |
| Screening was 8 undifferentiated steps; eye step showed a static guide box unrelated to the actual face, with generic ADJUST/HIDDEN chips | No tracker geometry exposed; single-frame gating; hardcoded guide | `screening_flow.dart` |
| Results were generic cards | ResultCard showed badge + lines with no observation-first structure | `common.dart` ResultCard |
| Vision Lab tabs were text-only | No visual test identity | `vision_lab_screen.dart` |
| Bare spinners on Learn/References/History | No context-aware loading states | 3 screens |
| Forward chevrons hardcoded right-pointing | RTL mirroring unaudited | settings/learn/dev tiles |
| Pipeline diagram arrows hardcoded forward | Same | `about_screen.dart` |

## 2. Arabic problems found

| Observed | Root cause | Affected |
|---|---|---|
| Switching language changed almost nothing on device | ~95% of user-facing strings hardcoded English; `AppStrings` covered ~25 keys | All screens |
| No consistent Arabic typography | No bundled font; system fallback varies by device | Whole app |
| Material widgets (dialogs/pickers) stayed LTR (prior audit fixed supportedLocales; verified still correct) | `MaterialApp` config | `app.dart` (kept) |
| Reference filter broke under Arabic | `_visible()` matched display labels to codes | `references_screen.dart` |
| Month headers, tier labels, calibration labels, vision instructions, settings rows, dev chrome all English-only | Same hardcoded-string root cause | Listed screens |

Locale state verified intentional: language persisted in SharedPreferences (`language` key), restored into `AppState` at launch, `MaterialApp.locale` explicit (never overridden by system locale). Round-trip covered by `localization_test.dart`.

Deliberate non-translations (documented): persisted measurement records (test names, finding labels, limitations) stay canonical English so history rows are locale-independent; module registry engineering specs stay English; still-image analyzer inputs unchanged. Finding/evidence names show Arabic term + English medical term from the evidence DB (`nameAr`), descriptions stay canonical English to preserve exact scientific meaning.

## 3. Eye detection root cause

Observed on device: face found → app cannot determine eyes → repeated "adjust".

| # | Root cause | Evidence |
|---|---|---|
| R1 | ML Kit fed **hardcoded `rotation0deg`** while the portrait front camera needs **270°** (`camera_service.dart:146` pre-fix). Detector saw sideways frames: bounding boxes roughly appear, landmarks/contours/eye-open classification degrade → `bothEyesOpen` flaky, face fraction/centering computed in the wrong frame | Code trace; matches symptom exactly (face yes, eyes no) |
| R2 | `FaceDetectorMode.fast` — worse landmarks than `accurate` | API behavior |
| R3 | `FaceFrame` exposed **no geometry** (no box, no eye points) → static 190×250 guide unrelated to the face; guidance could not be directional; analyzer-specific gating/crops impossible | Code trace |
| R4 | Single-frame gating (`faceFound`, `verdict != null`) with generic messages; no stability window; thresholds (±12% center, 0.4 openness) applied in the wrong frame | Code trace |
| R5 | No mirror/rotation-aware overlay mapping existed at all | Code trace |

NOT the cause: model capacity (ML Kit is sufficient once fed correctly-oriented frames), resolution (medium stream + full-res stills retained), timing (`_busy` serialization retained).

## 4. Fixes implemented

**Eye pipeline (no new model, no faked detection):**
- Computed ML Kit rotation from sensor orientation + device orientation (standard compensation formula; front-portrait → 270°), logged per frame in /dev.
- Detector switched to `accurate` mode (landmarks + contours + classification + tracking kept).
- `EyeGeometry` per frame (normalized raw-space box, L/R eye landmarks, yaw/roll, openness, tracking id, contour count) + cheap Y-plane luminance/blur sampling.
- `EyeTracker`: 12 diagnostic states (first-failure-wins), EMA smoothing, 5-frame loss budget with explicit stale marking, 5-frame stability window → lock, per-analyzer `meetsNeed` gates (pupil/blink need lock; facial asymmetry needs positioned face only).
- 5-stage screening (Position / Eyes / Movement / Measurements / Summary); Eyes stage is face→position→eyes→stabilize→ready with specific actionable guidance (EN+AR), live overlay (face box, L/R eye dots + regions, lock pulse), stage strip, stabilizing progress, status chips; Continue gated on real lock (camera-less runtime still reports unable-to-assess).
- Facial-movement analysis additionally requires a real eye lock (`meetsNeed`); all other unmeasured modules unchanged (unable with reasons).
- Research-only `/eye-debug` (from /dev Overview): live preview + overlay, 6-stage frame pipeline readout (raw → quality → box → landmarks → crops → analyzer input), live thresholds, still inspector (`analyzeStill` in still space, file deleted on exit), 40-frame ring log with rotation/sensor/mirror/box/eyes/luminance/blur.
- Coordinate-transform unit tests (rotation formula all orientations, mirrored/non-mirrored portrait/landscape mapping, cover-fit, region clamping, Y-plane sampling, full state machine incl. loss budget and needs).

**Arabic:** `AppStrings` expanded from ~25 to ~200 keys covering every consumer screen; `DevStrings` extended for research chrome; reference filter re-keyed to canonical codes; months/tiers/calibration/vision/settings/dev all localized; Tajawal Regular/Medium/Bold bundled (OFL, credited in About) and wired as app font; `NavChevron` direction-aware tiles; pipeline arrows mirror in RTL; camera overlay keeps physical L/R labels (never swapped); Arabic walkthrough test visits 14 routes asserting zero errors + RTL.

**UI:** design tokens (`OcuSpace`, `OcuRadii`, status tints, TabBar/NavigationBar/SnackBar theming); editorial Home (kicker, CTA, latest screening, Vision Lab, how-it-works, research status); distinctive result layout (status rail, OBSERVATION-first, quality/confidence chips); per-test visual previews in Vision Lab; labeled loading states; empty states everywhere; lock pulse + stage animations tied to real tracker state (no fake progress).

**Incidental robustness fix:** `CameraService.dispose` no longer lets ML Kit `close()` fail teardown (guarded async close).

## 5. Runtime verification

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` full suite | **151/151 PASS** (111 baseline + 31 eye-tracking + 8 localization + 1 walkthrough net of journey growth) |
| Widget journeys (7 incl. new AR walkthrough) | PASS |
| Physical-device install/test | **BLOCKED** — no device attached to this environment (`adb devices` empty). NOT claimed. |
| Real-device test script (§50–51) | Provided below for the creator |

### Device test script for the creator
1. Install the v0.3.2 APK (version 0.3.2+2 installs over 0.1.0+1).
2. English: onboarding → screening → Eyes stage: verify the overlay box tracks the face, eye dots sit on the eyes, guidance names the real problem (try: too far, too close, dark, tilted, one eye covered), lock achieved in normal indoor light → complete flow → result.
3. `/dev` → Eye Tracking Debug: confirm rotation reads 270, sensor 270, mirror true (front portrait); frame log plausible; capture still & inspect shows still-space overlay.
4. Arabic: Settings → العربية → repeat screening; verify RTL, Arabic guidance, Tajawal shaping; restart app → Arabic persists.
5. Report back: lock success/failure per condition (distance/lighting/angle/glasses) with the exact guidance text shown.

## 6. Remaining limitations

- On-device verification of the rotation fix, lock reliability, FPS impact of `accurate` mode, and Arabic shaping quality is BLOCKED here — creator run required (§5 script).
- Blur threshold (8.0) and luminance bounds are conservative defaults; tune from /dev live readouts on the target phone.
- Vision measurement sentences and registry engineering specs remain English by design (record stability).
- Screen-reader pass, runtime profiling, and `RECORD_AUDIO` manifest hardening still need hardware.
- No new medical analyzers added per §55; pupil/alignment/surface/corneal/lens/nystagmus still report unable-to-assess with reasons.

## 7. Tests

- `test/eye_tracking_test.dart` (31): rotation formula, portrait/landscape/mirrored mapping, region clamping, Y-plane sampling, tracker gates/stability/loss/needs.
- `test/localization_test.dart` (8): EN≠AR coverage per screen area, all 12 guidance states, taxonomy/month/tier mappings, research chrome, language persistence round-trip.
- `test/audit_journey_test.dart` (7 incl. new `arabic walkthrough renders all major screens` over 14 routes).
- Full suite: 151/151, 0 regressions.

## 8. APK details

- Path: `D:\YASEZ_HOME\projects\medical eye app\build\app\outputs\flutter-apk\app-release.apk`
- Size: 85.2 MB, built 2026-09-26 (clean → pub → analyze 0 → test 151/151 → build EXIT 0).
- `aapt dump badging`: `com.ocuscan.ocuscan` versionName `0.3.2` versionCode `2`, minSdk 24 / targetSdk 36.
- Physical-device install/test: BLOCKED in this environment (no device attached) — NOT claimed.
