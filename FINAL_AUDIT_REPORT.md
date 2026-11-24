# OcuScan v0.3.1 — Final Audit Report

- **Project:** OcuScan — privacy-first smartphone eye and facial screening prototype
- **Creator:** Yassen Taha Hussainy Elnasher, G11 — STEM Gharbiya
- **Date (UTC):** 2026-09-26
- **Toolchain:** Flutter 3.47.5 · Dart 3.13 · BellSoft LibericaJDK-17 · Android SDK 36 (NDK r28c) · minSdk 24 / targetSdk 36
- **Verdict vocabulary:** `PASS` / `FAIL` (→fixed) / `BLOCKED` / `NOT APPLICABLE` / `EXPERIMENTAL`
- **Severity:** P0 crash/data-loss/safety · P1 major broken · P2 important · P3 cosmetic/hardening

Companion document: `AUDIT_MATRIX.md` (per-area rows with locations and verification).

## 1. Static verification (actually executed)

| Check | Result |
|---|---|
| `flutter analyze` | No issues found |
| `flutter test` (full suite) | **111/111 passed**, EXIT_CODE=0 (105 pre-existing + 6 new journey tests, 0 regressions) |
| `TODO`/`FIXME`/placeholder/`mock`/`print` in `lib/` | Zero matches (grep) |
| Camera pipeline sites (`CameraController`/`ImageStream`/`FaceDetector`) | Exactly 1 (`camera_service.dart`) |
| Network/audio runtime use in `lib/` (`http`, `Dio`, `Socket`, `HttpClient`, microphone) | Zero matches |
| Release build `flutter build apk --release` | EXIT_CODE=0, `app-release.apk` 84.1 MB |
| `aapt dump badging` | `com.ocuscan.ocuscan` v0.1.0 (code 1); permissions CAMERA, RECORD_AUDIO, READ/WRITE_EXTERNAL_STORAGE, INTERNET, ACCESS_NETWORK_STATE |

## 2. Fixes applied during this audit

### P0
- **Blink filler produced a false finding.** `_runAllAnalyzers` fed `List.filled(150, 0.9)` into the blink analyzer (≈0 blinks/min → possibleFinding from non-data). Fixed: modules without real input now return `ScreeningResult.unable` via `notMeasured()` (alignment, pupil, surface, corneal, lens, nystagmus, blink<30 samples). Verified by unit tests + flow review.

### P1
- **Camera re-entry leak** (`camera_service.init`): old controller never disposed on route re-entry → duplicate streams/camera lock. Fixed with init guard + dispose-first; screens hold `_camRef` and release on dispose; `release()` no longer notifies listeners during route teardown. Verified by lifecycle re-entry widget test.
- **Capture failure blacks preview** (`captureStill`): stream not restarted if `takePicture` throws. Fixed with finally-restart.
- **Analyzer honesty gaps**: corneal constant `(0.15, 0.6)` → "No opacity" from thin air; pupil/alignment openness-proxies and constant cover deltas → normals from non-measurements. All converted to explicit unable-to-assess with reasons.
- **Evidence Audit tab fragile load** (`dev_analysis_tabs._load`): after loading the repo it performed a second raw `rootBundle` re-read for duplicate-id checking; any bundle failure left the tab on a spinner forever. Fixed by deriving ids from the already-loaded repo (identical data); removed now-unused `dart:convert` / `services` imports.

### P2
- **Camera permission UX**: `permission_handler` dependency was unused; no settings route. Added `ensureCameraPermission()` / `explainCameraIssue()` + open-app-settings path.
- **Vision outcomes never persisted**: 7 vision tests completed without writing history (spec §27/39/44). Added `persistVisionResult(...)` for all vision tests; journey test asserts the history row (uncalibrated checklist → honest `unableToAssess` record).
- **History duplicate inserts**: back/forth re-runs duplicated result sets. Added `_persistOnce()` on summary entry only; delete-all test asserts empty.
- **Arabic locale ignored by Material scaffolding**: `MaterialApp` had no `supportedLocales`/delegates, so `WidgetsApp` fell back to en/LTR — Material widgets (dialogs, pickers) stayed LTR and `localeOf` returned `'en'` while app strings were Arabic. Fixed with `flutter_localizations` + `supportedLocales [en, ar]` + global delegates; journey test asserts root `Directionality.rtl`.

