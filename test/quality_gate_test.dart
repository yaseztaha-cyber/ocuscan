import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:ocuscan/core/models/screening_result.dart';
import 'package:ocuscan/core/pipeline/quality_gate.dart';
import 'package:ocuscan/core/utils/image_utils.dart';
import 'package:ocuscan/features/camera/eye_tracking.dart';
import 'package:ocuscan/ui/screens/screening/screening_flow.dart'
    show stillQualityInput;

QualityInput _base({ImageStats? stats, bool eyes = true}) => QualityInput(
  stats: stats ?? const ImageStats(meanLuminance: 120, overexposedFraction: 0.02,
    underexposedFraction: 0.02, sharpnessVariance: 120, rednessMean: 0.36,
    yellownessMean: 0.05, width: 640, height: 480),
  bothEyesVisible: eyes, faceCentered: true, faceAngleDeg: 0,
  faceBoxFraction: 0.5, eyesObstructed: false, strongBacklight: false,
  coloredAmbientLight: false,
);

void main() {
  group('QualityGate', () {
    test('high quality passes', () {
      final v = QualityGate.evaluate(_base());
      expect(v.quality, ImageQuality.high);
    });
    test('blur forces LOW', () {
      const s = ImageStats(meanLuminance: 120, overexposedFraction: 0.02,
        underexposedFraction: 0.02, sharpnessVariance: 5, rednessMean: 0.36,
        yellownessMean: 0.05, width: 640, height: 480);
      final v = QualityGate.evaluate(_base(stats: s));
      expect(v.quality, ImageQuality.low);
    });
    test('dark scene forces LOW', () {
      const s = ImageStats(meanLuminance: 10, overexposedFraction: 0.0,
        underexposedFraction: 0.8, sharpnessVariance: 120, rednessMean: 0.36,
        yellownessMean: 0.05, width: 640, height: 480);
      final v = QualityGate.evaluate(_base(stats: s));
      expect(v.quality, ImageQuality.low);
    });
    test('missing eyes degrades', () {
      final v = QualityGate.evaluate(_base(eyes: false));
      expect(v.quality == ImageQuality.low || v.quality == ImageQuality.medium, true);
      expect(v.issues.isNotEmpty, true);
    });
    test('capture attempts report resolved and introduced issues', () {
      final first = CaptureAttempt(
          at: DateTime.utc(2026, 1, 1),
          source: 'front',
          width: 1280,
          height: 960,
          score: 42,
          quality: ImageQuality.low,
          issues: const ['Scene too dark.', 'Both eyes are not visible.']);
      final second = CaptureAttempt(
          at: DateTime.utc(2026, 1, 1, 0, 1),
          source: 'front',
          width: 1280,
          height: 960,
          score: 78,
          quality: ImageQuality.medium,
          issues: const ['Both eyes are not visible.', 'Face slightly turned.']);
      expect(second.resolvedSince(first), ['Scene too dark.']);
      expect(second.introducedSince(first), ['Face slightly turned.']);
      expect(second.resolvedSince(null), isEmpty);
    });
    test('low quality message is safe', () {
      expect(QualityGate.lowQualityMessage.contains('reliable image'), true);
    });
    ImageStats _stats({
      double lum = 120,
      double over = 0.02,
      double under = 0.02,
      double sharp = 120,
      int w = 640,
      int h = 480,
    }) =>
        ImageStats(
            meanLuminance: lum,
            overexposedFraction: over,
            underexposedFraction: under,
            sharpnessVariance: sharp,
            rednessMean: 0.36,
            yellownessMean: 0.05,
            width: w,
            height: h);
    QualityInput _mod({
      ImageStats? stats,
      bool eyes = true,
      bool centered = true,
      double angle = 0,
      double fraction = 0.5,
      bool obstructed = false,
      bool backlight = false,
      bool colored = false,
    }) =>
        QualityInput(
          stats: stats ?? _stats(),
          bothEyesVisible: eyes,
          faceCentered: centered,
          faceAngleDeg: angle,
          faceBoxFraction: fraction,
          eyesObstructed: obstructed,
          strongBacklight: backlight,
          coloredAmbientLight: colored,
        );
    test('bright scene is medium, not high', () {
      final v = QualityGate.evaluate(_mod(stats: _stats(lum: 230)));
      expect(v.quality, ImageQuality.medium);
      expect(v.issues, contains('Scene too bright.'));
    });
    test('exposure fractions and backlight each cost medium', () {
      for (final input in [
        _mod(stats: _stats(over: 0.5)),
        _mod(stats: _stats(under: 0.5)),
        _mod(backlight: true),
      ]) {
        final v = QualityGate.evaluate(input);
        expect(v.quality, ImageQuality.medium);
        expect(v.issues.length, 1);
      }
    });
    test('soft blur lands medium with guidance', () {
      final v = QualityGate.evaluate(_mod(stats: _stats(sharp: 40)));
      expect(v.quality, ImageQuality.medium);
      expect(v.issues, contains('Image may be slightly soft.'));
      expect(v.guidance.isNotEmpty, true);
    });
    test('geometry faults each cost medium', () {
      final cases = {
        'Face is not centered.': _mod(centered: false),
        'Face slightly turned.': _mod(angle: 15),
        'Face angle too large.': _mod(angle: 30),
        'Face too far from camera.': _mod(fraction: 0.1),
        'Face too close; landmarks may clip.': _mod(fraction: 0.99),
      };
      for (final e in cases.entries) {
        final v = QualityGate.evaluate(e.value);
        expect(v.quality, ImageQuality.medium, reason: e.key);
        expect(v.issues, contains(e.key));
      }
    });
    test('obstructed and colored light stay medium alone', () {
      expect(QualityGate.evaluate(_mod(obstructed: true)).quality,
          ImageQuality.medium);
      expect(QualityGate.evaluate(_mod(colored: true)).quality,
          ImageQuality.medium);
      expect(
          QualityGate.evaluate(_mod(obstructed: true)).issues,
          contains('Eyes appear obstructed (hair, hands, glasses glare).'));
    });
    test('low resolution costs medium', () {
      final v =
          QualityGate.evaluate(_mod(stats: _stats(w: 320, h: 240)));
      expect(v.quality, ImageQuality.medium);
      expect(v.issues, contains('Image resolution too low.'));
    });
    test('missing eyes with score below 70 vetoes to LOW', () {
      final v = QualityGate.evaluate(_mod(eyes: false));
      expect(v.score, 65);
      expect(v.quality, ImageQuality.low);
    });
    test('extreme luminance vetoes to LOW despite mid score', () {
      expect(
          QualityGate.evaluate(_mod(stats: _stats(lum: 240))).quality,
          ImageQuality.low);
      expect(
          QualityGate.evaluate(_mod(stats: _stats(lum: 20))).quality,
          ImageQuality.low);
    });
    test('score floor clamps at zero on stacked faults', () {
      final v = QualityGate.evaluate(_mod(
        stats: _stats(lum: 10, over: 0.5, under: 0.5, sharp: 5, w: 100, h: 100),
        eyes: false,
        centered: false,
        angle: 30,
        fraction: 0.1,
        obstructed: true,
        backlight: true,
        colored: true,
      ));
      expect(v.score, 0);
      expect(v.quality, ImageQuality.low);
      expect(v.issues.length, v.guidance.length);
    });
  });

  group('ImageUtils', () {
    test('asymmetry index formula', () {
      expect(ImageUtils.asymmetryIndex(100, 100), 0);
      expect(ImageUtils.asymmetryIndex(120, 80), closeTo(0.4, 1e-9));
      expect(ImageUtils.asymmetryIndex(0, 0), 0);
    });
    test('computeStats on uniform gray', () {
      final rgb = List<int>.filled(32 * 32 * 3, 128);
      final s = ImageUtils.computeStats(rgb, width: 32, height: 32);
      expect(s.meanLuminance, closeTo(128, 2));
      expect(s.sharpnessVariance, closeTo(0, 1e-6));
    });
    test('computeStats preserves the original capture resolution', () {
      final rgb = List<int>.filled(32 * 32 * 3, 128);
      final s = ImageUtils.computeStats(rgb,
          width: 32, height: 32, actualWidth: 1280, actualHeight: 960);
      expect(s.width, 1280);
      expect(s.height, 960);
      expect(s.meanLuminance, closeTo(128, 2));
    });
    test('computeStats ignores invalid reported dimensions', () {
      final rgb = List<int>.filled(32 * 32 * 3, 128);
      final s = ImageUtils.computeStats(rgb,
          width: 32, height: 32, actualWidth: 0, actualHeight: -4);
      expect(s.width, 32);
      expect(s.height, 32);
    });
    test('eye-region sampler stays inside the landmark ROI', () {
      const width = 80;
      const height = 40;
      final rgb = List<int>.filled(width * height * 3, 60);
      // Paint the left ROI red; paint the matching right ROI neutral gray.
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < 20; x++) {
          final o = (y * width + x) * 3;
          rgb[o] = 200;
          rgb[o + 1] = 60;
          rgb[o + 2] = 60;
        }
        for (var x = 60; x < width; x++) {
          final o = (y * width + x) * 3;
          rgb[o] = 120;
          rgb[o + 1] = 120;
          rgb[o + 2] = 120;
        }
      }
      final left = ImageUtils.sampleEyeRegion(
          rgb: rgb,
          width: width,
          height: height,
          centerX: 0.125,
          centerY: 0.5,
          faceWidth: 0.8);
      final right = ImageUtils.sampleEyeRegion(
          rgb: rgb,
          width: width,
          height: height,
          centerX: 0.875,
          centerY: 0.5,
          faceWidth: 0.8);
      expect(left.usable, true);
      expect(right.usable, true);
      expect(left.rednessMean, greaterThan(right.rednessMean + 0.1));
    });
    test('eye-region sampler rejects invalid geometry', () {
      final rgb = List<int>.filled(20 * 10 * 3, 120);
      final outside = ImageUtils.sampleEyeRegion(
          rgb: rgb,
          width: 20,
          height: 10,
          centerX: 1.5,
          centerY: 0.5,
          faceWidth: 0.4);
      final invalidScale = ImageUtils.sampleEyeRegion(
          rgb: rgb,
          width: 20,
          height: 10,
          centerX: 0.5,
          centerY: 0.5,
          faceWidth: 0);
      expect(outside.usable, false);
      expect(invalidScale.usable, false);
    });
    test('still verdict uses the still geometry, not a stale frame', () {
      const stats = ImageStats(
          meanLuminance: 130,
          overexposedFraction: 0.02,
          underexposedFraction: 0.02,
          sharpnessVariance: 120,
          rednessMean: 0.38,
          yellownessMean: 0.02,
          width: 640,
          height: 480);
      EyeGeometry geo(double l, double r) => EyeGeometry(
            faceFound: true,
            faceBox: const Rect.fromLTWH(0.3, 0.2, 0.4, 0.4),
            leftEye: const EyePoint(0.42, 0.38),
            rightEye: const EyePoint(0.58, 0.38),
            yawDeg: 0,
            leftOpenProb: l,
            rightOpenProb: r,
            imageWidth: 640,
            imageHeight: 480,
          );
      // Open eyes in the still: visible, centered, no obstruction.
      final open = stillQualityInput(geo(0.9, 0.85), stats);
      expect(open.bothEyesVisible, true);
      expect(open.faceCentered, true);
      expect(open.eyesObstructed, false);
      // Measured-closed in the still: not visible + obstructed.
      final closed = stillQualityInput(geo(0.1, 0.9), stats);
      expect(closed.bothEyesVisible, false);
      expect(closed.eyesObstructed, true);
      // Unknown openness (-1) with landmarks: permissive, and NEVER
      // mislabeled as obstructed.
      final unknown = stillQualityInput(geo(-1, -1), stats);
      expect(unknown.bothEyesVisible, true);
      expect(unknown.eyesObstructed, false);
      // No face in the still: nothing claimed either way.
      final noFace = stillQualityInput(
          const EyeGeometry(faceFound: false), stats);
      expect(noFace.bothEyesVisible, false);
      expect(noFace.eyesObstructed, false);
      expect(noFace.faceCentered, false);
    });
    test('color confidence requires usable, well-exposed samples', () {
      const good = EyeRegionSample(
          meanLuminance: 130,
          rednessMean: 0.38,
          yellownessMean: 0.02,
          redDominantFraction: 0.1,
          pixelCount: 120);
      const full = ImageStats(
          meanLuminance: 130,
          overexposedFraction: 0.02,
          underexposedFraction: 0.02,
          sharpnessVariance: 120,
          rednessMean: 0.38,
          yellownessMean: 0.02,
          width: 640,
          height: 480);
      expect(
          ImageUtils.eyeRegionColorConfidence(
              left: good, right: good, full: full),
          greaterThanOrEqualTo(0.5));
      const dark = EyeRegionSample(
          meanLuminance: 30,
          rednessMean: 0.38,
          yellownessMean: 0.02,
          redDominantFraction: 0.1,
          pixelCount: 120);
      expect(
          ImageUtils.eyeRegionColorConfidence(
              left: dark, right: dark, full: full),
          lessThan(0.5));
    });
  });
}
