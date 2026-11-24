// Facial-movement detail tests: amplitude mapping, inter-expression
// timing, span, honesty on empty input. The finding logic lives in
// FacialAsymmetryAnalyzer (tested elsewhere); this module only enriches
// measurement text and never diagnoses.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/analyzers/facial_movement.dart';

void main() {
  group('FacialMovementAnalyzer', () {
    test('empty input reports no samples honestly', () {
      final d = const FacialMovementAnalyzer().analyze([]);
      expect(d.amplitudes, isEmpty);
      expect(d.spanSeconds, 0);
      expect(d.summary, 'no samples');
    });

    test('amplitudes map per region', () {
      final t = DateTime.utc(2026, 1, 1);
      final d = const FacialMovementAnalyzer().analyze([
        ExpressionSample(key: 'brow', amplitude: 12.4, at: t),
        ExpressionSample(key: 'smile', amplitude: 11.9, at: t),
      ]);
      expect(d.amplitudes['brow'], closeTo(12.4, 1e-9));
      expect(d.amplitudes['smile'], closeTo(11.9, 1e-9));
    });

    test('inter-expression gaps measured in seconds', () {
      final t = DateTime.utc(2026, 1, 1);
      final d = const FacialMovementAnalyzer().analyze([
        ExpressionSample(key: 'brow', amplitude: 10, at: t),
        ExpressionSample(
            key: 'smile',
            amplitude: 10,
            at: t.add(const Duration(seconds: 4))),
        ExpressionSample(
            key: 'cheek',
            amplitude: 10,
            at: t.add(const Duration(seconds: 9))),
      ]);
      expect(d.gapsToNext['brow->smile'], closeTo(4.0, 1e-9));
      expect(d.gapsToNext['smile->cheek'], closeTo(5.0, 1e-9));
      expect(d.spanSeconds, closeTo(9.0, 1e-9));
    });

    test('out-of-order samples sorted by time', () {
      final t = DateTime.utc(2026, 1, 1);
      final d = const FacialMovementAnalyzer().analyze([
        ExpressionSample(
            key: 'smile', amplitude: 1, at: t.add(const Duration(seconds: 5))),
        ExpressionSample(key: 'brow', amplitude: 2, at: t),
      ]);
      expect(d.spanSeconds, closeTo(5.0, 1e-9));
      expect(d.gapsToNext.keys.first, 'brow->smile');
    });

    test('summary lists amplitudes', () {
      final t = DateTime.utc(2026, 1, 1);
      final d = const FacialMovementAnalyzer().analyze([
        ExpressionSample(key: 'brow', amplitude: 12.4, at: t),
      ]);
      expect(d.summary, contains('brow 12.4'));
    });
    test('summary shows actually measured sides only', () {
      final t = DateTime.utc(2026, 1, 1);
      final d = const FacialMovementAnalyzer().analyze([
        ExpressionSample(
            key: 'smile',
            amplitude: 12.0,
            leftAmplitude: 12.4,
            rightAmplitude: 11.6,
            at: t),
      ]);
      expect(d.summary, contains('L 12.4/R 11.6'));
    });
  });
}
