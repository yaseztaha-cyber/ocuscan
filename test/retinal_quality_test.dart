// Retinal quality gate tests: gradable only when every check passes;
// every failure named; doubt means ungradable.
import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/features/retina/retinal_quality.dart';

RetinalQualityInput good() => const RetinalQualityInput(
      focus: 80,
      illumination: 75,
      fieldCoverage: 0.9,
      artifacts: 0.1,
      stillness: 80,
      contrast: 70,
      retinaVisible: true,
      opticDiscVisible: true,
      vesselsVisible: true,
    );

void main() {
  group('RetinalQualityGate', () {
    test('good image is gradable', () {
      final v = RetinalQualityGate.evaluate(good());
      expect(v.gradable, true);
      expect(v.reasons.length, 1);
    });

    test('missing retina fails fast', () {
      final v = RetinalQualityGate.evaluate(const RetinalQualityInput(
        focus: 90,
        illumination: 90,
        fieldCoverage: 1.0,
        artifacts: 0.0,
        stillness: 90,
        contrast: 90,
        retinaVisible: false,
        opticDiscVisible: false,
        vesselsVisible: false,
      ));
      expect(v.gradable, false);
      expect(v.reasons.any((r) => r.contains('No retinal view')),
          true);
    });

    test('each dimension can fail independently', () {
      final base = good();
      final cases = [
        base.copyWithFocus(10),
        base.copyWithIllumination(10),
        base.copyWithField(0.2),
        base.copyWithArtifacts(0.9),
        base.copyWithStillness(10),
        base.copyWithContrast(10),
      ];
      for (final c in cases) {
        expect(RetinalQualityGate.evaluate(c).gradable, false);
      }
    });

    test('disc and vessel visibility required where relevant', () {
      final v = RetinalQualityGate.evaluate(const RetinalQualityInput(
        focus: 80,
        illumination: 75,
        fieldCoverage: 0.9,
        artifacts: 0.1,
        stillness: 80,
        contrast: 70,
        retinaVisible: true,
        opticDiscVisible: false,
        vesselsVisible: true,
      ));
      expect(v.gradable, false);
      expect(v.reasons.any((r) => r.contains('Optic disc')), true);
    });
  });
}

extension on RetinalQualityInput {
  RetinalQualityInput copyWithFocus(double v) => RetinalQualityInput(
      focus: v,
      illumination: illumination,
      fieldCoverage: fieldCoverage,
      artifacts: artifacts,
      stillness: stillness,
      contrast: contrast,
      retinaVisible: retinaVisible,
      opticDiscVisible: opticDiscVisible,
      vesselsVisible: vesselsVisible);
  RetinalQualityInput copyWithIllumination(double v) =>
      RetinalQualityInput(
          focus: focus,
          illumination: v,
          fieldCoverage: fieldCoverage,
          artifacts: artifacts,
          stillness: stillness,
          contrast: contrast,
          retinaVisible: retinaVisible,
          opticDiscVisible: opticDiscVisible,
          vesselsVisible: vesselsVisible);
  RetinalQualityInput copyWithField(double v) => RetinalQualityInput(
      focus: focus,
      illumination: illumination,
      fieldCoverage: v,
      artifacts: artifacts,
      stillness: stillness,
      contrast: contrast,
      retinaVisible: retinaVisible,
      opticDiscVisible: opticDiscVisible,
      vesselsVisible: vesselsVisible);
  RetinalQualityInput copyWithArtifacts(double v) => RetinalQualityInput(
      focus: focus,
      illumination: illumination,
      fieldCoverage: fieldCoverage,
      artifacts: v,
      stillness: stillness,
      contrast: contrast,
      retinaVisible: retinaVisible,
      opticDiscVisible: opticDiscVisible,
      vesselsVisible: vesselsVisible);
  RetinalQualityInput copyWithStillness(double v) => RetinalQualityInput(
      focus: focus,
      illumination: illumination,
      fieldCoverage: fieldCoverage,
      artifacts: artifacts,
      stillness: v,
      contrast: contrast,
      retinaVisible: retinaVisible,
      opticDiscVisible: opticDiscVisible,
      vesselsVisible: vesselsVisible);
  RetinalQualityInput copyWithContrast(double v) => RetinalQualityInput(
      focus: focus,
      illumination: illumination,
      fieldCoverage: fieldCoverage,
      artifacts: artifacts,
      stillness: stillness,
      contrast: v,
      retinaVisible: retinaVisible,
      opticDiscVisible: opticDiscVisible,
      vesselsVisible: vesselsVisible);
}
