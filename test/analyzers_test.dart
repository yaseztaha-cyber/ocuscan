import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/core/pipeline/quality_gate.dart';
import 'package:ocuscan/core/utils/image_utils.dart';
import 'package:ocuscan/features/analyzers/facial_asymmetry.dart';
import 'package:ocuscan/features/analyzers/eyelid.dart';
import 'package:ocuscan/features/analyzers/eye_alignment.dart';
import 'package:ocuscan/features/analyzers/pupil.dart';
import 'package:ocuscan/features/analyzers/pupil_response.dart';
import 'package:ocuscan/features/analyzers/redness.dart';
import 'package:ocuscan/features/analyzers/scleral.dart';
import 'package:ocuscan/features/analyzers/corneal.dart';
import 'package:ocuscan/features/analyzers/lens.dart';
import 'package:ocuscan/features/analyzers/blink.dart';
import 'package:ocuscan/features/analyzers/nystagmus.dart';
import 'package:ocuscan/features/analyzers/surface_growth.dart';

QualityVerdict highQ() => const QualityVerdict(quality: ImageQuality.high, score: 95, issues: [], guidance: []);
QualityVerdict lowQ() => const QualityVerdict(quality: ImageQuality.low, score: 20, issues: ['blur'], guidance: ['hold still']);

