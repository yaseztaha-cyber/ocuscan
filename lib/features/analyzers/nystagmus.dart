import 'dart:math';
import '../../core/models/screening_result.dart';
import '../../core/pipeline/analyzer.dart';
import '../../core/pipeline/quality_gate.dart';

// Module 12 — Nystagmus / involuntary eye movement screening.
// Looks for periodic oscillation in horizontal gaze series.
class NystagmusInput {
  final List<double> gazeX; // normalized gaze x per frame
  final double fps;
  final double trackingConfidence; // 0..1
  const NystagmusInput({required this.gazeX, required this.fps, required this.trackingConfidence});
}

class NystagmusAnalyzer extends Analyzer<NystagmusInput> {
  @override
  String get testName => 'Eye movement stability';

  @override
  ScreeningResult analyze(NystagmusInput i, QualityVerdict q) {
    final veto = lowQualityShortCircuit(testName, q, const [
      'Movement tracking needs a stable head and continuous gaze lock.',
    ]);
    if (veto != null) return veto;
    if (i.trackingConfidence < 0.55 || i.gazeX.length < (i.fps * 5).round()) {
      return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
        reason: 'Tracking confidence ${(i.trackingConfidence*100).toStringAsFixed(0)}% or clip too short for oscillation analysis.',
        limitations: const ['Stabilize the head, fixate on the target, and repeat.']);
    }
    // Detrend + zero-crossing frequency + amplitude.
    final n = i.gazeX.length;
    final mean = i.gazeX.reduce((a, b) => a + b) / n;
    final detrended = i.gazeX.map((v) => v - mean).toList();
    int crossings = 0;
    for (int k = 1; k < n; k++) {
      if ((detrended[k - 1] < 0 && detrended[k] >= 0) ||
          (detrended[k - 1] > 0 && detrended[k] <= 0)) {
        crossings++;
      }
    }
    final seconds = n / i.fps;
    final freqHz = crossings / 2 / seconds;
    double peak = 0;
    for (final v in detrended) { peak = max(peak, v.abs()); }
    // Periodic oscillation: 2..8 Hz with sustained amplitude.
    // Require multiple consecutive oscillation windows to be conservative.
    final sustained = _sustainedOscillation(detrended, i.fps);
    if (freqHz >= 2 && freqHz <= 8 && peak >= 0.03 && sustained) {
      return ScreeningResult(
        testName: testName,
        measurement: 'Oscillation ~${freqHz.toStringAsFixed(1)} Hz, amplitude ${peak.toStringAsFixed(3)}',
        measurementUnit: 'Hz', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.possibleFinding,
        findingLabel: 'Repetitive involuntary eye movement was observed during the test',
        possibleAssociations: const ['Multiple ocular or neurologic causes', 'Normal endpoint movement', 'Tracking artifact'],
        limitations: const ['This test cannot determine the cause.', 'Brief endpoint movement can resemble oscillation.'],
        recommendedAction: 'Repeat with the head stabilized. Consider professional evaluation if persistent or with dizziness, vision change, or imbalance.',
        whyFlagged: 'Sustained periodic gaze oscillation ~${freqHz.toStringAsFixed(1)} Hz over ${seconds.toStringAsFixed(1)}s exceeded conservative screening bounds.',
        timestamp: DateTime.now(), rawMetrics: {'freq_hz': freqHz, 'amplitude': peak});
    }
    if (freqHz < 0.5 && peak < 0.02) {
      return ScreeningResult(
        testName: testName, measurement: 'Stable fixation, drift ${peak.toStringAsFixed(3)}',
        measurementUnit: '', imageQuality: q.quality, confidence: Confidence.low,
        finding: ResultCategory.noObviousAbnormality,
        findingLabel: 'No obvious abnormality observed in this screening',
        possibleAssociations: const [],
        limitations: const ['Short-clip screening only; subtle movement may be missed.'],
        recommendedAction: 'No further action needed from this test.',
        whyFlagged: 'No sustained periodic oscillation in this clip.',
        timestamp: DateTime.now(), rawMetrics: {'freq_hz': freqHz, 'amplitude': peak});
    }
    return ScreeningResult.unable(testName: testName, imageQuality: q.quality,
      reason: 'Eye-movement pattern was indeterminate (freq ${freqHz.toStringAsFixed(2)} Hz, amplitude ${peak.toStringAsFixed(3)}). Confidence too low to call either way.',
      limitations: const ['Repeat with better fixation and head stability.']);
  }

  bool _sustainedOscillation(List<double> s, double fps) {
    // Split into 2s windows; need oscillation sign in ≥2 windows.
    final win = (fps * 2).round();
    if (s.length < win * 2) return false;
    int oscillating = 0;
    for (int start = 0; start + win <= s.length; start += win) {
      final seg = s.sublist(start, start + win);
      int c = 0;
      for (int k = 1; k < seg.length; k++) {
        if ((seg[k - 1] < 0 && seg[k] >= 0) || (seg[k - 1] > 0 && seg[k] <= 0)) c++;
      }
      final f = c / 2 / (win / fps);
      if (f >= 2 && f <= 8) oscillating++;
    }
    return oscillating >= 2;
  }
}
