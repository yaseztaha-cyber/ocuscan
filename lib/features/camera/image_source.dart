// Image-source abstraction (v0.2, future retinal attachment ready).
//
// The normal screening pipeline uses front/rear camera sources only.
// A future retinal optical attachment plugs in as FutureRetinalCameraSource
// with its own quality gate and research models. No retinal disease
// classifier may operate on ordinary front-camera eye images: the retinal
// path refuses non-retinal sources explicitly instead of guessing.

import '../../core/pipeline/quality_gate.dart';

/// Where a research image came from.
abstract class ImageSource {
  String get label;
  String get code;

  /// Modality tag: 'camera' for ordinary phone captures, 'retinal' for
  /// verified retinal-capture hardware. Retinal analysis accepts only
  /// sources whose [sourceType] is 'retinal'.
  String get sourceType => 'camera';
}

class FrontCameraSource extends ImageSource {
  @override
  String get label => 'Front camera';
  @override
  String get code => 'front';
}

class RearCameraSource extends ImageSource {
  @override
  String get label => 'Rear camera';
  @override
  String get code => 'rear';
}

/// Placeholder for a future calibrated retinal optical attachment.
/// Not a working source in this build: using it raises, by design.
class FutureRetinalCameraSource extends ImageSource {
  @override
  String get label => 'Future retinal attachment (not available)';
  @override
  String get code => 'future_retinal';

  /// Always throws: there is no retinal capture path in this build.
  Never requireRetinalImage() {
    throw UnsupportedError(
      'Retinal analysis requires a calibrated optical attachment with '
      'controlled illumination. Ordinary front-camera eye images must never '
      'be used as retinal images.',
    );
  }
}

/// Future verified retinal-capture interface. Even when hardware exists,
/// [require] rejects anything that is not a verified retinal source:
/// front camera, ordinary selfie images, and face images are refused
/// before any retinal analysis can run.
class RetinalImageSource extends ImageSource {
  @override
  String get label => 'Retinal attachment capture';
  @override
  String get code => 'retinal';

  @override
  String get sourceType => 'retinal';

  /// Validates the source modality. Throws for non-retinal sources.
  static void require(ImageSource source) {
    if (source.sourceType != 'retinal') {
      throw UnsupportedError(
        'sourceType = ${source.sourceType}: retinal analysis requires '
        'sourceType = retinal from a verified optical attachment. '
        'Front camera, selfie, and face images are rejected.',
      );
    }
  }
}

ImageSource imageSourceForCode(String code) {
  switch (code) {
    case 'rear':
      return RearCameraSource();
    case 'future_retinal':
      return FutureRetinalCameraSource();
    default:
      return FrontCameraSource();
  }
}

/// Future retinal workflow shape (quality first, research model last).
/// In this build the workflow stops after the quality verdict: no retinal
/// model exists, so no finding is ever produced here.
class RetinalResearchWorkflow {
  /// Returns the quality verdict only. A finding requires a validated
  /// retinal model, which is not present in this build.
  static QualityVerdict assessCaptureQuality(QualityInput input) =>
      QualityGate.evaluate(input);
}