void main() {
  group('Analyzers respect LOW quality veto', () {
    test('facial asymmetry veto', () {
      final r = FacialAsymmetryAnalyzer().analyze(const FacialAsymmetryInput(
        leftBrow: 20, rightBrow: 5, leftLid: 20, rightLid: 5,
        leftMouth: 20, rightMouth: 5, leftCheek: 20, rightCheek: 5), lowQ());
      expect(r.finding, ResultCategory.unableToAssess);
    });
    test('pupil veto', () {
      final r = PupilAnalyzer().analyze(PupilInput(
        frames: List.generate(5, (_) => const PupilFrame(leftArea: 100, rightArea: 100)),
        lightingStable: true), lowQ());
      expect(r.finding, ResultCategory.unableToAssess);
    });
    test('redness veto + scleral calibration gate', () {
      final r = RednessAnalyzer().analyze(const RednessInput(
        leftRedness: 0.6, rightRedness: 0.6, rednessSpread: 0.9, whiteBalanceConfidence: 0.9), lowQ());
      expect(r.finding, ResultCategory.unableToAssess);
      final s = ScleralAnalyzer().analyze(const ScleralInput(
        yellowness: 0.5, calibrationPassed: false, warmLight: false,
        coloredLight: false, calibrationConfidence: 0.2), highQ());
      expect(s.finding, ResultCategory.unableToAssess);
      expect(s.findingLabel.contains('Unable'), true);
    });
  });

  group('Detection paths (no diagnosis language)', () {
    test('facial asymmetry flags large bilateral difference', () {
      final r = FacialAsymmetryAnalyzer().analyze(const FacialAsymmetryInput(
        leftBrow: 20, rightBrow: 8, leftLid: 20, rightLid: 9,
        leftMouth: 22, rightMouth: 9, leftCheek: 18, rightCheek: 8), highQ());
      expect(r.finding, ResultCategory.possibleFinding);
      expect(r.findingLabel, contains('Possible'));
      expect(r.recommendedAction.isNotEmpty, true);
    });
    test('symmetric face passes', () {
      final r = FacialAsymmetryAnalyzer().analyze(const FacialAsymmetryInput(
        leftBrow: 15, rightBrow: 15, leftLid: 18, rightLid: 18,
        leftMouth: 18, rightMouth: 18, leftCheek: 12, rightCheek: 12), highQ());
      expect(r.finding, ResultCategory.noObviousAbnormality);
    });
    test('eyelid flags 20%+', () {
      final r = EyelidAnalyzer().analyze(const EyelidInput(leftOpenness: 0.96, rightOpenness: 0.64), highQ());
      expect(r.finding, ResultCategory.possibleFinding);
    });
    test('eyelid refuses unknown or closed eyes', () {
      final unknown = EyelidAnalyzer().analyze(const EyelidInput(leftOpenness: -1, rightOpenness: 0.9), highQ());
      final closed = EyelidAnalyzer().analyze(const EyelidInput(leftOpenness: 0.1, rightOpenness: 0.9), highQ());
      expect(unknown.finding, ResultCategory.unableToAssess);
      expect(closed.finding, ResultCategory.unableToAssess);
    });
    test('alignment flags cover shift', () {
      final r = EyeAlignmentAnalyzer().analyze(const EyeAlignmentInput(
        leftGazeX: 0.3, rightGazeX: 0.0, leftGazeY: 0, rightGazeY: 0,
        coverDeltaLeft: 8, coverDeltaRight: 1, ipdPx: 100), highQ());
      expect(r.finding, ResultCategory.possibleFinding);
      expect(r.findingLabel.toLowerCase(), isNot(contains('strabismus')));
    });
    test('pupil uses multi-frame mean + rejects unstable light', () {
      final unstable = PupilAnalyzer().analyze(PupilInput(
        frames: List.generate(5, (_) => const PupilFrame(leftArea: 120, rightArea: 80)),
        lightingStable: false), highQ());
      expect(unstable.finding, ResultCategory.unableToAssess);
      final flagged = PupilAnalyzer().analyze(PupilInput(
        frames: List.generate(5, (_) => const PupilFrame(leftArea: 130, rightArea: 80)),
        lightingStable: true), highQ());
      expect(flagged.finding, ResultCategory.possibleFinding);
      expect(flagged.measurementUnit, isNot(contains('mm')));
    });
    test('pupil response disabled safely', () {
      final r = PupilResponseAnalyzer().analyze(
        const PupilResponseInput(hardwareSupportsSafeTest: false, leftSeries: [], rightSeries: []), highQ());
      expect(r.finding, ResultCategory.unableToAssess);
    });
    test('redness does not name a cause', () {
      final r = RednessAnalyzer().analyze(const RednessInput(
        leftRedness: 0.5, rightRedness: 0.5, rednessSpread: 0.5, whiteBalanceConfidence: 0.9), highQ());
      expect(r.finding, ResultCategory.possibleFinding);
      expect(r.findingLabel.toLowerCase(), isNot(contains('infection')));
      expect(r.limitations.join().toLowerCase(), contains('cannot'));
    });
    test('corneal + lens conservative', () {
      final c = CornealAnalyzer().analyze(const CornealInput(opacityScore: 0.1, confidence: 0.8), highQ());
      expect(c.finding, ResultCategory.noObviousAbnormality);
      final l = LensAnalyzer().analyze(const LensInput(opacityScore: 0.9, captureSupport: 0.1, closeUpMethod: false), highQ());
      expect(l.finding, ResultCategory.unableToAssess);
    });
    test('blink + nystagmus behavior', () {
      // Realistic 10 s clip at 20 fps with 3 full blinks (~18/min, complete).
      List<double> blinkSeries() {
        final s = List<double>.filled(200, 0.9);
        for (final start in [30, 90, 150]) {
          for (int k = 0; k < 6; k++) {
            s[start + k] = k < 3 ? 0.9 - (k + 1) * 0.28 : 0.06 + (k - 2) * 0.28;
          }
        }
        return s;
      }
      final b = BlinkAnalyzer().analyze(BlinkInput(openness: blinkSeries(), fps: 20), highQ());
      expect(b.finding, ResultCategory.noObviousAbnormality);
      final n = NystagmusAnalyzer().analyze(
        NystagmusInput(gazeX: List<double>.filled(200, 0.0), fps: 20, trackingConfidence: 0.9), highQ());
      expect(n.finding, ResultCategory.noObviousAbnormality);
      final nLow = NystagmusAnalyzer().analyze(
        NystagmusInput(gazeX: List<double>.filled(200, 0.0), fps: 20, trackingConfidence: 0.2), highQ());
      expect(nLow.finding, ResultCategory.unableToAssess);
    });
    test('surface growth needs confidence', () {
      final r = SurfaceGrowthAnalyzer().analyze(const SurfaceGrowthInput(
        nasalVesselDensity: 0.9, temporalVesselDensity: 0.9, triangularity: 0.9,
        cornealEncroachmentFrac: 0.5, segmentationConfidence: 0.2), highQ());
      expect(r.finding, ResultCategory.unableToAssess);
    });
  });

  test('asymmetry helper matches spec formula', () {
    expect(ImageUtils.asymmetryIndex(120, 80), closeTo(0.4, 1e-9));
  });

  group('eyelid gaze-pitch gate (no false confidence when tilted)', () {
    test('tilted pitch refuses measurement as unable-to-assess', () {
      final r = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: 20),
          highQ());
      expect(r.finding, ResultCategory.unableToAssess);
      expect(r.whyFlagged.toLowerCase(), contains('pitch'));
      final neg = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: -18),
          highQ());
      expect(neg.finding, ResultCategory.unableToAssess);
    });

    test('boundary |pitch| == 15 passes through to normal verdict', () {
      final pos = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: 15),
          highQ());
      expect(pos.finding, ResultCategory.noObviousAbnormality);
      final neg = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: -15),
          highQ());
      expect(neg.finding, ResultCategory.noObviousAbnormality);
      final justOver = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: 15.1),
          highQ());
      expect(justOver.finding, ResultCategory.unableToAssess);
    });

    test('unknown pitch (default 0 / NaN) passes through unchanged', () {
      final def = EyelidAnalyzer().analyze(
          const EyelidInput(leftOpenness: 0.9, rightOpenness: 0.9), highQ());
      expect(def.finding, ResultCategory.noObviousAbnormality);
      final explicitZero = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9, rightOpenness: 0.9, gazePitchDeg: 0),
          highQ());
      expect(explicitZero.finding, ResultCategory.noObviousAbnormality);
      final nan = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.9,
              rightOpenness: 0.9,
              gazePitchDeg: double.nan),
          highQ());
      expect(nan.finding, ResultCategory.noObviousAbnormality);
    });

    test('probability contract unchanged under frontal pitch', () {
      // 20% threshold still flags when pitch is frontal/unknown.
      final flagged = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.96,
              rightOpenness: 0.64,
              gazePitchDeg: 5),
          highQ());
      expect(flagged.finding, ResultCategory.possibleFinding);
      // Closed/unknown eyes still refuse even with good pitch.
      final closed = EyelidAnalyzer().analyze(
          const EyelidInput(
              leftOpenness: 0.1, rightOpenness: 0.9, gazePitchDeg: 0),
          highQ());
      expect(closed.finding, ResultCategory.unableToAssess);
    });
  });

  group('analyzer decision branches (synthetic inputs)', () {
    test('scleral flags, holds borderline warm, clears low', () {
      const goodCal = ScleralInput(
          yellowness: 0.25,
          calibrationPassed: true,
          warmLight: false,
          coloredLight: false,
          calibrationConfidence: 0.8);
      final flag = ScleralAnalyzer().analyze(goodCal, highQ());
      expect(flag.finding, ResultCategory.possibleFinding);
      expect(flag.measurement, 'Yellowness index 0.250');
      const borderline = ScleralInput(
          yellowness: 0.2,
          calibrationPassed: true,
          warmLight: true,
          coloredLight: false,
          calibrationConfidence: 0.8);
      expect(ScleralAnalyzer().analyze(borderline, highQ()).finding,
          ResultCategory.unableToAssess);
      const clear = ScleralInput(
          yellowness: 0.1,
          calibrationPassed: true,
          warmLight: false,
          coloredLight: false,
          calibrationConfidence: 0.9);
      final ok = ScleralAnalyzer().analyze(clear, highQ());
      expect(ok.finding, ResultCategory.noObviousAbnormality);
      expect(ok.measurement, 'Yellowness index 0.100');
    });
    test('scleral low quality short-circuits', () {
      const i = ScleralInput(
          yellowness: 0.9,
          calibrationPassed: true,
          warmLight: false,
          coloredLight: false,
          calibrationConfidence: 1.0);
      expect(ScleralAnalyzer().analyze(i, lowQ()).finding,
          ResultCategory.unableToAssess);
    });
    test('lens gates method/support, flags high opacity', () {
      expect(
          LensAnalyzer()
              .analyze(
                  const LensInput(
                      opacityScore: 0.9,
                      captureSupport: 0.9,
                      closeUpMethod: false),
                  highQ())
              .finding,
          ResultCategory.unableToAssess);
      expect(
          LensAnalyzer()
              .analyze(
                  const LensInput(
                      opacityScore: 0.9,
                      captureSupport: 0.5,
                      closeUpMethod: true),
                  highQ())
              .finding,
          ResultCategory.unableToAssess);
      final flag = LensAnalyzer().analyze(
          const LensInput(
              opacityScore: 0.8, captureSupport: 0.8, closeUpMethod: true),
          highQ());
      expect(flag.finding, ResultCategory.possibleFinding);
      expect(flag.measurement, 'Opacity cue 80% (experimental)');
      final clear = LensAnalyzer().analyze(
          const LensInput(
              opacityScore: 0.3, captureSupport: 0.9, closeUpMethod: true),
          highQ());
      expect(clear.finding, ResultCategory.noObviousAbnormality);
    });
    test('surface growth needs vascular+shape, clears below', () {
      const flagIn = SurfaceGrowthInput(
          nasalVesselDensity: 0.6,
          temporalVesselDensity: 0.2,
          triangularity: 0.7,
          cornealEncroachmentFrac: 0.1,
          segmentationConfidence: 0.9);
      final flag = SurfaceGrowthAnalyzer().analyze(flagIn, highQ());
      expect(flag.finding, ResultCategory.possibleFinding);
      expect(flag.measurement,
          'Vascular density 60%, encroachment 10.0%');
      const clearIn = SurfaceGrowthInput(
          nasalVesselDensity: 0.1,
          temporalVesselDensity: 0.1,
          triangularity: 0.2,
          cornealEncroachmentFrac: 0.0,
          segmentationConfidence: 0.9);
      final clear = SurfaceGrowthAnalyzer().analyze(clearIn, highQ());
      expect(clear.finding, ResultCategory.noObviousAbnormality);
      expect(clear.measurement, 'No growth pattern above thresholds');
      const weakSeg = SurfaceGrowthInput(
          nasalVesselDensity: 0.9,
          temporalVesselDensity: 0.9,
          triangularity: 0.9,
          cornealEncroachmentFrac: 0.5,
          segmentationConfidence: 0.3);
      final weak = SurfaceGrowthAnalyzer().analyze(weakSeg, highQ());
      expect(weak.finding, ResultCategory.unableToAssess);
      expect(weak.measurement, 'not measured');
    });
    test('pupil response asymmetry flags, symmetry clears', () {
      PupilResponseInput asym(bool hw) => PupilResponseInput(
            hardwareSupportsSafeTest: hw,
            leftSeries: const [
              1.0, 1.0, 1.0, 1.0, 1.0,
              0.9, 0.8, 0.7, 0.7, 0.7, 0.7, 0.7,
            ],
            rightSeries: const [
              1.0, 1.0, 1.0, 1.0, 1.0,
              1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,
            ],
          );
      final flag = PupilResponseAnalyzer().analyze(asym(true), highQ());
      expect(flag.finding, ResultCategory.possibleFinding);
      expect(flag.measurement,
          'Left constriction 30.0%, right 0.0%');
      final sym = PupilResponseAnalyzer().analyze(
          PupilResponseInput(
            hardwareSupportsSafeTest: true,
            leftSeries: const [
              1.0, 1.0, 1.0, 1.0, 1.0,
              0.9, 0.8, 0.7, 0.7, 0.7, 0.7, 0.7,
            ],
            rightSeries: const [
              1.0, 1.0, 1.0, 1.0, 1.0,
              0.9, 0.8, 0.7, 0.7, 0.7, 0.7, 0.7,
            ],
          ),
          highQ());
      expect(sym.finding, ResultCategory.noObviousAbnormality);
    });
    test('pupil response refuses short and flat series', () {
      const short = PupilResponseInput(
        hardwareSupportsSafeTest: true,
        leftSeries: [1.0, 1.0, 1.0, 1.0, 1.0],
        rightSeries: [1.0, 1.0, 1.0, 1.0, 1.0],
      );
      final s = PupilResponseAnalyzer().analyze(short, highQ());
      expect(s.finding, ResultCategory.unableToAssess);
      expect(s.measurement, 'not measured');
      const flat = PupilResponseInput(
        hardwareSupportsSafeTest: true,
        leftSeries: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
        rightSeries: [1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0],
      );
      expect(PupilResponseAnalyzer().analyze(flat, highQ()).finding,
          ResultCategory.unableToAssess);
    });
  });
}
