# OcuScan Audit Matrix — v0.3.1 + v0.3.2

Audit of the actual v0.3.0 codebase plus v0.3.1 fixes. Verdicts: PASS /
FAIL (fixed) / BLOCKED (needs physical device) / EXPERIMENTAL (by design).
Severity: P0 crash/data-loss/safety · P1 major broken · P2 important ·
P3 cosmetic.

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Camera | Single pipeline, no duplicates | `camera_service.dart` (sole CameraController/ImageStream/FaceDetector) | source grep | PASS | — | — | — | grep: 1 site |
| Camera | Re-entry leak (route reopen) | `camera_service.dart:init()` | code review | FAIL→fixed | Old controller never disposed; duplicate streams/camera lock | P1 | init guard + dispose-first; `release()` on screen dispose | analyze clean; lifecycle test re-enters flow |
| Camera | Capture failure blacks preview | `camera_service.dart:captureStill()` | code review | FAIL→fixed | Stream not restarted if takePicture throws | P1 | finally-restart | analyze clean |
| Camera | Permission UX | screening/record flows | code review | FAIL→fixed | permission_handler dep unused; no settings route | P2 | ensureCameraPermission + explainCameraIssue + openAppSettings | widget test taps flow |
| Camera | Live stream/frames/lifecycle | device runtime | — | BLOCKED | No physical device; emulator camera virtual | — | — | Requires physical device |
| ML | ML Kit face/eye tracking | `camera_service` + FaceFrame | — | BLOCKED | Needs real frames | — | — | Requires physical device |
| Analyzers | No mocks/placeholders in modules | `features/analyzers/*` | source grep | PASS | — | — | — | grep clean |
| Analyzers | Blink filler → false finding | `screening_flow:_runAllAnalyzers` | code trace | FAIL→fixed (P0) | `List.filled(150, 0.9)` → 0 blinks/min → possibleFinding from non-data | P0 | Gate on ≥30 tracked samples, else unable | unit tests; flow review |
| Analyzers | Corneal constant → false normal | same | code trace | FAIL→fixed | `(0.15, 0.6)` → "No opacity" from thin air | P1 | Explicit unable (no segmentation model) | flow review |
| Analyzers | Pupil/alignment proxies → normals | same | code trace | FAIL→fixed | Openness-proxy frames + yaw/constant cover deltas | P1 | Explicit unable with reasons | flow review |
| Analyzers | Surface/lens/nystagmus constants | same | code trace | FAIL→fixed | Safe outcomes but unmeasured inputs | P2 | Explicit unable with reasons | flow review |
| Analyzers | 12 modules verified | analyzers + tests | `flutter test` | PASS | Contracts, thresholds, unable-paths covered | — | — | 111 tests pass |
| Analyzers | Experimental badges | lens/corneal/surface/pupil-response | UI review | PASS | Badges + registry flags + Tier C | — | — | analyzer_info_screen |
| QualityGate | Veto + failure codes | quality_gate + tests | `flutter test` | PASS | LOW blocks; blur/dark/geometry cases | — | — | quality_gate_test |
| Vision | Distance/near/color/contrast/central/peripheral/cover/refractive | vision_lab_screen + vision_logic | widget test + review | PASS | Each has calibration header, eye separation, restart (re-tap/re-submit) | — | Added `_CalibrationHeader` ×7 + test catalog dialog | journey test |
| Vision | History persistence | persistVisionResult | code review | FAIL→fixed | Vision outcomes never saved (spec §27/39/44) | P2 | Persist all 7 tests with finding mapping + calibration quality | journey test asserts row |
| Vision | No zoom | textScaler lock | code review | PASS | `TextScaler.linear(1.0)` | — | — | review |
| History | Duplicate inserts | `_runAllAnalyzers` + `_next` | code review | FAIL→fixed | Back/forth re-runs duplicated 12-row sets | P2 | `_persistOnce()` on summary entry only | journey delete-all asserts empty |
| History | Timeline, versions, evidence | history_screen | widget test | PASS | Day-grouped headers, analyzer version, tier line, §57 detail | — | Added grouping + tier + §57 order | journey test |
| Research | Hidden gate, defaults OFF | settings + dev_dashboard | widget test | PASS | researchMode/captures OFF; double ack; settings tile only when ON | — | — | journey test enables + opens /dev |
| Research | CRUD + delete-all + export | validation repo + tabs | unit + widget test | PASS | ffi-backed CRUD tests; CSV/JSON no-image tests | — | — | validation_db/misc tests |
| Research | Fairness fields + migration v3 | app_database + models | unit test | PASS | Idempotent ALTERs; round-trip test | — | — | validation tests |
| Evidence | 27 entries, 40 verified refs | medical_evidence.json | tests + web verification | PASS | Every ref real (DOI/PMID/URL verified live); tiers/statuses; coverage 1.0 | — | — | evidence_safety_test (18) |
| Evidence | Audit page computes from data | EvidenceAuditTab | widget test | PASS | Coverage, orphans, identifiers, staleness, Tier-C shipped | — | — | journey test opens tab |
| Evidence | Audit re-read bundle raw (fragile) | `dev_analysis_tabs:_load` | code trace + widget test | FAIL→fixed | Second raw rootBundle read after repo load; any bundle failure → spinner forever, audit never renders | P2 | Derive duplicate-ids from loaded repo; removed now-unused imports | journey Evidence-Audit tab asserts content |
| References | Full biblio, filters, search | references_screen | widget test | PASS | No raw JSON; disclaimer present | — | — | journey test |
| Privacy | No uploads/recognition; delete-all | code grep + tests | PASS | No http/upload deps for images; captures local-only; exports row-only | — | — | grep + misc tests |
| Privacy | Manifest permissions provenance | aapt + manifest-merger report | PASS* | RECORD_AUDIO + storage come from camera_android_camerax merge (app never requests audio, never records); INTERNET/ACCESS_NETWORK_STATE come from ML Kit telemetry transport (app makes zero network calls — grep clean) | P3 | Recommend `tools:node="remove"` for RECORD_AUDIO in a future hardening pass (unverifiable without device, so not changed now) | merger report lines 404/622/628 |
| Security | /dev route exposure | app.dart + settings | review | PASS | Route table only; settings tile gated by researchMode | — | — | journey test |
| I18n | Arabic RTL | app/dev strings + screens | widget test | PASS | arabic test asserts RTL + strings | — | — | journey test |
| I18n | Material scaffolding ignored Arabic locale | `app.dart` MaterialApp | widget test | FAIL→fixed | No supportedLocales/delegates: WidgetsApp fell back to en/LTR, so Material widgets (dialogs, pickers) stayed LTR and localeOf returned 'en' while app strings were Arabic | P2 | Added flutter_localizations + supportedLocales [en, ar] + global delegates | journey arabic test asserts root Directionality.rtl |
| A11y | Labels, contrast, no color-only | theme + widgets | review | PASS | Icon+text badges; text scaling; high contrast | — | Partial: screen-reader audit BLOCKED (no device) |
| Perf | No leaks by construction | camera release; bounded lists | review | PASS* | *Runtime profiling BLOCKED | — | — | *Static only |
| Offline | No network deps for core | pubspec grep | PASS | path_provider/share only for export/share actions | — | — | review |
| Build | Release APK | build log + aapt | PASS | app-release.apk 84.1MB, com.ocuscan.ocuscan v0.1.0(1), minSdk24/target36, EXIT_CODE=0 | — | — | aapt dump badging verified |
| Logging | No sensitive logs | grep print/debugPrint | PASS | Zero matches in lib | — | — | grep |
| Tests | 6 widget journeys, real providers + FFI DB | `test/audit_journey_test.dart` | `flutter test` | PASS | Onboarding, screening-gate, vision-persist, learn/references, research-tabs/experiment/delete-all, arabic-RTL | — | Test-only `EvidenceRepository.debugLoaderOverride` (same file, disk transport); scroll-to-build + runAsync/pump ratchet patterns | 111/111 pass |

