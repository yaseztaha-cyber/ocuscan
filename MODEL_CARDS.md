# OcuScan Model Cards (v0.5)

One card per ML model actually used. Unknown fields say unknown — never
invented.

## ML Kit Face Detection (Google, on-device)

- **Version**: google_mlkit_face_detection 0.15.1 (Flutter plugin) wrapping
  `com.google.mlkit:face-detection:16.1.7` (bundled SDK model version
  undisclosed by vendor). `libface_detector_v2_jni.so` verified present in
  arm64-v8a, armeabi-v7a and x86_64 release ABIs.
- **Input**: YUV/NV21/BGRA frames with rotation metadata.
- **Output**: face bounding boxes, landmarks (eyes), eye-open
  classification, head euler angles, tracking IDs. Contours DISABLED
  (unused, latency cost).
- **Purpose in OcuScan**: face presence, geometry, eye localization
  inputs — never a finding by itself.
- **Training data**: proprietary, undisclosed (vendor).
- **Validation data**: none by OcuScan (engineering verification only).
- **Known limitations**: needs Play-services-capable Android for some
  devices; degrades in poor light/extreme pose; no pitch angle; may
  vary across populations (unevaluated — fairness tab reports
  "Not evaluated", never assumed equal).
- **Excluded populations**: none explicitly — unevaluated everywhere.
- **Hardware assumptions**: working camera + analysis stream; see
  device compatibility doc.
- **Failure modes**: no faces (logged per attempt), wrong rotation
  (computed + logged), corrupt layout (observed-layout construction).
- **Clinical status**: not a medical model; infrastructure only.

## Deterministic analyzers (12, `AnalyzerRegistry`)

Not ML models: fixed rules over measurements (see ALGORITHM_CARDS.md).
No training data, no learned weights. Versions pinned per result.

## No other models

No disease classifiers, no downloaded weights, no server inference.
Any future model requires a new card before use.
