// Strict image-quality gate. Runs BEFORE any screening analysis.
// States: HIGH -> continue; MEDIUM -> repeat-or-continue where acceptable;
// LOW -> do NOT produce a screening result.
//
// Inputs are explicit so the gate is deterministic and unit-testable.

import '../models/screening_result.dart';
import '../utils/image_utils.dart';

class QualityInput {
  final ImageStats stats;
  final bool bothEyesVisible;
  final bool faceCentered;
  final double faceAngleDeg; // absolute yaw/pitch estimate
  final double faceBoxFraction; // face height / image height
  final bool eyesObstructed;
  final bool strongBacklight;
  final bool coloredAmbientLight;

  const QualityInput({
    required this.stats,
    required this.bothEyesVisible,
    required this.faceCentered,
    required this.faceAngleDeg,
    required this.faceBoxFraction,
    required this.eyesObstructed,
    required this.strongBacklight,
    required this.coloredAmbientLight,
  });
}

class QualityVerdict {
  final ImageQuality quality;
  final double score; // 0..100 internal
  final List<String> issues;
  final List<String> guidance;

  const QualityVerdict({
    required this.quality,
    required this.score,
    required this.issues,
    required this.guidance,
  });
}

/// One evaluated still-image attempt. The raw image is transient; this
/// record keeps only the actionable measurement metadata needed to compare
/// retries and to show whether guidance actually improved the capture.
class CaptureAttempt {
  final DateTime at;
  final String source;
  final int width;
  final int height;
  final double score;
  final ImageQuality quality;
  final List<String> issues;

  const CaptureAttempt({
    required this.at,
    required this.source,
    required this.width,
    required this.height,
    required this.score,
    required this.quality,
    required this.issues,
  });

  /// Issues present in [previous] but absent now.
  List<String> resolvedSince(CaptureAttempt? previous) {
    if (previous == null) return const [];
    return previous.issues.where((i) => !issues.contains(i)).toList();
  }

  /// Issues absent before but present now.
  List<String> introducedSince(CaptureAttempt? previous) {
    if (previous == null) return const [];
    return issues.where((i) => !previous.issues.contains(i)).toList();
  }
}

class QualityGate {
  /// Protocol version stamped on every measurement trace (§9).
  static const String protocolVersion = 'quality-gate-v1';
  // Conservative thresholds — tuned for safety, not demo impressiveness.
  static const double minSharpness = 60.0;
  static const double lowSharpness = 25.0;
  static const double minLuminance = 45.0;
  static const double maxLuminance = 210.0;
  static const double maxBadExposureFraction = 0.25;
  static const int minDimension = 480;

  static QualityVerdict evaluate(QualityInput input) {
    final issues = <String>[];
    final guidance = <String>[];
    double score = 100;

    final s = input.stats;

    // Resolution.
    if (s.width < minDimension || s.height < minDimension) {
      issues.add('Image resolution too low.');
      guidance.add('Use the rear camera or move closer if guidance allows.');
      score -= 30;
    }

    // Lighting / exposure.
    if (s.meanLuminance < minLuminance) {
      issues.add('Scene too dark.');
      guidance.add('Move to a well-lit room facing a window or lamp.');
      score -= 25;
    }
    if (s.meanLuminance > maxLuminance) {
      issues.add('Scene too bright.');
      guidance.add('Reduce glare and avoid pointing the camera at lights.');
      score -= 25;
    }
    if (s.overexposedFraction > maxBadExposureFraction) {
      issues.add('Overexposed regions detected.');
      guidance.add('Reduce bright light behind you.');
      score -= 15;
    }
    if (s.underexposedFraction > maxBadExposureFraction) {
      issues.add('Underexposed regions detected.');
      guidance.add('Add soft frontal lighting on the face.');
      score -= 15;
    }
    if (input.strongBacklight) {
      issues.add('Strong backlight.');
      guidance.add('Place light in front of the face, not behind.');
      score -= 15;
    }

    // Blur / focus.
    if (s.sharpnessVariance < lowSharpness) {
      issues.add('Image is blurred or out of focus.');
      guidance.add('Hold the phone steady at eye level and tap to focus.');
      score -= 30;
    } else if (s.sharpnessVariance < minSharpness) {
      issues.add('Image may be slightly soft.');
      guidance.add('Hold still for a moment and retake if possible.');
      score -= 12;
    }

    // Geometry.
    if (!input.bothEyesVisible) {
      issues.add('Both eyes are not visible.');
      guidance.add('Remove obstructions, center the face in the guide.');
      score -= 35;
    }
    if (!input.faceCentered) {
      issues.add('Face is not centered.');
      guidance.add('Align the face inside the on-screen guide.');
      score -= 12;
    }
    if (input.faceAngleDeg.abs() > 20) {
      issues.add('Face angle too large.');
      guidance.add('Look straight at the phone at eye level.');
      score -= 20;
    } else if (input.faceAngleDeg.abs() > 12) {
      issues.add('Face slightly turned.');
      guidance.add('Face the camera directly.');
      score -= 8;
    }
    if (input.faceBoxFraction < 0.25) {
      issues.add('Face too far from camera.');
      guidance.add('Move the phone closer to the guided distance.');
      score -= 15;
    }
    if (input.faceBoxFraction > 0.95) {
      issues.add('Face too close; landmarks may clip.');
      guidance.add('Move the phone slightly farther away.');
      score -= 10;
    }
    if (input.eyesObstructed) {
      issues.add('Eyes appear obstructed (hair, hands, glasses glare).');
      guidance.add('Clear the eye area and reduce reflections.');
      score -= 25;
    }
    if (input.coloredAmbientLight) {
      issues.add('Colored ambient lighting detected.');
      guidance.add('Color-based tests need neutral white lighting.');
      score -= 15;
    }

    score = score.clamp(0, 100);

    final ImageQuality q;
    if (score >= 80 && issues.isEmpty) {
      q = ImageQuality.high;
    } else if (score >= 55) {
      q = ImageQuality.medium;
    } else {
      q = ImageQuality.low;
    }

    // Hard vetoes: never upgrade these to medium/high.
    if (!input.bothEyesVisible || input.eyesObstructed) {
      if (q != ImageQuality.low && score < 70) {
        return QualityVerdict(
            quality: ImageQuality.low,
            score: score,
            issues: issues,
            guidance: guidance);
      }
    }
    if (s.sharpnessVariance < lowSharpness ||
        s.meanLuminance < 25 ||
        s.meanLuminance > 235) {
      return QualityVerdict(
          quality: ImageQuality.low,
          score: score,
          issues: issues,
          guidance: guidance);
    }

    return QualityVerdict(
        quality: q, score: score, issues: issues, guidance: guidance);
  }

  static const String lowQualityMessage =
      "We couldn't obtain a reliable image. "
      'Please improve the lighting, move the phone to eye level, '
      'and keep your face still.';
}