*Items marked BLOCKED require a physical Android device (camera frames, ML
tracking, screen-reader, profiling, install). The emulator covers lifecycle,
permission, navigation, persistence, and rendering verification instead.

## v0.3.2 — real-device UX overhaul (details: V0_3_2_UI_CAMERA_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Camera | ML Kit rotation hardcoded 0° | `camera_service:_onImage` | code trace | FAIL→fixed | Sideways frames on portrait front camera → unreliable landmarks/eye-open; root cause of eye-positioning failures | P0 | Computed rotation (sensor+device orientation, front-portrait 270°), logged per frame | eye_tracking rotation tests; needs device run |
| Camera | Fast detector mode | `camera_service` FaceDetector | review | FAIL→fixed | Poor landmarks | P1 | Accurate mode (tracking kept; `_busy` serialization kept) | FPS impact needs device profiling (BLOCKED) |
| Camera | No geometry/diagnostics | `camera_service` + flow | code trace | FAIL→fixed | Static guide box unrelated to face; generic ADJUST; no crops/gates | P1 | EyeGeometry + EyeTracker (12 states, EMA, 5-frame loss budget, 5-frame lock) + staged Eyes UI + /eye-debug overlay/log/still-inspector | 31 transform/state tests; 7 journeys |
| Camera | Detector close crashes teardown | `camera_service.dispose` | widget test | FAIL→fixed | Unawaited ML Kit close error failed tests/teardown | P2 | Guarded async close | full suite green |
| I18n | 95% strings hardcoded EN | all screens | source audit + device report | FAIL→fixed | Language switch changed almost nothing | P1 | AppStrings ~25→~200 keys; DevStrings research chrome; canonical codes for filters | localization tests (8); AR walkthrough over 14 routes |
| I18n | No Arabic font | pubspec/assets | review | FAIL→fixed | Inconsistent shaping per device | P2 | Tajawal R/M/B bundled (OFL, credited), app fontFamily | walkthrough AR screens |
| I18n | RTL chevrons/arrows | tiles/diagram | review | FAIL→fixed | Hardcoded right-pointing | P3 | NavChevron; pipeline arrows mirror; overlay L/R never swapped | AR walkthrough |
| UI | Generic Material look | all screens | review | FAIL→fixed | Boring/flat | P2 | Tokens (OcuSpace/OcuRadii/tints), editorial Home, result rail layout, vision previews, labeled loaders, empty states, lock/stage animations | journeys; analyze clean |
| Privacy | Permission provenance | aapt + merger report | PASS | RECORD_AUDIO/storage from camerax merge; INTERNET from ML Kit transport; zero runtime audio/network use (grep) | P3 | Documented; removal deferred to on-device pass | merger report |
| Build | Release APK v0.3.2+2 | build log + aapt | PASS | app-release.apk 85.2MB, com.ocuscan.ocuscan v0.3.2(2), minSdk24/target36, clean→pub→analyze(0)→test(151)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | Lock reliability, FPS, shaping, reader, profiling | real phone | — | BLOCKED | No device in this environment | — | Creator test script in V0_3_2 doc §5 | — |

