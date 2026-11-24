# OcuScan Release Checklist (v0.5) — pre-release gate

An APK is release-ready only when ALL boxes check. Physical-device
checks are reported separately and never converted to PASS.

- [ ] `flutter analyze` — No issues found
- [ ] `flutter test` — full suite green, 0 regressions
- [ ] No banned medical wording (`validation_misc_test` scan green,
      incl. hospital/clinical-grade claims)
- [ ] Evidence coverage intact (linkage + counts tests green)
- [ ] No mock medical outputs (privacy/no-mock grep audit clean)
- [ ] No unresolved P0/P1 bugs (audit matrix)
- [ ] APK generated + `aapt` badging verified (id, version, versionCode)
- [ ] App Bundle generated + signed (`app-release.aab`, `jarsigner -verify`,
      contents: base manifest, per-ABI face libs, bundled asset, icons)
- [ ] Release built with Dart obfuscation:
      `flutter build apk --release --obfuscate
      --split-debug-info=build/app/outputs/symbols`
      (symbols retained per release for stack-trace de-obfuscation;
      R8 mapping.txt retained alongside)
- [ ] `flutter pub get` advisory pass clean (no GitHub Advisory hits)
- [ ] `osv-scanner scan --lockfile=pubspec.lock` — No issues found
      (114 packages at last scan; re-run after ANY dependency change;
      every `ignored_advisories` entry carries its justification
      comment in pubspec.yaml — currently zero suppressions)
- [ ] Physical-device checks reported separately (TEST 1–8 + condition
      matrix), never assumed from unit tests

## Signing, upgrade & rollback gate (P8)

- [x] Release signed with the REAL keystore (never debug keys for a
      distributed build); keystore + passwords stored outside the repo
      (`android/ocuscan-release.keystore` + gitignored `key.properties`;
      BACK UP the keystore offline — losing it strands upgrades)
- [ ] `versionCode` bumped vs the previous release (downgrade installs
      are rejected by Android — a repeated code strands users)
- [ ] Per-ABI `aapt dump badging` verified when splits are enabled
- [ ] Signed-upgrade install tested on a real device (data preserved:
      sqflite DB migrates vN → vN+1, history/profiles intact)
- [ ] Rollback plan recorded (previous signed APK retained; downgrade
      requires reinstall + data loss, stated in release notes)

## R8 / native-model gate (P8 — regressions here re-break face detection)

- [ ] `build/app/outputs/mapping/release/mapping.txt` exists (R8 ran)
- [ ] Dex audit proves the keeps survived: `MODULE_ID` +
      `MODULE_VERSION` fields on the Dynamite `ModuleDescriptor`,
      `ThickFaceDetectorCreator.newFaceDetector`, registrar
      `getComponents` (see AUDIT_MATRIX R8-keep rows for the method)
- [ ] Bundled model assets present in APK (`models_bundled/`,
      `libface_detector_v2_jni.so` per ABI)
- [ ] AGP/R8/plugin version bumps re-run this whole gate from scratch

## Database migration gate (P8)

- [ ] `AppDatabase.version` bumped iff schema changed; `onUpgrade`
      covers every oldV < newV step; fresh-install schema matches
- [ ] Old rows read back with safe defaults (never backfilled meaning);
      trend comparisons against migrated rows stay fail-closed
