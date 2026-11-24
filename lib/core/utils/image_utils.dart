// Pure-Dart image statistics used by the quality gate and analyzers.
// Operates on raw RGB bytes so it is unit-testable without a camera.
// Callers decode with package:image and pass pixels downsampled if needed.

class ImageStats {
  final double meanLuminance; // 0..255
  final double overexposedFraction; // luminance > 240
  final double underexposedFraction; // luminance < 15
  final double sharpnessVariance; // Laplacian variance (higher = sharper)
  final double rednessMean; // mean r/(r+g+b) over sampled pixels
  final double yellownessMean; // mean (r+g)/2 - b proxy, normalized
  // Reported capture dimensions. These may be larger than the downsampled
  // working buffer used for pixel statistics.
  final int width;
  final int height;

  const ImageStats({
    required this.meanLuminance,
    required this.overexposedFraction,
    required this.underexposedFraction,
    required this.sharpnessVariance,
    required this.rednessMean,
    required this.yellownessMean,
    required this.width,
    required this.height,
  });
}

class ImageUtils {
  /// Compute stats from interleaved RGB bytes.
  ///
  /// [width]/[height] describe the sampled pixel buffer. When callers
  /// downsample for performance, [actualWidth]/[actualHeight] preserve the
  /// original capture dimensions so resolution checks use real pixels
  /// rather than the downsampled working size.
  static ImageStats computeStats(
    List<int> rgb, {
    required int width,
    required int height,
    int stride = 1,
    int? actualWidth,
    int? actualHeight,
  }) {
    final int reportWidth =
        actualWidth != null && actualWidth > 0 ? actualWidth : width;
    final int reportHeight =
        actualHeight != null && actualHeight > 0 ? actualHeight : height;
    if (rgb.isEmpty || width <= 0 || height <= 0) {
      return ImageStats(
        meanLuminance: 0,
        overexposedFraction: 1,
        underexposedFraction: 1,
        sharpnessVariance: 0,
        rednessMean: 0,
        yellownessMean: 0,
        width: reportWidth,
        height: reportHeight,
      );
    }
    final n = width * height;
    double lumSum = 0;
    int over = 0, under = 0;
    double redSum = 0, yellowSum = 0;
    int count = 0;

    // Grayscale buffer for Laplacian.
    final gray = List<double>.filled(n, 0);

    for (int i = 0; i < n; i += stride) {
      final o = i * 3;
      if (o + 2 >= rgb.length) break;
      final r = rgb[o].toDouble();
      final g = rgb[o + 1].toDouble();
      final b = rgb[o + 2].toDouble();
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      gray[i] = lum;
      lumSum += lum;
      if (lum > 240) over++;
      if (lum < 15) under++;
      final s = r + g + b;
      if (s > 1) {
        redSum += r / s;
        yellowSum += ((r + g) / 2 - b) / 255.0;
      }
      count++;
    }
    final mean = count == 0 ? 0.0 : lumSum / count;

    // Laplacian variance on interior pixels (step by stride).
    double lapSum = 0;
    double lapSqSum = 0;
    int lapCount = 0;
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final i = y * width + x;
        if (i % stride != 0) continue;
        final c = gray[i];
        final lap = gray[i - 1] +
            gray[i + 1] +
            gray[i - width] +
            gray[i + width] -
            4 * c;
        lapSum += lap;
        lapSqSum += lap * lap;
        lapCount++;
      }
    }
    double variance = 0;
    if (lapCount > 1) {
      final m = lapSum / lapCount;
      variance = (lapSqSum / lapCount) - m * m;
      if (variance.isNaN || variance < 0) variance = 0;
    }

    return ImageStats(
      meanLuminance: mean,
      overexposedFraction: count == 0 ? 1 : over / count,
      underexposedFraction: count == 0 ? 1 : under / count,
      sharpnessVariance: variance,
      rednessMean: count == 0 ? 0 : redSum / count,
      yellownessMean: count == 0 ? 0 : yellowSum / count,
      width: reportWidth,
      height: reportHeight,
    );
  }

  /// Relative asymmetry index from spec:
  /// abs(l - r) / average(l, r). Returns 0 when both are 0.
  static double asymmetryIndex(double left, double right) {
    final avg = (left.abs() + right.abs()) / 2.0;
    if (avg <= 1e-9) return 0;
    return (left - right).abs() / avg;
  }

  /// Left/right percent difference helper for landmark amplitudes.
  static double percentDifference(double left, double right) =>
      asymmetryIndex(left, right) * 100.0;

  /// Sample color statistics inside an elliptical eye region.
  ///
  /// All positions use the sampled buffer's normalized coordinates (0..1).
  /// [faceWidth] is the normalized horizontal face width in the same space
  /// and supplies the physical scale for the region. The region is only a
  /// landmark-centered ROI: it does not segment sclera from eyelids, lashes,
  /// or iris. Callers must label downstream results accordingly.
  static EyeRegionSample sampleEyeRegion({
    required List<int> rgb,
    required int width,
    required int height,
    required double centerX,
    required double centerY,
    required double faceWidth,
    double regionScale = 0.28,
    double regionHeightRatio = 0.65,
    int stride = 2,
  }) {
    const empty = EyeRegionSample(
      meanLuminance: 0,
      rednessMean: 0,
      yellownessMean: 0,
      redDominantFraction: 0,
      pixelCount: 0,
    );
    if (rgb.isEmpty || width <= 0 || height <= 0 || stride <= 0) return empty;
    if (centerX.isNaN ||
        centerY.isNaN ||
        faceWidth.isNaN ||
        faceWidth <= 0 ||
        faceWidth > 1) {
      return empty;
    }
    // Centers may sit near the frame edge (the ROI is clipped below), but a
    // center outside normalized image space cannot belong to this image.
    if (centerX < 0 || centerX > 1 || centerY < 0 || centerY > 1) {
      return empty;
    }

    final halfW = faceWidth * regionScale / 2;
    final halfH = halfW * width / height * regionHeightRatio;
    if (halfW <= 0 || halfH <= 0) return empty;

    double lumSum = 0;
    double redSum = 0;
    double yellowSum = 0;
    int redDominant = 0;
    int count = 0;
    final n = width * height;
    for (int i = 0; i < n; i += stride) {
      final o = i * 3;
      if (o + 2 >= rgb.length) break;
      final x = (i % width + 0.5) / width;
      final y = (i ~/ width + 0.5) / height;
      final dx = (x - centerX) / halfW;
      final dy = (y - centerY) / halfH;
      if (dx * dx + dy * dy > 1) continue;
      final r = rgb[o].toDouble();
      final g = rgb[o + 1].toDouble();
      final b = rgb[o + 2].toDouble();
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final sum = r + g + b;
      lumSum += lum;
      if (sum > 1) {
        redSum += r / sum;
        yellowSum += ((r + g) / 2 - b) / 255.0;
        if (sum > 30 && r / sum > 0.45) redDominant++;
      }
      count++;
    }
    if (count == 0) return empty;
    return EyeRegionSample(
      meanLuminance: lumSum / count,
      rednessMean: redSum / count,
      yellownessMean: yellowSum / count,
      redDominantFraction: redDominant / count,
      pixelCount: count,
    );
  }

  /// Prototype color-confidence proxy for eye-region color comparison.
  ///
  /// This is an engineering gate, not a calibrated white-balance measurement.
  /// Poor exposure, extreme luminance, strong color cast, or mismatched left
  /// and right samples all lower confidence. Values below 0.5 mean color
  /// comparison is unavailable.
  static double eyeRegionColorConfidence({
    required EyeRegionSample left,
    required EyeRegionSample right,
    required ImageStats full,
  }) {
    if (!left.usable || !right.usable) return 0;
    if (full.overexposedFraction > 0.25 ||
        full.underexposedFraction > 0.25) {
      return 0.3;
    }
    final lum = (left.meanLuminance + right.meanLuminance) / 2;
    if (lum < 70 || lum > 190) return 0.35;
    final cast = (left.yellownessMean + right.yellownessMean).abs() / 2;
    if (cast > 0.08) return 0.4;
    final redMismatch = (left.rednessMean - right.rednessMean).abs();
    if (redMismatch > 0.08) return 0.45;
    return 0.8;
  }
}

/// Landmark-centered eye-region color sample. See
/// [ImageUtils.sampleEyeRegion] for the ROI limitation.
class EyeRegionSample {
  final double meanLuminance;
  final double rednessMean;
  final double yellownessMean;
  final double redDominantFraction;
  final int pixelCount;

  /// Minimum sampled pixels before color comparison is attempted.
  static const int minPixels = 25;

  const EyeRegionSample({
    required this.meanLuminance,
    required this.rednessMean,
    required this.yellownessMean,
    required this.redDominantFraction,
    required this.pixelCount,
  });

  bool get usable => pixelCount >= minPixels;
}
