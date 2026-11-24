# OcuScan System Architecture (v0.5)

Research-platform architecture. No certification claimed.

## Pipeline

```text
ACQUIRE (CameraService: permission → controller → preview ∥ stream)
  → CHECK INPUT (frame validity: size/format/planes/stride/rotation)
  → LOCALIZE (ML Kit face → EyeGeometry → EyeTracker states)
  → MEASURE (12 analyzers + 7 vision tests; per-module needs)
  → CHECK MEASUREMENT QUALITY (QualityGate; analyzer-specific gates)
  → ESTIMATE UNCERTAINTY (quality/confidence/frame counts; explicit gaps)
  → SCREEN (three states only: no-obvious-abnormality / possible-finding / unable-to-assess)
  → EXPLAIN (finding label, why-flagged, limitations, next step)
  → CITE EVIDENCE (tiered entries → references)
  → GUIDE USER (stage-specific instructions, recovery, help, emergency path)
```

## Subsystems

- **Acquisition**: `CameraService` (front/rear/best sources, fallback
  configs, watchdog, FPS counters, error/event rings, diagnostic
  export). Preview and analysis are independent paths.
- **Localization**: `EyeGeometry` (normalized raw space) + `EyeTracker`
  (12 states, EMA smoothing, 5-frame loss budget, 5-frame lock).
- **Measurement**: `Analyzer` base (`analyzer.dart`), 12 modules in
  `features/analyzers/`, `AnalyzerRegistry` (19 pinned entries with
  versions), `researchTracks` catalog (future directions, never measured).
- **Vision Lab**: 7 tests, each intro → calibrate → run → structured
  result; adaptive staircases (`Staircase`), seeded orders, per-eye
  protocols; persistence with conditions + versions.
- **Quality**: `QualityGate` (stills) + live luminance/blur + analyzer
  `meetsNeed` gates. LOW quality never yields confident results.
- **Evidence**: `medical_evidence.json` (27 entries / 40 refs), tiers,
  audit page, references library. Published numbers never presented as
  OcuScan performance.
- **Safety**: `SafetyLanguage` (banned phrases, no-false-reassurance
  enforcement), independent emergency pathway, experimental badges.
- **Data**: one SQLite file (`ocuscan.db` v4): results (+provenance),
  sessions, experiments, trials, reference_labels, device_profiles.
  Local-only; raw images never in DB.
- **Research**: `/dev` (12 tabs + Risk), experiments/trials/reference
  labels, statistics, exports (row-only CSV/JSON), diagnostic reports.
- **Localization**: `AppStrings` (~200 keys) + `DevStrings`, explicit
  locale, persisted, RTL, Tajawal bundled. Records stay canonical
  English (locale-independent rows).

## Invariants

1. No analyzer receives unmeasured constants.
2. No result without quality + limitations + evidence link.
3. No diagnosis, score, probability, or prescription anywhere.
4. No silent failure: every stage has a named state; errors recorded.
5. No network for core features; no image uploads, ever.
6. Retinal sources refuse non-retinal images by design.