### P3 / hardening (not changed — unverifiable without device)
- `RECORD_AUDIO` + storage permissions are merged from `camera_android_camerax` (app never requests audio, never records); `INTERNET`/`ACCESS_NETWORK_STATE` are merged from ML Kit's telemetry transport (app makes zero network calls). Recommend `tools:node="remove"` for `RECORD_AUDIO` in a future on-device-verified pass.

### UI/UX enhancements (this audit)
Home research-status card + research-mode line; screening step header (Step N of 8) + camera overlay face-guide with LIGHTING/FACE/EYES chips; history day-grouped timeline + evidence-tier line + §57 detail order; About icon section headers + pipeline diagram; Settings learn-more links; Emergency calm wording; Vision Lab per-test calibration headers ×7 + test-catalog dialog; `DevStrings.of`.

## 3. Status table (actual results only)

| Area | Verdict | Evidence |
|---|---|---|
| Camera pipeline (single, lifecycle, capture, permissions) | PASS (P0/P1 fixed) | grep 1 site; analyze clean; lifecycle + gate widget tests |
| Camera live stream / frames | BLOCKED | No physical device; emulator offline |
| ML Kit face/eye tracking | BLOCKED | Needs real frames |
| Analyzers (12 modules, honesty gating, badges) | PASS (P0/P1 fixed) | 111 tests; analyzer + quality-gate suites |
| Screening gate (camera-less honesty) | PASS | Journey test: banner shown, Continue disabled |
| Vision Lab (8 tests, calibration, persistence) | PASS (P2 fixed) | Journey test asserts persisted row |
| History (timeline, versions, tiers, delete-all) | PASS (P2 fixed) | Journey delete-all asserts empty |
| Research gate + /dev tabs + experiments + export | PASS | Journey test: gate dialog, 4 tabs content, create, delete-all |
| Evidence DB (27 entries / 40 refs) + audit + references | PASS (P1 fixed) | evidence_safety_test (18); journey learn/references/audit |
| Privacy (local-only, no uploads/recognition) | PASS (+P3 note) | grep clean; merger-report provenance |
| Security (/dev route gating) | PASS | Tile gated by researchMode; journey test |
| I18n (Arabic RTL incl. Material scaffolding) | PASS (P2 fixed) | Journey arabic test (strings + RTL) |
| Accessibility (labels, contrast, no color-only) | PASS* | Static review; *screen-reader run BLOCKED (no device) |
| Performance | PASS* | *Static only; profiling BLOCKED |
| Offline core | PASS | No network deps for core features |
| Release APK | PASS | 84.1 MB, badging verified, EXIT_CODE=0 |
| Logging hygiene | PASS | Zero print/debugPrint in lib |
| Widget journeys (6, real providers + FFI DB) | PASS | 6/6 in full suite |

## 4. BLOCKED items (require a physical Android device)

Live camera frames, ML Kit tracking behavior, install/launch, screen-reader pass, runtime profiling, and the `RECORD_AUDIO` removal hardening pass. `adb devices` shows no attached device; the `ocuscan_test` emulator is offline. An on-device `integration_test/app_journey_test.dart` suite exists in-repo for when hardware is available.

## 5. Test-methodology notes (environment, not app bugs)

Widget tests run under FakeAsync: `rootBundle` loads and FFI futures started from widget code do not resolve with pumps alone, and directly awaiting them in a test body deadlocks the test. The journey suite uses proven patterns: runAsync/pump ratcheting for multi-round-trip FFI work, a test-only evidence loader override (identical JSON file, disk transport; production path untouched), scroll-to-build for lazy lists/horizontal TabBars (below-fold items don't exist until scrolled), and settling TabBar flings before tapping labels. Details in `AUDIT_MATRIX.md`.

## 6. Residual risks / recommendations

1. Clinical: OcuScan is a research prototype, not clinically validated — already stated in-app (About, Learn, banners); keep every new module behind Tier-C + experimental badges until validation data exists.
2. On-device verification of camera/ML/speech/profiling at first hardware access; then execute `integration_test/app_journey_test.dart`.
3. Re-evaluate `RECORD_AUDIO` removal and storage-permission scoping with a device in hand.
4. Keep the 111-test suite green; the 6 journey tests are the end-to-end safety net for honesty gating, persistence, research gating, evidence rendering, and RTL.