## v0.3.3 — physical-device pipeline debug + front/rear sources (details: V0_3_3_CAMERA_RUNTIME_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Camera | Stuck at "Starting camera" on device | full pipeline | code trace + device report | FAIL→fixed | No stage separation; preview blocked behind analysis states; silent swallowing; assumed NV21 layout | P0 | Explicit CameraStage machine; preview/analysis split; watchdog (8 s); observed-layout ML format choice; recorded errors; recovery ladder | 17 pipeline tests; journeys |
| Camera | Single/initState notify crash | screening/eye-debug init | widget test | FAIL→fixed | prepare() notified synchronously in initState (build phase) | P1 | Post-frame deferred camera start | journeys green |
| Camera | Detector close teardown crash | service dispose | widget test | FAIL→fixed | Unawaited close error attributed to running test | P2 | Guarded async close | full suite green |
| Camera | Front/rear/best sources | service + Eyes UI + /dev | unit + widget test | PASS (new) | Switching lifecycle, assisted rear mode, capabilities, best decision, L/R safety, comparison, export, restart | — | — | pipeline tests; selector/help journey asserts; AR walkthrough 16 routes |
| Tests | 168-test suite | test/ | `flutter test` | PASS | 151 baseline + 17 pipeline, 0 regressions | — | — | EXIT 0 |
| Build | Release APK v0.3.3+3 | build log + aapt | PASS | app-release.apk 85.5MB, com.ocuscan.ocuscan v0.3.3(3), minSdk24/target36, clean→pub→analyze(0)→test(168)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | Tests A–I physical verification | real phone | — | BLOCKED | No device in this environment | — | In-app /dev observability + creator protocol | — |

## v0.3.4 — face-detection root-cause investigation (details: V0_3_4_FACE_DETECTION_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Camera | Face never detected on device | full pipeline | device report + code trace | FAIL→instrumented | Prior fixes unverified on hardware; single "Starting camera" state hid first failing box; silent per-frame swallowing | P0 | Stage-separated pipeline already in; added frame index, ML-ready flag, raw face boxes, face-fail log, health panel, timeline, test buttons, logcat card | device run pending (BLOCKED here) |
| Camera | Minimal face test | `/face-test` | widget journey (builds) | PASS (new) | Needed tracker-free Camera→image→ML→count+box gate | — | New screen, both cameras, raw overlay, PASS/FAIL readout | walkthrough visits route |
| Camera | Still face test + first-frame save | eye-debug | widget journey (builds) | PASS (new) | Needed Case A/B separation + inspectable frames | — | Explicit still/image/ml readout; ML grayscale view; local save + delete | walkthrough visits route |
| Camera | Snapshot fallback | screening recovery | code review + analyze | PASS (new) | Live-unreliable devices need an honest still path | — | SnapshotScanView; same-still pixel analysis; temporal modules unable; labeled summary | analyze clean; journey green |
| Camera | initState notify crash (prepare) | screening/eye-debug | widget test | FAIL→fixed | Synchronous notify in initState (build phase) | P1 | Post-frame deferred camera start | journeys green |
| Camera | Detector-close teardown crash | service dispose | widget test | FAIL→fixed | Unawaited close error hit running test | P2 | Guarded async close | full suite green |
| Tests | 169-test suite | test/ | `flutter test` | PASS | 168 baseline + still-geometry tracker test, 0 regressions | — | — | EXIT 0 |
| Build | Release APK v0.3.4+4 | build log + aapt | PASS | app-release.apk 85.8MB, com.ocuscan.ocuscan v0.3.4(4), minSdk24/target36, clean→pub→analyze(0)→test(169)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | TEST 1–8 physical verification | real phone | — | BLOCKED | No device in this environment | — | Creator protocol + report template in audit doc | — |

