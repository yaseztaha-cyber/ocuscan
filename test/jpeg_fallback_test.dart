// JPEG-file ML fallback tests: pure pixel math (downscale, explicit
// rotation, YUV->RGB) plus the file-latch rule. No plugins, no camera.
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:ocuscan/features/camera/jpeg_fallback.dart';

/// Canonical NV21 buffer: Y = [yOf], VU interleaved neutral (128,128)
// so R=G=B=Y exactly.
List<int> _grayNv21(
    int w, int h, int Function(int x, int y) yOf) {
  final out = List<int>.filled(w * h * 3 ~/ 2, 128);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      out[y * w + x] = yOf(x, y);
    }
  }
  return out;
}

void main() {
  group('fallbackScaleFor', () {
    test('720p -> 2, small stays 1, 1080p -> 4', () {
      expect(fallbackScaleFor(720, 480), 2);
      expect(fallbackScaleFor(320, 240), 1);
      expect(fallbackScaleFor(480, 360), 1);
      expect(fallbackScaleFor(1920, 1080), 4);
    });
    test('degenerate dims -> 1 (never 0)', () {
      expect(fallbackScaleFor(0, 480), 1);
      expect(fallbackScaleFor(-5, 10), 1);
    });
  });

  group('uprightDimsFor', () {
    test('90/270 swap, 0/180 keep, negatives normalize', () {
      expect(uprightDimsFor(720, 480, 270), (w: 480, h: 720));
      expect(uprightDimsFor(720, 480, 90), (w: 480, h: 720));
      expect(uprightDimsFor(720, 480, 0), (w: 720, h: 480));
      expect(uprightDimsFor(720, 480, 180), (w: 720, h: 480));
      expect(uprightDimsFor(640, 480, -90), (w: 480, h: 640));
    });
  });

  group('shouldLatchFileFallback', () {
    test('latches after persistent converter failure under YV12+bitmap', () {
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: true,
              fileLatched: false,
              converterError: true),
          true);
    });
    test('stays off in every other case', () {
      // Bitmap rung not engaged yet: it goes before file.
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 50,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: false,
              fileLatched: false,
              converterError: true),
          false);
      // YV12 latch never engaged: declaration fallback goes first.
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 50,
              framesProcessed: 0,
              yv12Latched: false,
              bitmapLatched: false,
              fileLatched: false,
              converterError: true),
          false);
      // Already latched: mlDegraded takes over.
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: true,
              fileLatched: true,
              converterError: true),
          false);
      // Below gate / frames flowing / non-converter error.
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 9,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: true,
              fileLatched: false,
              converterError: true),
          false);
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 10,
              framesProcessed: 2,
              yv12Latched: true,
              bitmapLatched: true,
              fileLatched: false,
              converterError: true),
          false);
      expect(
          shouldLatchFileFallback(
              consecMlErrors: 10,
              framesProcessed: 0,
              yv12Latched: true,
              bitmapLatched: true,
              fileLatched: false,
              converterError: false),
          false);
    });
  });

  group('nv21ToRgbImage rotation is exact', () {
    test('rot0 identity with gray ramp', () {
      const w = 4, h = 2;
      final buf = _grayNv21(w, h, (x, y) => x + y * 10);
      final im = nv21ToRgbImage(
          nv21: buf, width: w, height: h, rotationDeg: 0);
      expect(im, isNotNull);
      expect(im!.width, w);
      expect(im.height, h);
      expect(im.getPixel(0, 0).r, 0);
      expect(im.getPixel(3, 0).r, 3);
      expect(im.getPixel(0, 1).r, 10);
      expect(im.getPixel(3, 1).r, 13);
    });

    test('rot270 maps source (W-1-uy, ux): corners verified', () {
      // 4x2 source, distinct luma; upright must be 2x4 with
      // upright(0,0) == source(3,0) and upright(1,3) == source(0,1).
      const w = 4, h = 2;
      final buf = _grayNv21(w, h, (x, y) => x + y * 10);
      final im = nv21ToRgbImage(
          nv21: buf, width: w, height: h, rotationDeg: 270);
      expect(im, isNotNull);
      expect(im!.width, 2);
      expect(im.height, 4);
      expect(im.getPixel(0, 0).r, 3);
      expect(im.getPixel(1, 0).r, 13);
      expect(im.getPixel(0, 3).r, 0);
      expect(im.getPixel(1, 3).r, 10);
    });

    test('rot90 and rot180 corners verified', () {
      const w = 4, h = 2;
      final buf = _grayNv21(w, h, (x, y) => x + y * 10);
      final p90 = nv21ToRgbImage(
          nv21: buf, width: w, height: h, rotationDeg: 90);
      expect(p90, isNotNull);
      expect(p90!.width, 2);
      expect(p90.height, 4);
      // Upright (0,0) <- source (0, H-1) = (0,1) = 10.
      expect(p90.getPixel(0, 0).r, 10);
      // Upright (1,3) <- source (3, H-1-1)=(3,0) = 3.
      expect(p90.getPixel(1, 3).r, 3);
      final p180 = nv21ToRgbImage(
          nv21: buf, width: w, height: h, rotationDeg: 180);
      expect(p180, isNotNull);
      expect(p180!.width, 4);
      expect(p180.height, 2);
      expect(p180.getPixel(0, 0).r, 13);
      expect(p180.getPixel(3, 1).r, 0);
    });

    test('field dims downscale: 720x480 rot270 -> 240x360 RGB', () {
      const w = 720, h = 480;
      final buf = _grayNv21(w, h, (x, y) => (x + y) % 200);
      final im = nv21ToRgbImage(
          nv21: buf, width: w, height: h, rotationDeg: 270);
      expect(im, isNotNull);
      expect(im!.width, 240);
      expect(im.height, 360);
    });

    test('refuses short buffers, bad rotation, absurd dims', () {
      expect(
          nv21ToRgbImage(
              nv21: List.filled(100, 0),
              width: 16,
              height: 16,
              rotationDeg: 0),
          isNull);
      expect(
          nv21ToRgbImage(
              nv21: List.filled(16 * 16 * 3 ~/ 2, 0),
              width: 16,
              height: 16,
              rotationDeg: 45),
          isNull);
      expect(
          nv21ToRgbImage(
              nv21: const [1, 2, 3], width: 0, height: 8, rotationDeg: 0),
          isNull);
      expect(
          nv21ToRgbImage(
              nv21: const [1, 2, 3],
              width: 1 << 20,
              height: 1 << 20,
              rotationDeg: 0),
          isNull);
    });
  });

  group('nv21ToJpegBytes', () {
    test('emits decodable JPEG at upright dims', () {
      const w = 16, h = 8;
      final buf = _grayNv21(w, h, (x, y) => 100 + ((x + y) % 100));
      final jpg = nv21ToJpegBytes(
          nv21: buf, width: w, height: h, rotationDeg: 270);
      expect(jpg, isNotNull);
      expect(jpg![0], 0xFF);
      expect(jpg[1], 0xD8);
      final decoded = img.decodeImage(jpg);
      expect(decoded, isNotNull);
      // Upright 8x16 (no downscale: longest side 16 < 480).
      expect(decoded!.width, 8);
      expect(decoded.height, 16);
    });

    test('null on unbuildable input', () {
      expect(
          nv21ToJpegBytes(
              nv21: List.filled(10, 0),
              width: 16,
              height: 16,
              rotationDeg: 0),
          isNull);
    });
  });

  group('nv21ToRgbaBytes (bitmap input rung)', () {
    test('white stays white, black stays black, alpha opaque', () {
      // 2x2: Y=235 white-ish top row, Y=16 black-ish bottom row.
      const w = 2, h = 2;
      final nv21 = <int>[
        235, 235,
        16, 16,
        128, 128, // VU neutral
      ];
      final out = nv21ToRgbaBytes(
          nv21: nv21, width: w, height: h, rotationDeg: 0);
      expect(out, isNotNull);
      expect(out!.w, w);
      expect(out.h, h);
      expect(out.bytes.length, w * h * 4);
      // Top-left white: R=G=B high, alpha 255.
      expect(out.bytes[0], greaterThan(200));
      expect(out.bytes[1], greaterThan(200));
      expect(out.bytes[2], greaterThan(200));
      expect(out.bytes[3], 255);
      // Bottom-left black: channels low, alpha still 255.
      final o = (1 * w + 0) * 4;
      expect(out.bytes[o], lessThan(30));
      expect(out.bytes[o + 1], lessThan(30));
      expect(out.bytes[o + 2], lessThan(30));
      expect(out.bytes[o + 3], 255);
    });

    test('rot270 upright dims match the JPEG builder', () {
      const w = 16, h = 8;
      final nv21 = List<int>.filled(w * h * 3 ~/ 2, 128);
      final out = nv21ToRgbaBytes(
          nv21: nv21, width: w, height: h, rotationDeg: 270);
      expect(out, isNotNull);
      expect(out!.w, 8);
      expect(out.h, 16);
      expect(out.bytes.length, 8 * 16 * 4);
    });

    test('null on unbuildable input', () {
      expect(
          nv21ToRgbaBytes(
              nv21: List.filled(10, 0),
              width: 16,
              height: 16,
              rotationDeg: 0),
          isNull);
    });
  });
}
