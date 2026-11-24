import 'dart:math';
import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 11 — Blink analysis over short video.
class BlinkInput {
  final List<double> openness; // per-frame eye openness 0..1
  final double fps;
  final List<String> symptoms; // e.g. dryness, burning
  const BlinkInput({required this.openness, required this.fps, this.symptoms = const []});
}

class BlinkAnalyzer extends Analyzer<BlinkInput> {
  @override
  String get testName => 'Blink pattern';

  @override
  ScreeningResult analyze(BlinkInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Blink tracking needs a stable frontal video of both eyes.',
    ]);
    if (veto != null) return veto;
    if (i.openness.length < (i.fps * 5).round()) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Video too short for blink measurement (need ≥5s).',
        limitations: const ['Record a steady 10s clip looking at the camera.']);
    }
    int blinks = 0; int incomplete = 0;
    bool inBlink = false; double minOpen = 1;
    for (final o in i.openness) {
      if (!inBlink && o < 0.35) { inBlink = true; minOpen = o; }
      else if (inBlink) {
        minOpen = min(minOpen, o);
        if (o > 0.7) { inBlink = false; blinks++; if (minOpen > 0.12) incomplete++; }
      }
    }
    final minutes = i.openness.length / i.fps / 60.0;
    final rate = minutes > 0 ? blinks / minutes : 0.0;
    final incompleteFrac = blinks == 0 ? 0.0 : incomplete / blinks;
    final unusual = rate < 5 || rate > 30 || incompleteFrac > 0.5;
    if (unusual) {
      return ScreeningResult(
        testName: testName,
        measurement: '${rate.toStringAsFixed(1)} blinks/min, ${(incompleteFrac*100).toStringAsFixed(0)}% incomplete',
        measurementUnit: 'blinks/min', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'An unusual blinking pattern was observed',
        possibleAssociations: const ['Dryness', 'Fatigue', 'Screen use', 'Normal variation'],
        limitations: const ['Cannot diagnose dry-eye disease from blinking alone.', 'Consider reported symptoms alongside this measurement.'],
        recommendedAction: 'Repeat when rested. Consider professional evaluation for persistent discomfort, burning, or fluctuating vision. Symptoms noted: ${"none"}.',
        whyFlagged: '$blinks blinks in ${(i.openness.length / i.fps).toStringAsFixed(1)}s ($rate/min) with ${(incompleteFrac*100).toStringAsFixed(0)}% incomplete; outside 5–30/min or >50% incomplete screening bounds.',
        timestamp: DateTime.now(), rawMetrics: {'rate': rate.toDouble(), 'incomplete_frac': incompleteFrac});
    }
    return ScreeningResult(
      testName: testName,
      measurement: '${rate.toStringAsFixed(1)} blinks/min, ${(incompleteFrac*100).toStringAsFixed(0)}% incomplete',
      measurementUnit: 'blinks/min', imageQuality: q.quality, confidence: Confidence.low,
      finding: ResultCategory.noObviousAbnormality,
      findingLabel: 'No obvious abnormality observed in this screening',
      possibleAssociations: const [],
      limitations: const ['Short-clip screening only.'],
      recommendedAction: 'No further action needed from this test.',
      whyFlagged: 'Blink rate and completeness within screening bounds.',
      timestamp: DateTime.now(), rawMetrics: {'rate': rate.toDouble(), 'incomplete_frac': incompleteFrac});
  }
}