## v0.4 — robust acquisition + professional Vision Lab + expansion + UX (details: V0_4_VALIDATION_AND_DEVICE_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Camera | Unused contour pipeline cost | service detector config | review | FAIL→fixed | Contours enabled, nothing consumed them | P3 | Contours OFF (landmarks/classification/tracking kept) | analyze; suite green |
| Camera | Stream start undistinguished | service init | review | FAIL→fixed | startImageStream failure collapsed into initFailed | P2 | Distinct `streamFailed` stage + recorded error | pipeline tests |
| Vision | Simplistic game-like tests | vision_lab_screen + vision_logic | widget + unit test | FAIL→fixed | Fixed ladders, no intros/restarts, unstructured results, no calibration depth | P1 | Staircase acuity (per-eye, threshold, real text-scale check), leveled color, adaptive contrast, sequential central, catch-trial peripheral, intros/restarts/result cards/index | vision_logic (11) + journeys |
| Catalog | Future-module architecture | analyzer_registry + learn | unit test | PASS (new) | Needed evidence-driven capability catalog without fake classifiers or registry pollution | — | Separate `researchTracks` list (9 tracks, EXPERIMENTAL/FUTURE, Tier C) + Learn section; registry pinned at 19 | research_tracks (4) |
| UI | Command-center/home, pills, countdown, headers, studyType, reduced motion | home/eye_stage/vision/references/eye_positioning | widget test | PASS | Polish gaps vs spec | P3 | OCUSCAN kicker, Learn entry, status pills, evidence-type line, static lock ring | AR walkthrough 17 routes |
| Safety | Banned language, privacy, no-mocks | lib grep + tests | PASS | No diagnoses/scores/risks; no network clients; no mocks/prints; permissions provenance unchanged | — | — | safety suites + audits |
| Tests | 189-test suite | test/ | `flutter test` | PASS | 184 baseline + 5 stream fallback/stale-stream tests, 0 regressions | — | — | EXIT 0 |
| Build | Release APK v0.4.0+5 (stream hotfix) | build log + aapt | PASS | app-release.apk 86.0MB, com.ocuscan.ocuscan v0.4.0(5), minSdk24/target36, clean→pub→analyze(0)→test(189)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | TEST 1–8 + condition matrix | real phone | — | BLOCKED | No device in this environment | — | Creator protocol in audit doc | — |

## v0.5 — advanced screening platform (details: V0_4_VALIDATION_AND_DEVICE_AUDIT.md + docs below)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Results | Traceability fields | screening_result + DB v4 + history detail | unit + widget test | PASS (new) | Rows lacked uncertainty/hardware/device/algorithm/evidence versions | P2 | 5 optional fields, v4 migration (old rows read back empty), copyWith, populated at persist, "Why this result?" chain in detail | round-trip + suite |
| Camera | Multi-face handling | tracker + service + guidance | unit + widget test | PASS (new) | First face picked arbitrarily; no multi-face state | P1 | Largest-face forwarding + `multipleFaces` refusal state + guidance + all-boxes research view | tracker test; walkthrough |
| Camera | Contours cost; stream undistinguished | service | review | FAIL→fixed | Unused contours cost latency; stream failure collapsed | P3/P2 | Contours OFF; distinct `streamFailed` | suite green |
| Vision | Game-like tests | vision_lab + vision_logic | unit + widget test | FAIL→fixed | Fixed ladders, no intros/restarts/results structure | P1 | Adaptive staircases, leveled color, catch-trial peripheral, per-eye central, intros/restarts/result cards/index, real text-scale check | vision_logic (11); journeys |
| Catalog | Future-module architecture | registry + learn | unit test | PASS (new) | Needed capability catalog without fake classifiers | — | Separate `researchTracks` (13: neuro/ocular/retinal/voice/gait/stereo) + Learn section; registry pinned 19 | research_tracks (4+) |
| Risk | Risk register + tab | assets + dev + test | unit test | PASS (new) | No structured risk record | P2 | risk_management.json (15 entries) + /dev Risk tab + schema tests | risk_register (4) |
| UI | Command center, pills, countdown, headers, studyType, reduced motion, learn-why link | home/eye_stage/vision/references/history | widget test | PASS | Polish gaps | P3 | OCUSCAN kicker, Learn entry, status pills, evidence-type line, static lock ring, detail Learn link | AR walkthrough 17 routes |
| Safety | Banned claims, privacy, no-mocks | lib grep + tests | PASS | Extended hospital/clinical-grade phrase list; audits clean | — | — | misc test list; audits |
| Docs | 9 new docs | repo root | review | PASS (new) | Missing architecture/risk/usability/validation/model/algorithm/dataset/device/limitations/release docs | — | Written; no cert claims | — |
| Tests | 246-test suite | test/ | `flutter test` | PASS | 208 baseline + layout/adaptive/multi-face/still-geometry/banned tests, 0 regressions | — | — | EXIT 0 || Build | Release APK v0.5.0+6 | build log + aapt | PASS | app-release.apk 86.1MB, com.ocuscan.ocuscan v0.5.0(6), minSdk24/target36, clean→pub→analyze(0)→test(194)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | TEST 1–8 + condition matrix | real phone | — | BLOCKED | No device in this environment | — | Creator protocol in audit docs | — |

