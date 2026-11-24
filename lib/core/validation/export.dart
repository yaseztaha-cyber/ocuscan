// Research data export (v0.2): CSV + JSON builders and file helpers.
//
// Exports carry RESEARCH MEASUREMENTS ONLY. Raw images are never exported:
// trials store a hasCapture flag, never a file path, and the builders below
// have no image column at all.

import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../evidence/evidence_repository.dart' show AppInfo;
import '../pipeline/quality_gate.dart';
import 'validation_repository.dart';

/// CSV columns, exactly as documented in VALIDATION.md.
/// v2 adds the previously dropped quality/fairness/conditions columns.
const List<String> exportCsvHeader = [
  'experiment_id',
  'experiment_name',
  'trial_id',
  'test_type',
  'analyzer_version',
  'device',
  'camera',
  'timestamp',
  'subject_id',
  'lighting',
  'lux',
  'distance_cm',
  'head_angle',
  'quality',
  'confidence',
  'measurement',
  'unit',
  'measurement_label',
  'status',
  'failure_reason',
  'reference_value',
  'reference_method',
  'notes',
  'luminance',
  'sharpness',
  'exposure_bad_fraction',
  'screen_brightness',
  'skin_tone',
  'eye_color',
  'eyewear',
  'age_group',
  'environmental_notes',
  'operator_notes',
];

String _csvCell(String v) {
  if (v.contains(',') || v.contains('"') || v.contains('\n')) {
    return '"${v.replaceAll('"', '""')}"';
  }
  return v;
}

/// Build CSV text from export rows. Pure function — unit-tested.
String trialsToCsv(List<TrialExportRow> rows) {
  final sb = StringBuffer();
  sb.writeln(exportCsvHeader.join(','));
  for (final r in rows) {
    sb.writeln([
      r.experimentId.toString(),
      r.experimentName,
      r.trialId.toString(),
      r.testType,
      r.analyzerVersion,
      r.deviceLabel,
      r.camera,
      r.timestamp,
      r.subjectId,
      r.lightingLevel,
      r.lux,
      r.distanceCm,
      r.headAngleDeg,
      r.inputQuality,
      r.confidence,
      r.value,
      r.unit,
      r.measurementLabel,
      r.status,
      r.failureReason,
      r.referenceValue,
      r.referenceMethod,
      r.notes,
      r.luminance,
      r.sharpness,
      r.exposureBadFraction,
      r.screenBrightness,
      r.skinTone,
      r.eyeColor,
      r.eyewear,
      r.ageGroup,
      r.environmentalNotes,
      r.operatorNotes,
    ].map(_csvCell).join(','));
  }
  return sb.toString();
}

/// Build JSON text from export rows. Pure function — unit-tested.
/// The envelope records app + evidence-DB versions for reproducibility.
/// v2 adds the dropped quality/fairness/conditions columns plus a
/// reproducibility sidecar (R8: catalog version + quality-gate
/// thresholds + tracker needs, so a re-analyst can reconstruct the
/// calibration context per VALIDATION.md §8).
String trialsToJson(List<TrialExportRow> rows,
    {String? generatedBy,
    String ocuscanVersion = AppInfo.ocuscanVersion,
    String evidenceDbVersion = AppInfo.evidenceDbVersion,
    String detectionCatalogVersion = '0.7'}) {
  final doc = {
    'format': 'ocuscan-research-export',
    'version': 2,
    'ocuscan_version': ocuscanVersion,
    'analyzer_versions': 'per-trial analyzer_version column',
    'evidence_db_version': evidenceDbVersion,
    'detection_catalog_version': detectionCatalogVersion,
    'quality_gate_thresholds': {
      'min_sharpness': QualityGate.minSharpness,
      'low_sharpness': QualityGate.lowSharpness,
      'min_luminance': QualityGate.minLuminance,
      'max_luminance': QualityGate.maxLuminance,
      'max_bad_exposure_fraction': QualityGate.maxBadExposureFraction,
      'min_dimension': QualityGate.minDimension,
    },
    'notice':
        'Research measurements only. No images, no identity. See VALIDATION.md for schema.',
    ...? generatedBy == null ? null : {'generatedBy': generatedBy},
    'exportedAt': DateTime.now().toIso8601String(),
    'trials': [
      for (final r in rows)
        {
          'experiment_id': r.experimentId,
          'experiment_name': r.experimentName,
          'trial_id': r.trialId,
          'test_type': r.testType,
          'analyzer_version': r.analyzerVersion,
          'device': r.deviceLabel,
          'camera': r.camera,
          'timestamp': r.timestamp,
          'subject_id': r.subjectId,
          'lighting': r.lightingLevel,
          'lux': r.lux,
          'distance_cm': r.distanceCm,
          'head_angle': r.headAngleDeg,
          'quality': r.inputQuality,
          'confidence': r.confidence,
          'measurement': r.value,
          'unit': r.unit,
          'measurement_label': r.measurementLabel,
          'status': r.status,
          'failure_reason': r.failureReason,
          'reference_value': r.referenceValue,
          'reference_method': r.referenceMethod,
          'notes': r.notes,
          'luminance': r.luminance,
          'sharpness': r.sharpness,
          'exposure_bad_fraction': r.exposureBadFraction,
          'screen_brightness': r.screenBrightness,
          'skin_tone': r.skinTone,
          'eye_color': r.eyeColor,
          'eyewear': r.eyewear,
          'age_group': r.ageGroup,
          'environmental_notes': r.environmentalNotes,
          'operator_notes': r.operatorNotes,
        }
    ],
  };
  return const JsonEncoder.withIndent('  ').convert(doc);
}

/// Write export text to the app documents directory. Returns the file path.
/// Filenames carry a timestamp; content is measurements only.
Future<String> writeExportFile(String content, String ext,
    {String prefix = 'ocuscan_research'}) async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/research_exports');
  await dir.create(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('${dir.path}/${prefix}_$stamp.$ext');
  await file.writeAsString(content, flush: true);
  return file.path;
}

/// Share an exported file via the platform share sheet.
Future<void> shareExportFile(String path) async {
  await SharePlus.instance.share(ShareParams(
    files: [XFile(path)],
    text: 'OcuScan research measurements (no images, no identity).',
  ));
}

/// Base directory for local research captures (app documents).
Future<String> researchBaseDir() async {
  final docs = await getApplicationDocumentsDirectory();
  return docs.path;
}
