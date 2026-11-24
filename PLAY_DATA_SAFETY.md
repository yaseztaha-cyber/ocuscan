# Play Data Safety — OcuScan answers (code-evidence backed)

Fill the Play Console Data Safety form with these answers. Each row
names the code evidence; re-verify after ANY dependency change
(the `osv-scanner` gate in RELEASE_CHECKLIST.md runs alongside).

## Permissions declared by the release artifact

| Permission | Source | Why it is there |
|---|---|---|
| CAMERA | app manifest + camera_android_camerax | Core feature: on-device eye screening |
| INTERNET | transitive `datatransport` (ML Kit SDK telemetry) | App Dart code makes zero network calls; present via SDK |
| ACCESS_NETWORK_STATE | transitive media3/datatransport | SDK-level; unused by app code |
| DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION | androidx.core | SDK-level |
| RECORD_AUDIO | STRIPPED (`tools:node="remove"`) | Absent from release; mic never used |
| WRITE_EXTERNAL_STORAGE | STRIPPED (`tools:node="remove"`) | App uses app-private dirs only |
| READ_EXTERNAL_STORAGE | STRIPPED (`tools:node="remove"`, was transitively implied) | App reads app-private dirs, own assets, camera stream only |

## Questionnaire

| Play question | Answer | Evidence |
|---|---|---|
| Does your app collect or share any of the required user data types? | **No collection; no sharing by the app.** Camera frames are processed on-device and deleted by default; measurements/history/profiles live in on-device SQLite with `allowBackup=false`. Files (reports, CSV/JSON, error JSONs) leave only via the user-tapped system share sheet. | No `http`/firebase/analytics SDKs in `lib/`; `AndroidManifest.xml` (backup off, cleartext off); `data_extraction_rules.xml` excludes db/prefs/research; `settings_repository.dart` defaults (raw images OFF) |
| Location | **No** | No location permission; no geolocator |
| Camera | **Yes — processed on-device, not collected off-device** | `CAMERA` permission; `enableAudio: false`; frames never uploaded |
| Microphone | **No** | `RECORD_AUDIO` stripped, absent from release badging |
| Photos / videos | **Processed on-device, deleted by default; no upload** | Stills one-at-a-time + delete-on-dispose; research captures OFF + acknowledged |
| Health info | **Stored on-device only; no transmission** | `app_database.dart`; user-directed share only; report has no copy button |
| Is all user data encrypted in transit? | **Yes (nothing transmitted by the app; cleartext disabled)** | `usesCleartextTraffic=false`; no app network calls |
| Can users request data deletion? | **Yes** | In-app Delete-all (`history_repository.dart`), backup exclusion |
| Target audience / children | General audience; supervised use by children (see privacy policy) | No age gate; no ads; no analytics |

## Reviewer notes to attach

- `cloudUpload`-style dead switches: none (the toggle is a static
  offline-only notice; no switch promises an upload that cannot happen).
- ML Kit `datatransport` telemetry is Google's SDK-level behavior,
  not app collection; declared here for transparency.
- Privacy policy URL: host PRIVACY_POLICY.md and link it.
