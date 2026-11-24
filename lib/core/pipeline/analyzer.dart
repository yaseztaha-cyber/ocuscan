// Base analyzer contract. Each module independently returns
// measurement + quality + confidence + finding + limitations.
// No module may emit a disease diagnosis.

import '../models/screening_result.dart';
import 'quality_gate.dart';

abstract class Analyzer<I> {
  String get testName;

  /// Algorithm version recorded with every validation experiment.
  /// See AnalyzerRegistry for the documented version per module.
  String get version => 'v1';

  ScreeningResult analyze(I input, QualityVerdict quality);
}

/// Shared helper: LOW quality short-circuits to Unable-to-assess.
ScreeningResult? lowQualityShortCircuit(
  String testName,
  QualityVerdict quality,
  List<String> limitations,
) {
  if (quality.quality == ImageQuality.low) {
    return ScreeningResult.unable(
      testName: testName,
      imageQuality: ImageQuality.low,
      reason:
          'Image quality was too low for a reliable measurement. ${QualityGate.lowQualityMessage}',
      limitations: limitations,
    );
  }
  return null;
}