## Test-environment methodology notes (not app bugs)
- `rootBundle` asset loads and FFI-DB futures started inside widget code do
  not resolve under the fake-async test clock with pumps alone; awaiting them
  directly in a test body deadlocks the test. Proven patterns used in the
  journey suite: (1) `tester.runAsync` real-time windows interleaved with
  pumps ("ratchet") for multi-round-trip FFI work; (2) a test-only loader
  override reading the identical evidence JSON from disk; (3) scrolling lazy
  lists/TabBars to build items before asserting (below-fold widgets,
  including items ~9px past the viewport edge, do not exist until scrolled);
  (4) letting TabBar strip flings settle before tapping tab labels.

## v0.6 — useful features: trends, doctor report, retest, profiles

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Data | Person profiles (local-only) | screening_result + DB v5 + settings + home | unit + widget test | PASS (new) | Single shared history for all users of a phone | P2 | profileId on rows (default self, backfilled), profiles table, prefs + AppState active profile, settings radios/add/delete, home indicator | suite green |
| History | Trends over time | trends_screen + trend_logic + test | unit + widget test | PASS (new) | No cross-visit comparison; risk of invented charts | P2 | Per-test timeline with conservative comparability chips (quality+calibration+eye); recorded text only, no charts | trend_logic (8); walkthrough |
| History | Doctor report | clinical_report + report_screen + test | unit test | PASS (new) | No shareable professional summary | P2 | Pure builder (latest per test, full limitations/actions, non-diagnosis framing) + preview + system share; banned-language tested EN+AR | clinical_report (4) |
| Vision | Guided retest | vision_lab args + history detail | widget test | PASS (new) | Retests never reproduce setup | P2 | Route args (tab + setup banner), history detail per-test retest buttons | walkthrough routes |
| Tests | 226-test suite | test/ | `flutter test` | PASS | 220 baseline + trend/report/profile tests, 0 regressions | — | — | EXIT 0 |
| Build | Release APK v0.6.0+7 | build log + aapt | PASS | app-release.apk 86.4MB, com.ocuscan.ocuscan v0.6.0(7), minSdk24/target36, clean→pub→analyze(0)→test(226)→build EXIT 0 | — | — | aapt dump badging verified |
| Device | Camera loop + TEST 1–8 | real phone | — | BLOCKED | No device in this environment | — | Creator protocol in audit docs | — |

## v0.6 — capability catalog + research modules (details: V0_6_CAPABILITY_AND_MEDICAL_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Catalog | Master capability registry | assets/detection_catalog.json + loader + explorer UI | unit + widget test | PASS (new) | No evidence-driven capability registry; statuses merged | P1 | 70 entries, separated implementation/evidence/validation statuses, hardware requirements, live references | detection_catalog (6); explorer in walkthrough |
| Research | Facial-movement detail (amplitude+timing) | facial_movement.dart + timestamps | unit test | PASS (new) | Samples had no timestamps; speed unmeasurable | P2 | ExpressionSample + FacialMovementAnalyzer; enriched measurement text | facial_movement (5) |
| Research | Retinal quality gate | retinal_quality.dart | unit test | PASS (new) | No gradability gate for future retinal images | P2 | RetinalQualityGate (focus/illumination/field/artifacts/motion/contrast/visibility) | retinal_quality (4) |
| Research | Modality requirements | analyzer_registry | unit test | PASS (new) | Analyzers did not declare hardware needs | P2 | modalityRequirements map + requirementsFor | validation_models (1) |
| Safety | Banned claims | lib + assets grep | unit test | PASS | Extended hospital/clinical-grade/probability list | P2 | Added ruled-out/disease-free/risk-%/probability-of-disease | misc test list |
| Risk | Risk register rows | risk_management.json | unit test | PASS (new) | No structured risk record | P2 | +2 rows (multi-face, snapshot substitution) | risk_register (4) |
| UI | Capability explorer + home/learn entries | capabilities_screen, capability_detail, home, learn | widget journey | PASS | No user-facing capability directory | P2 | Search/filter/cards + detail with live evidence | walkthrough 19 routes |
| Tests | 226-test suite | test/ | flutter test | PASS | 220 baseline + trend/report/profile/catalog/retinal/facial-movement/risk | — | — | EXIT 0 |
| Build | Release APK v0.6.0+7 | build log + aapt | PASS | app-release.apk 86.5MB, com.ocuscan.ocuscan v0.6.0(7), minSdk24/target36 | — | — | aapt dump badging verified |
| Device | Camera loop + TEST 1–8 | real phone | — | BLOCKED | No device in this environment | — | Creator protocol in audit docs | — |

## v0.7 — final product engineering (details: V0_7_FINAL_PRODUCT_AUDIT.md)

