// JPEG-file ML fallback (v0.7.5): escape hatch for devices where ML Kit's
// native InputImage.fromByteArray throws on valid bytes (observed NPE on
// an OPPO CPH2121 for both NV21 and YV12 declarations at exact canonical
// sizes). InputImage.fromFilePath takes a completely different native
// path (file decode, no byte-array converter), so valid pixels that the
// converter rejects can still be detected.
//
// Strategy per fallback frame, all pure and unit-tested here:
// 1. Downscale (longest side <= 480px): face detection needs position,
//    not megapixels; keeps encode + detection latency bounded.
// 2. Rotate pixels to UPRIGHT in the loop (explicit inverse-clockwise
//    mapping — no library direction ambiguity), sampling Y + VU directly
//    from the canonical NV21 buffer.
// 3. Full-range BT.601 YUV->RGB, JPEG-encode. The service writes these
//    bytes to a reused temp file and runs fromFilePath on it.
//
// Detection runs on upright pixels, so boxes normalize by the UPRIGHT
// dimensions with rotation 0 at the call site. Chroma fidelity only
// affects color; face geometry comes from luma. All synthesis is logged
// by the caller (layout suffix + ML_INPUT event), never silent.

import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'camera_pipeline.dart' show maxFramePixels;

/// Downscale factor so the fallback frame's longest side is <= 480px.
/// Bounded [1, 8]; 1 means full resolution.
int fallbackScaleFor(int width, int height) {
  if (width <= 0 || height <= 0) return 1;
  final m = width > height ? width : height;
  return ((m / 480).ceil()).clamp(1, 8);
}

/// Upright (display-order) dimensions after a clockwise rotation of
/// sensor-order pixels. Record return: (w, h).
({int w, int h}) uprightDimsFor(int width, int height, int rotationDeg) {
  final r = ((rotationDeg % 360) + 360) % 360;
  if (r == 90 || r == 270) return (w: height, h: width);
  return (w: width, h: height);
}

/// Latch rule for the file fallback: the YV12 declaration AND the RGBA
/// bitmap rung already failed persistently, so the byte-array converter
/// and bitmap native paths are exhausted on this device. Same gate shape
/// (converter-class errors, zero analyzed frames), one rung further down.
bool shouldLatchFileFallback({
  required int consecMlErrors,
  required int framesProcessed,
  required bool yv12Latched,
  required bool bitmapLatched,
  required bool fileLatched,
  required bool converterError,
}) =>
    converterError &&
    yv12Latched &&
    bitmapLatched &&
    !fileLatched &&
    framesProcessed == 0 &&
    consecMlErrors >= 10;

int _clamp8(int v) => v < 0 ? 0 : (v > 255 ? 255 : v);

/// Build an upright, downscaled RGB image from a canonical NV21 buffer.
/// Returns null when the buffer cannot supply the pixels (short, absurd
/// dims). Rotation is applied by explicit inverse-clockwise sampling —
/// target upright pixel (ux,uy) reads source sensor pixel:
/// 0: (ux,uy); 90: (uy, H-1-ux); 180: (W-1-ux, H-1-uy); 270: (W-1-uy, ux).
img.Image? nv21ToRgbImage({
  required List<int> nv21,
  required int width,
  required int height,
  required int rotationDeg,
}) {
  if (width <= 0 || height <= 0) return null;
  if (width * height > maxFramePixels) return null;
  if (nv21.length < width * height * 3 ~/ 2) return null;
  final r = ((rotationDeg % 360) + 360) % 360;
  if (r != 0 && r != 90 && r != 180 && r != 270) return null;

  final scale = fallbackScaleFor(width, height);
  final dims = uprightDimsFor(width, height, r);
  final suw = (dims.w + scale - 1) ~/ scale;
  final suh = (dims.h + scale - 1) ~/ scale;
  if (suw <= 0 || suh <= 0) return null;

  final yLen = width * height;
  final out = img.Image(width: suw, height: suh);
  for (var uy = 0; uy < suh; uy++) {
    for (var ux = 0; ux < suw; ux++) {
      // Full-res upright coords, then inverse rotation to sensor coords.
      var fx = ux * scale;
      var fy = uy * scale;
      if (fx >= dims.w) fx = dims.w - 1;
      if (fy >= dims.h) fy = dims.h - 1;
      late final int sx;
      late final int sy;
      switch (r) {
        case 90:
          sx = fy;
          sy = height - 1 - fx;
          break;
        case 180:
          sx = width - 1 - fx;
          sy = height - 1 - fy;
          break;
        case 270:
          sx = width - 1 - fy;
          sy = fx;
          break;
        default:
          sx = fx;
          sy = fy;
      }
      if (sx < 0 || sx >= width || sy < 0 || sy >= height) return null;
      final y = nv21[sy * width + sx];
      final vuOff = yLen + (sy ~/ 2) * width + (sx ~/ 2) * 2;
      if (vuOff + 1 >= nv21.length) return null;
      final v = nv21[vuOff] - 128;
      final u = nv21[vuOff + 1] - 128;
      // Full-range BT.601 (sensor luma is full-range, not studio-swing).
      final rr = _clamp8((y + 1.402 * v).round());
      final gg = _clamp8((y - 0.344136 * u - 0.714136 * v).round());
      final bb = _clamp8((y + 1.772 * u).round());
      out.setPixelRgb(ux, uy, rr, gg, bb);
    }
  }
  return out;
}

/// JPEG bytes for the ML file fallback, or null when unbuildable.
Uint8List? nv21ToJpegBytes({
  required List<int> nv21,
  required int width,
  required int height,
  required int rotationDeg,
  int quality = 80,
}) {
  final rgb = nv21ToRgbImage(
      nv21: nv21,
      width: width,
      height: height,
      rotationDeg: rotationDeg);
  if (rgb == null) return null;
  try {
    final out = img.encodeJpg(rgb, quality: quality);
    if (out.isEmpty) return null;
    return out;
  } catch (_) {
    return null;
  }
}

/// Upright, downscaled RGBA bytes for InputImage.fromBitmap (commons
/// 0.13+ bitmap path: raw RGBA -> ARGB Bitmap -> detector, bypassing
/// both the byte-array converter and file IO). Same pixels and rotation
/// math as [nv21ToRgbImage]; alpha is opaque. Returns bytes + upright
/// dims for the caller's metadata.
({Uint8List bytes, int w, int h})? nv21ToRgbaBytes({
  required List<int> nv21,
  required int width,
  required int height,
  required int rotationDeg,
}) {
  final rgb = nv21ToRgbImage(
      nv21: nv21,
      width: width,
      height: height,
      rotationDeg: rotationDeg);
  if (rgb == null) return null;
  final out = Uint8List(rgb.width * rgb.height * 4);
  var o = 0;
  for (var y = 0; y < rgb.height; y++) {
    for (var x = 0; x < rgb.width; x++) {
      final p = rgb.getPixel(x, y);
      out[o++] = p.r.toInt().clamp(0, 255);
      out[o++] = p.g.toInt().clamp(0, 255);
      out[o++] = p.b.toInt().clamp(0, 255);
      out[o++] = 255;
    }
  }
  return (bytes: out, w: rgb.width, h: rgb.height);
}
