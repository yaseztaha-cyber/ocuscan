# OcuScan 0.7.22+30 — Deployment-readiness release

First release built for store submission: real signing, App Bundle,
hardened manifest, launcher identity, honest failure UX, privacy and
Data Safety documentation.

## Deployment

- Real release keystore (`android/ocuscan-release.keystore`, gitignored)
  wired via `android/key.properties`; release falls back to debug keys
  only when the properties file is absent (dev machines).
- App Bundle (`app-release.aab`) for Play; APK retained for direct install.
- Dart obfuscation + per-ABI debug symbols + R8 mapping retained.
- compileSdk 37 (permission_handler_android 14.x requirement);
  targetSdk 36, minSdk 24.
- Manifest: `WRITE_EXTERNAL_STORAGE` stripped (app-private dirs only),
  `RECORD_AUDIO` stripped, backup off, cleartext off.
- Launcher identity: OcuScan label, custom teal eye-mark icons
  (Android adaptive + legacy, full iOS set), 512px store icon.

## User-flow resilience (audit findings)

- Permission denial is now a persistent panel (Retry permission +
  Open settings + help) instead of a strandable banner.
- Detector-down states read "Analysis unavailable" with retry and
  still-capture escape; pills and checklist reflect analysis truth,
  including the native silent window (starting state, never ✓).
- Native liveness guard arms on every native start (primary, failover,
  manual).
- Recovery button renamed to what it does ("Take a still instead").
- Snapshot capture disabled with a stated reason while the native
  engine owns the camera.

## Privacy & compliance

- PRIVACY_POLICY.md (host before listing), PLAY_DATA_SAFETY.md
  (code-evidence answers), dead cloud-upload switch replaced with a
  static offline-only notice.

## Verification

- `flutter analyze`: clean. `flutter test`: 495/495.
- `osv-scanner` lockfile gate: 114 packages, no issues.
- Dex keep audit: ModuleDescriptor fields + ThickFaceDetectorCreator
  present. Bundled face asset + native face libs in artifact.

## Still open (need hardware)

- Rear/airplane/second-device proof runs on this build.
- Signed-upgrade install test (data preserved) on a real device.
- 16 KB page-size confirmation via Play Console on the uploaded bundle.