| Area | Feature | Location | Test method | Status | Issue | Sev | Fix | Verification |
|---|---|---|---|---|---|---|---|---|
| Catalog | Clinical status + Available filter + audit cross-check | detection_catalog + explorer + audit tab | unit + widget test | PASS (new) | Missing clinical axis; no Available grouping; audit blind to orphan capabilities | P2 | clinicalStatus research-only on all 70; Available-now filter; orphan section in Evidence Audit (override-safe) | catalog tests; journeys |
| Research | Facial movement detail + timestamps | facial_movement + flow | unit test | PASS (new) | Amplitude/timing unmeasured; speed unclaimable | P2 | ExpressionSample + analyzer; enriched measurement text; finding logic untouched | facial_movement (5) |
| Research | Retinal quality gate | retinal_quality | unit test | PASS (new) | No gradability gate | P2 | 9-signal gate, named reasons, doubt means ungradable | retinal_quality (4) |
| Research | Modality requirements | analyzer_registry + methodology | unit test | PASS (new) | Hardware needs undeclared | P2 | Per-key camera/eyes/temporal/source + cards row | validation_models (1) |
| Research | Tracks: voice/gait/dementia/stereopsis/skin/genetic/endocrine | researchTracks + learn | unit test | PASS (new) | Multimodal + phenotype futures uncatalogued | — | 13 tracks total, FUTURE, Tier C, never measured | research_tracks (4+) |
| Risk | +2 rows (multi-face, snapshot) | risk_management.json | unit test | PASS (new) | New features lacked risk rows | P2 | Appended, schema-tested | risk_register (4) |
| UI | Risk tab, tracks section, Learn articles, switch-camera recovery, health eyes/lock, Learn-why link | dev/learn/eye_stage/eye_debug/history | widget test | PASS | Coverage gaps | P3 | Tab + cards + articles + buttons + rows | walkthrough |
| Safety | Banned claims extended | validation_misc_test | unit test | PASS | Missing ruled-out/disease-free/probability phrases | P2 | Added after zero-hit manual review | misc test |
| Docs | 13-doc release set | repo root | unit test | PASS (new) | Undocumented governance | — | 9 new docs + doc-guard tests (existence, no-cert-claims) | release_docs (3) |
| Tests | 368-test suite + 9 JVM | test/ + android unit | `flutter test` + `:app:testDebugUnitTest` | PASS | Universal architecture: engine interfaces/manager/profile/validator, native mapping, bitmap/RGBA, compat lab route, failover-due rule | — | vision_compat + pipeline + jpeg_fallback + ml_diagnostic + journey + JVM green | EXIT 0 |
| Build | Release APK v0.7.10+18 (+ DEBUG) | build log + aapt + ABI audit | PASS | app-release.apk 87.0MB + app-debug.apk, com.ocuscan.ocuscan v0.7.10(18), minSdk24/target36, ABIs arm64-v8a/armeabi-v7a/x86_64, bundled libface_detector_v2_jni.so in all ABIs, clean→pub→analyze(0)→test(368)→build EXIT 0 | — | — | aapt + APK lib audit verified, both variants |
| Build | Release 0.7.24+32 (no-device verification round) | analyze(0) + full suite (505) + aapt + apksigner + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.24(32). AAB 68.9MB + APK 83.6MB, keystore-signed, obfuscated. Crash sweep: all bangs/casts/substrings triaged safe. New failure-panel widget tests (permission/mlDegraded/report-error) + TechDetails Material fix. REAL BUG FOUND BY TESTS: report _load re-triggered itself forever on persistent failure (profile recorded only on success) — profile now recorded at load start. Dex re-verified. | — | — | Device proof: single install-and-confirm round only (preview, report, export) |
| Build | Release APK v0.7.23+31 (native preview fix + report errors) | analyze(0) + full suite (499) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.23(31). Preview root cause: Flutter Texture ignores the SurfaceTexture transform, so CameraX sensor-landscape buffers displayed sideways/stretched; new shared NativePreviewTexture (RotatedBox turns=rot/90 + centered front mirror) on all 4 native preview sites, 4 widget tests. Report: load failures now a named error + Retry instead of fake-empty. Dex re-verified. | — | — | Device proof: install, confirm native preview upright + mirrored on front, run a screening, open the report, export |
| Build | Release 0.7.22+30 (deployment-ready: signing + AAB + identity + resilience) | analyze(0) + full suite (495) + aapt + apksigner + dex keep audit + osv-scan clean | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.22(30). AAB 68.9MB + APK 83.6MB, both keystore-signed (SHA-256 c129:…:1456, 2026-2051), obfuscated, symbols retained. Real keystore wired via gitignored key.properties (debug fallback when absent). OcuScan label + custom eye-mark icons (adaptive/legacy/iOS/store-512). WRITE_EXTERNAL_STORAGE stripped. Resilience: permission-denied persistent panel, mlDegraded honesty (title/pills/checklist/panel gate), guard on every native start, recovery copy fix, snapshot disabled-with-reason under native, native silent-window starting state. Dead cloud switch -> static offline notice. PRIVACY_POLICY.md + PLAY_DATA_SAFETY.md + RELEASE_NOTES_0.7.22.md. Dex re-verified. | — | — | Device proof: FRESH INSTALL on 0.7.22 (keystore change orphans debug-signed data — back up nothing, history rebuilds), smoke all flows, rear/airplane runs, export |
| Build | Release APK v0.7.21+29 (full architecture + pipeline audit) | analyze(0) + full suite (495) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.21(29). Audit findings fixed: isMirrored engine-aware (rear-native overlays were flipped; per-observation truth persisted), snapshot capture disabled with stated reason under native (was a dead button), record-trial preview native branch, native-primary header comment corrected, README suite count + checklist scan label. Audit method: pipeline-core pass, UI native-safety sweep (all controller!/CameraPreview/captureStill/ready gates checked), docs-vs-code + TODO + test-pin sweep, checklist-vs-reality (mapping.txt, symbols, zero suppressions all verified). No Critical findings; 3 medium UI-truth fixes, 1 stale comment, 2 stale labels. Dex re-verified. | — | — | Device proof: install, rear overlay orientation, snapshot note under native, export |
| Build | Release APK v0.7.20+28 (overlay double-rotation fix) | analyze(0) + full suite (495) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.20(28). Root cause of shifted box + glitchy eyes: pre-rotated bitmap/file rungs emit upright-normalized coords but tracker/overlay/logs/crops speak sensor frame + rotation metadata, so every marker double-rotated (centered face drew 48px left + 72px down on 480x720). Fix: pure uprightNormToSensorNorm/BoxToSensorNorm fold-back at the geometry + lastFaceBoxes build sites (bytes/native paths already sensor-frame, untouched). Analyzer crop regions corrected on the same path. 6 mapping tests (round-trip all rotations, centered-invariance, box area). Dex re-verified. | — | — | Device proof: install, center face front lens, confirm box + eyes sit on the face, export |
| Build | Release APK v0.7.19+27 (native-primary readiness + oracle config) | analyze(0) + full suite (489) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.19(27). 0.7.18 device data fixes: engine-aware ready flag (native sessions no longer read not-ready across screening + dev gates), captureStill native guard, native session facts in cameraInfo, native texture branches in face-test/eye-debug previews + health panel + self-test, oracle probes (ml-test B, vision-core A/B) to production full config, exact ByteData slicing for bundled-asset files. Dex re-verified. | — | — | Device proof: install, re-run ml-test B + vision-core A (expect FACE_FOUND), confirm previews live under native, export |
| Build | Release APK v0.7.18+26 (hardening: majors + obfuscation + osv gate) | analyze(0) + full suite (489) + aapt + dex keep audit + osv-scan clean | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.18(26), 83.6MB obfuscated, symbols per ABI retained. 27 deps upgraded (camera 0.12.1, device_info_plus 13.3.0, permission_handler 13.0.2, share_plus 13.3.1, sqflite/sqlite3, win32 6.4.0); compileSdk pinned 37 (permission_handler_android 14.x AAR requirement; targetSdk/minSdk untouched). osv-scanner v2.6.0 lockfile gate: 114 packages, No issues found. Dex keeps re-verified under obfuscation. | — | — | Device proof: install, smoke-test camera+screening+compat (new plugin majors), export |
| Build | Release APK v0.7.17+25 (native-primary ML architecture) | analyze(0) + full suite (489) + aapt + dex keep audit + release Kotlin compile | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.17(25). Engine hierarchy flipped: zero-copy native CameraX engine is offered first on every fresh entry (pure nativePrimaryDue gate), Dart plugin-camera ladder is the automatic fallback. Silent-native 10s liveness guard with entry-scoped suppression (survives re-init, resets on fresh entry). Native quality parity: Kotlin coarse-Laplacian blur sampler (same scale as Dart) rides observations into FaceObservation/tracker gates. Native measurement parity: native inference ms into lastInferMs, zero-copy convert=0, mapping dims, tier reports native. Dex re-verified. | — | — | Device proof: install, confirm engine=native + tier=native in summary, compare latency/throughput vs 0.7.13 Dart, export |
| Build | Release APK v0.7.16+24 (Compat Lab redesign + security pass) | analyze(0) + full suite (486) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.16(24). Compat Lab rebuilt as status-hero + sectioned telemetry (Detection/Capabilities), 48dp actions, screen-reader row labels, copy-failure handling. Static security review: no Critical/Warning findings (local-only, no network/auth/secrets; backup off, cleartext off). Dex re-verified. | — | — | Device proof: install (replaces 0.7.14), verify new summary + rows, export |
| Build | Release APK v0.7.15+23 (revert fast default + detection reporting) | analyze(0) + full suite (485) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.15(23). CPH2121 falsified the 0.7.14 fast tier (275ms vs ~110ms accurate, drops 61%->84%): default path back to accurate; fast is a dev-only /ml-test toggle with per-generation latency stats. New: latency convert/infer split, per-tier generation table, sensor-vs-ML size split (kills the 720x480/270 vs 240x360/0 reporting race), throughput-aware health (starved/slow pipe = degraded), Compat Lab detection/throughput/quality/ML-input rows + copy-summary detection block, manufacturer populated, BITMAP_INPUT change-only logging. Dex re-verified: ModuleDescriptor fields + newFaceDetector present. | — | — | Device proof: install, confirm drops/latency back to 0.7.13 levels, check new Compat Lab rows, export |
| Build | Release APK v0.7.14+22 (two-tier detector) | analyze(0) + full suite (481) + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.14(22). New: accurate-search/fast-track two-tier live detector (same landmarks+classification; tracking IDs dropped, dev-display only) to cut the 60% single-flight drop rate; ack-hint line; still-geometry verdict; summary counts; directionArrow truth-table fix. Dex re-verified: ModuleDescriptor fields + newFaceDetector present. | — | — | Device proof: install, compare drop ratio + far-face detection vs 0.7.13, export |
| Build | Release APK v0.7.13+21 (Phase 1A vision-core) | analyze(0) + full suite (473) + aapt + dex field audit + APK content audit | PASS (build) / PARTIAL (device: front-live PASS 2026-10-03, rear/offline/multi-device OPEN) | com.ocuscan.ocuscan v0.7.13(21), 87.8MB. New: real-face bundled asset (Eileen Collins/NASA public domain, sha256 pinned) replacing synthetic oracle; /dev/vision-core A/B/C diagnostic; VisionSession lifecycle; native ML event markers; VisionFaceStatus contract. Dex re-verified: ModuleDescriptor MODULE_ID/MODULE_VERSION present, newFaceDetector present. | — | — | Device proof still required: install, /dev/vision-core Run all, TEST A must be FACE_DETECTED, then export |
| Build | Release APK v0.7.12+20 (final) | analyze(0) + full suite + aapt + dex keep audit | PASS (build) / OPEN (device) | com.ocuscan.ocuscan v0.7.12(20). Since v0.7.11+19: credit-card calibration, DPI-true optotypes, pitch-gated eyelid, eye-region redness v2, capture-attempt harness, summary/history/report deployment pass, bounded detector-recreate wiring. R8 keeps re-verified in this build's dex (MODULE_ID/MODULE_VERSION, newFaceDetector, getComponents). analyze(0), 437/437 tests. | — | — | Device proof still required: install, /ml-test Run all, Test B must be pass/noFace (not error), then export errors |
| Build | Release APK v0.7.11+19 (R8-keep fix) | mapping.txt + classes.dex field audit + aapt | PASS (build) / superseded | com.ocuscan.ocuscan v0.7.11(19). Root cause of detector NPE proven: R8 stripped MODULE_ID/MODULE_VERSION from ML Kit ModuleDescriptor (mapping showed only <init>); getLocalVersion()=0 skipped the bundled offline module for the downloadable one. Fixed by android/app/proguard-rules.pro; dex audit proved keeps. | — | — | Superseded by v0.7.12+20 |
| ML | Detector runtime NPE on real device | CPH2121 / API 31 error export | device run | FAIL (open) | `NullPointerException: ...java.lang.Object.getClass() on a null object reference` from obfuscated Google class across NV21/bitmap/JPEG-file/minimal-detector inputs; frames arrive and convert but processed=0, stage=mlDegraded | P0 | `/ml-test` UniversalFaceDiagnostic (A captured JPEG, B bundled asset, C packed bytes, D bitmap, E front, F rear, G restart/recreate/offline) + native CameraX instrumentation to isolate detector construction vs processing | BLOCKED — no device in this environment; obfuscated stack has no retrace map |
| Device | Live front-camera face detection (CPH2121, Android 12, 0.7.13+21, 2026-10-03) | real phone (creator export ocuscan-diagnostic-1791006499758.json) | PASS | rx=217 ok=83 drop=132, consecMlErrors=0, consecConvertErrors=0, tracker ready+locked 5/5, 10/10 consecutive LOCK frames with stable eye landmarks, errorLog empty, faceFails empty, bitmap rung, gen 4, hit rate 92.7% | — | First automatic-detection proof on hardware; R8-keep root-cause fix confirmed live | export file |

