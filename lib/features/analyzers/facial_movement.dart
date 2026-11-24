// Facial-movement detail (v0.7 §5/§7): per-expression amplitude plus
// inter-expression timing from timestamped samples. Pure measurement
// enrichment — the FINDING still comes from FacialAsymmetryAnalyzer
// thresholds; this module never diagnoses. Speed within a single hold
// is NOT measurable from instant samples and is explicitly not claimed;
// what IS measured: amplitude per region and the timing between
// performed expressions.
class ExpressionSample {
  final String key;

  /// Mean eye-openness amplitude for this expression hold.
  final double amplitude;

  /// Measured per-side amplitudes. Null means that side was not measured;
  /// callers must not synthesize the missing side.
  final double? leftAmplitude;
  final double? rightAmplitude;
  final double yawDeg;
  final DateTime at;
  const ExpressionSample({
    required this.key,
    required this.amplitude,
    required this.at,
    this.leftAmplitude,
    this.rightAmplitude,
    this.yawDeg = 0,
  });
}

class FacialMovementDetail {
  /// Ordered samples backing this detail line.
  final List<ExpressionSample> samples;

  /// Amplitude per sampled region key.
  final Map<String, double> amplitudes;

  /// Seconds between consecutive samples (ordered by time).
  final Map<String, double> gapsToNext;

  /// Total span seconds from first to last sample.
  final double spanSeconds;
  const FacialMovementDetail({
    required this.samples,
    required this.amplitudes,
    required this.gapsToNext,
    required this.spanSeconds,
  });

  List<ExpressionSample> get _samples => samples;

  /// One-line honest measurement appendix, e.g.
  /// "brow 12.4 (L 12.6/R 12.2); smile 11.9 @4s; ...".
  /// Sides appear only when both were actually measured.
  String get summary {
    if (_samples.isEmpty) return 'no samples';
    return _samples
        .map((s) {
          final sides = s.leftAmplitude != null && s.rightAmplitude != null
              ? ' (L ${s.leftAmplitude!.toStringAsFixed(1)}/'
                  'R ${s.rightAmplitude!.toStringAsFixed(1)})'
              : '';
          return '${s.key} ${s.amplitude.toStringAsFixed(1)}$sides';
        })
        .join('; ');
  }
}

class FacialMovementAnalyzer {
  const FacialMovementAnalyzer();

  FacialMovementDetail analyze(List<ExpressionSample> samples) {
    if (samples.isEmpty) {
      return const FacialMovementDetail(
          samples: [], amplitudes: {}, gapsToNext: {}, spanSeconds: 0);
    }
    final ordered = List<ExpressionSample>.of(samples)
      ..sort((a, b) => a.at.compareTo(b.at));
    final amps = {for (final s in ordered) s.key: s.amplitude};
    final gaps = <String, double>{};
    for (var i = 0; i < ordered.length - 1; i++) {
      gaps['${ordered[i].key}->${ordered[i + 1].key}'] =
          ordered[i + 1].at.difference(ordered[i].at).inMilliseconds /
              1000.0;
    }
    final span = ordered.length < 2
        ? 0.0
        : ordered.last.at.difference(ordered.first.at).inMilliseconds /
            1000.0;
    return FacialMovementDetail(
        samples: ordered,
        amplitudes: amps,
        gapsToNext: gaps,
        spanSeconds: span);
  }
}
