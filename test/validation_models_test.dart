// Validation model tests: Experiment/Trial/ReferenceLabel/DeviceProfile
// map round-trips, status/failure codes, lighting levels, registry versions.

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/validation/analyzer_registry.dart';
import 'package:ocuscan/core/validation/experiment_models.dart';

Experiment _exp() => Experiment(
      id: 7,
      name: 'Pupil repeatability S1',
      testType: 'pupil',
      deviceLabel: 'Device A',
      camera: 'front',
      targetDistanceCm: 30,
      lightingLevel: 'controlled',
      lux: 320,
      headAngleDeg: 0,
      subjectId: 'R001',
      analyzerVersion: 'pupil v1',
      createdAt: DateTime.utc(2026, 9, 25, 12),
    );

void main() {
  group('Experiment', () {
    test('round-trips through Map', () {
      final back = Experiment.fromMap(_exp().toMap());
      expect(back.id, 7);
      expect(back.name, 'Pupil repeatability S1');
      expect(back.targetDistanceCm, 30.0);
      expect(back.lux, 320.0);
      expect(back.analyzerVersion, 'pupil v1');
    });

    test('anonymous identifiers are plain strings (no identity model)', () {
      final e = _exp();
      expect(e.subjectId, 'R001');
      expect(e.deviceLabel, 'Device A');
    });
  });

  group('Trial', () {
    test('round-trips through Map including snapshot + reference', () {
      final t = Trial(
        id: 3,
        experimentId: 7,
        timestamp: DateTime.utc(2026, 9, 25, 12, 1),
        inputQuality: 'high',
        value: 0.041,
        unit: 'index',
        measurementLabel: 'Relative asymmetry 4.1% over 5 frames',
        confidence: 'moderate',
        status: TrialStatus.accepted,
        referenceValue: 0.039,
        referenceMethod: 'manual caliper re-measure (documented)',
        lightingLevel: 'controlled',
        lux: 320,
        distanceCm: 30,
        headAngleDeg: 0,
        deviceLabel: 'Device A',
        subjectId: 'R001',
        testType: 'pupil',
        hasCapture: true,
        luminance: 120.5,
        sharpness: 88.2,
      );
      final back = Trial.fromMap(t.toMap());
      expect(back.id, 3);
      expect(back.value, closeTo(0.041, 1e-12));
      expect(back.status, TrialStatus.accepted);
      expect(back.referenceValue, closeTo(0.039, 1e-12));
      expect(back.hasCapture, true);
      expect(back.luminance, closeTo(120.5, 1e-9));
    });

    test('status codes cover accepted/rejected/unable', () {
      expect(TrialStatus.accepted.code, 'accepted');
      expect(TrialStatus.rejected.code, 'rejected');
      expect(TrialStatus.unable.code, 'unable');
      expect(TrialStatusX.fromCode('rejected'), TrialStatus.rejected);
      expect(TrialStatusX.fromCode('unable'), TrialStatus.unable);
      expect(TrialStatusX.fromCode('accepted'), TrialStatus.accepted);
    });

    test('failure codes cover the required taxonomy', () {
      const codes = [
        'LOW_ILLUMINATION',
        'OVEREXPOSURE',
        'BLUR',
        'LOW_RESOLUTION',
        'BAD_FACE_GEOMETRY',
        'EYE_NOT_VISIBLE',
        'OTHER',
      ];
      for (final c in codes) {
        expect(QualityFailureCodeX.fromCode(c).code, c);
      }
      expect(QualityFailureCodeX.fromCode('???'),
          QualityFailureCode.other);
    });

    test('lighting levels are the five steps plus controlled', () {
      expect(
          LightingLevels.all,
          containsAll([
            'very_low',
            'low',
            'moderate',
            'bright',
            'very_bright',
            'controlled',
          ]));
      expect(LightingLevels.isKnown('moderate'), true);
      expect(LightingLevels.isKnown('candlelight'), false);
    });
  });

  group('ReferenceLabel + DeviceProfile', () {
    test('reference label round-trips (interface only, no data bundled)', () {
      const l = ReferenceLabel(
        datasetId: 'none-yet',
        sampleId: 's-001',
        testType: 'pupil',
        referenceFinding: 'documented by researcher',
        referenceMethod: 'method on file',
        source: 'researcher notes',
      );
      final back = ReferenceLabel.fromMap(l.toMap());
      expect(back.datasetId, 'none-yet');
      expect(back.testType, 'pupil');
    });

    test('device profile round-trips with nullable instrument fields', () {
      const p = DeviceProfile(deviceLabel: 'Device B', model: 'X1');
      final back = DeviceProfile.fromMap(p.toMap());
      expect(back.deviceLabel, 'Device B');
      expect(back.manufacturer, isNull);
    });
  });

  group('AnalyzerRegistry', () {
    test('covers all 12 analyzers plus 7 vision tests', () {
      expect(AnalyzerRegistry.all.length, 19);
      for (final key in [
        'facial_asymmetry',
        'eyelid',
        'eye_alignment',
        'pupil',
        'pupil_response',
        'surface_growth',
        'redness',
        'scleral',
        'corneal',
        'lens',
        'blink',
        'nystagmus',
        'va_distance',
        'va_near',
        'color',
        'contrast',
        'amsler',
        'peripheral',
        'cover',
      ]) {
        expect(AnalyzerRegistry.forKey(key), isNotNull,
            reason: 'missing registry entry: $key');
      }
    });

    test('every entry documents input/output/version/limitations', () {
      for (final a in AnalyzerRegistry.all) {
        expect(a.input.isNotEmpty, true, reason: a.key);
        expect(a.output.isNotEmpty, true, reason: a.key);
        expect(a.version.isNotEmpty, true, reason: a.key);
        expect(a.qualityRequirements.isNotEmpty, true, reason: a.key);
        expect(a.failureConditions.isNotEmpty, true, reason: a.key);
        expect(a.knownLimitations.isNotEmpty, true, reason: a.key);
      }
    });

    test('experimental modules are explicitly flagged', () {
      expect(AnalyzerRegistry.forKey('lens')!.experimental, true);
      expect(AnalyzerRegistry.forKey('corneal')!.experimental, true);
      expect(
          AnalyzerRegistry.forKey('surface_growth')!.experimental, true);
      expect(
          AnalyzerRegistry.forKey('pupil_response')!.experimental, true);
      expect(AnalyzerRegistry.forKey('pupil')!.experimental, false);
      expect(AnalyzerRegistry.forKey('redness')!.experimental, false);
    });

    test('every camera analyzer declares modality requirements', () {
      for (final key in [
        'facial_asymmetry',
        'eyelid',
        'eye_alignment',
        'pupil',
        'pupil_response',
        'surface_growth',
        'redness',
        'scleral',
        'corneal',
        'lens',
        'blink',
        'nystagmus',
      ]) {
        final m = AnalyzerRegistry.modalityRequirements[key];
        expect(m, isNotNull, reason: key);
        for (final field in ['camera', 'eyes', 'temporal', 'source']) {
          expect(m![field]?.isNotEmpty, true,
              reason: '$key.$field');
        }
        expect(
            AnalyzerRegistry.requirementsFor(key).contains('undocumented'),
            false,
            reason: key);
      }
    });

    test('v1 analyzer testNames resolve to versions', () {
      expect(
          AnalyzerRegistry.versionForTestName('Pupil symmetry'), 'v1');
      expect(AnalyzerRegistry.keyForTestName('Eye redness'), 'redness');
    });
  });

  group('Cohen kappa (categorical agreement)', () {
    test('perfect agreement over 12 balanced pairs gives kappa 1', () {
      final a = [
        for (var i = 0; i < 4; i++) TrialStatus.accepted,
        for (var i = 0; i < 4; i++) TrialStatus.rejected,
        for (var i = 0; i < 4; i++) TrialStatus.unable,
      ];
      final b = List<TrialStatus>.of(a);
      final r = cohensKappa(a, b)!;
      expect(r.n, 12);
      expect(r.observedAgreement, closeTo(1.0, 1e-12));
      expect(r.expectedAgreement, closeTo(1 / 3, 1e-12));
      expect(r.kappa, closeTo(1.0, 1e-12));
      expect(r.degenerate, false);
      expect(r.insufficientData, false);
      expect(r.band, 'almost-perfect');
    });

    test('zero agreement gives negative kappa (poor)', () {
      final a = [
        for (var i = 0; i < 6; i++) TrialStatus.accepted,
        for (var i = 0; i < 6; i++) TrialStatus.rejected,
      ];
      final b = [
        for (var i = 0; i < 6; i++) TrialStatus.rejected,
        for (var i = 0; i < 6; i++) TrialStatus.accepted,
      ];
      final r = cohensKappa(a, b)!;
      expect(r.n, 12);
      expect(r.observedAgreement, closeTo(0.0, 1e-12));
      expect(r.expectedAgreement, closeTo(0.5, 1e-12));
      expect(r.kappa, closeTo(-1.0, 1e-12));
      expect(r.degenerate, false);
      expect(r.band, 'poor');
    });

    test('single-category data is degenerate (kappa undefined)', () {
      final a = List.filled(12, TrialStatus.accepted);
      final b = List.filled(12, TrialStatus.accepted);
      final r = cohensKappa(a, b)!;
      expect(r.n, 12);
      expect(r.observedAgreement, closeTo(1.0, 1e-12));
      expect(r.expectedAgreement, closeTo(1.0, 1e-12));
      expect(r.kappa.isNaN, true);
      expect(r.degenerate, true);
      expect(r.insufficientData, true);
      expect(r.band, 'insufficient-data');
    });

    test('fewer than 10 pairs is insufficient-data even when kappa is 1', () {
      final a = [
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.rejected,
        TrialStatus.rejected,
        TrialStatus.unable,
      ];
      final b = List<TrialStatus>.of(a);
      final r = cohensKappa(a, b)!;
      expect(r.n, 5);
      expect(r.kappa, closeTo(1.0, 1e-12));
      expect(r.insufficientData, true);
      expect(r.band, 'insufficient-data');
      expect(kappaBand(0.9, 9), 'insufficient-data');
    });

    test('partial agreement matches hand-computed Po/Pe/kappa', () {
      // Matrix AA=3 AR=1 AU=1 / RA=1 RR=2 RU=0 / UA=0 UR=1 UU=1.
      // Po=0.6, Pe=0.36, kappa=0.375 -> fair.
      final a = [
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.rejected,
        TrialStatus.rejected,
        TrialStatus.rejected,
        TrialStatus.unable,
        TrialStatus.unable,
      ];
      final b = [
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.rejected,
        TrialStatus.unable,
        TrialStatus.accepted,
        TrialStatus.rejected,
        TrialStatus.rejected,
        TrialStatus.rejected,
        TrialStatus.unable,
      ];
      final r = cohensKappa(a, b)!;
      expect(r.n, 10);
      expect(r.observedAgreement, closeTo(0.6, 1e-12));
      expect(r.expectedAgreement, closeTo(0.36, 1e-12));
      expect(r.kappa, closeTo(0.375, 1e-12));
      expect(r.degenerate, false);
      expect(r.insufficientData, false);
      expect(r.band, 'fair');
    });

    test('band thresholds follow Landis-Koch with guards', () {
      expect(minPairsForKappa, 10);
      expect(kappaBand(-0.5, 12), 'poor');
      expect(kappaBand(-0.01, 12), 'poor');
      expect(kappaBand(0.0, 12), 'slight');
      expect(kappaBand(0.20, 12), 'slight');
      expect(kappaBand(0.21, 12), 'fair');
      expect(kappaBand(0.40, 12), 'fair');
      expect(kappaBand(0.41, 12), 'moderate');
      expect(kappaBand(0.60, 12), 'moderate');
      expect(kappaBand(0.61, 12), 'substantial');
      expect(kappaBand(0.80, 12), 'substantial');
      expect(kappaBand(0.81, 12), 'almost-perfect');
      expect(kappaBand(1.0, 12), 'almost-perfect');
      expect(kappaBand(double.nan, 12), 'insufficient-data');
      expect(kappaBand(0.9, 12, degenerate: true), 'insufficient-data');
      expect(kappaBand(0.9, 9), 'insufficient-data');
    });

    test('empty input returns null; mismatched lengths throw', () {
      expect(cohensKappa([], []), isNull);
      expect(
          () => cohensKappa(
              [TrialStatus.accepted], [TrialStatus.accepted, TrialStatus.rejected]),
          throwsArgumentError);
    });
  });

  group('TrialStatusDistribution (observed outcome mix)', () {
    Trial trialWith(TrialStatus s) => Trial(
          experimentId: 7,
          timestamp: DateTime.utc(2026, 9, 25, 12),
          inputQuality: 'high',
          status: s,
        );

    test('counts and rates from raw statuses', () {
      final d = summarizeStatuses([
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.accepted,
        TrialStatus.rejected,
        TrialStatus.unable,
      ]);
      expect(d.total, 5);
      expect(d.accepted, 3);
      expect(d.rejected, 1);
      expect(d.unable, 1);
      expect(d.acceptedRate, closeTo(0.6, 1e-12));
      expect(d.rejectedRate, closeTo(0.2, 1e-12));
      expect(d.unableRateValue, closeTo(0.2, 1e-12));
    });

    test('summarizeTrialStatuses maps loaded trials honestly', () {
      final trials = [
        trialWith(TrialStatus.accepted),
        trialWith(TrialStatus.rejected),
        trialWith(TrialStatus.rejected),
        trialWith(TrialStatus.unable),
      ];
      final d = summarizeTrialStatuses(trials);
      expect(d.total, 4);
      expect(d.accepted, 1);
      expect(d.rejected, 2);
      expect(d.unable, 1);
      expect(d.acceptedRate, closeTo(0.25, 1e-12));
      expect(d.rejectedRate, closeTo(0.5, 1e-12));
      expect(d.unableRateValue, closeTo(0.25, 1e-12));
      expect(d.accepted + d.rejected + d.unable, d.total);
    });

    test('empty input yields zero counts and null rates', () {
      final d = summarizeTrialStatuses([]);
      expect(d.total, 0);
      expect(d.accepted, 0);
      expect(d.rejected, 0);
      expect(d.unable, 0);
      expect(d.acceptedRate, isNull);
      expect(d.rejectedRate, isNull);
      expect(d.unableRateValue, isNull);
    });
  });
}