## Physical device test matrix (universal milestone §21 — real devices only, never fabricated)
| # | Device | Android/API | Cameras | Selected engine | Face result | Latency | Recovery observed | Tester/date |
|---|--------|-------------|---------|-----------------|-------------|---------|-------------------|-------------|
| 1 | OPPO CPH2121 | 12 / 31 | front+rear | dartMlKit (native pending) | FAIL (detector NPE, all paths) | — | ladder→mlDegraded, honest | creator, 2026-09-29 |
| 2 | _unfilled_ | 7 / 24+ | | | | | | |
| 3 | _unfilled_ | 8 / 26+ | | | | | | |
| 4 | _unfilled_ | 9 / 28+ | | | | | | |
| 5 | _unfilled_ | 10 / 29+ | | | | | | |
| 6 | _unfilled_ | 11 / 30+ | | | | | | |
| 7 | _unfilled_ | 13 / 33+ | | | | | | |
| 8 | _unfilled_ | 14 / 34+ | | | | | | |
| 9 | _unfilled_ | 15-16 / 35-36+ | | | | | | |
Protocol per device: install release APK offline → first launch (no internet) → Eyes stage 60s → record engine/face/latency → /ml-test Run all → export errors → Compat Lab screenshot. Second manufacturer family required before any "broad" claim.
