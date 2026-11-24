// Physical display metrics for true optotype sizing.
//
// A 6/6 letter subtends exactly 5 arc minutes at the test distance — but
// only if the app knows the screen's physical pixel density. Flutter does
// not expose xdpi/ydpi, so MainActivity serves them on
// `ocuscan.display/metrics`. When metrics are missing or non-positive the
// result is invalid and callers must fall back to approximate sizing and
// label the display uncalibrated (never silently treat points as arcmin).
import 'dart:math';

import 'package:flutter/services.dart';

/// Physical display density + pixel size. Invalid when the platform did
/// not report a positive xdpi/ydpi (desktop, tests, external displays).
class DisplayMetrics {
  final double xdpi;
  final double ydpi;
  final int densityDpi;
  final int widthPx;
  final int heightPx;

  const DisplayMetrics({
    required this.xdpi,
    required this.ydpi,
    required this.densityDpi,
    required this.widthPx,
    required this.heightPx,
  });

  const DisplayMetrics.invalid()
      : xdpi = 0,
        ydpi = 0,
        densityDpi = 0,
        widthPx = 0,
        heightPx = 0;

  bool get valid =>
      xdpi.isFinite && ydpi.isFinite && xdpi > 0 && ydpi > 0;

  /// Logical-pixel height of a letter subtending [arcMin] arc minutes at
  /// [distanceMm] viewing distance, using vertical density (letters are
  /// sized by height). Returns -1 when metrics are invalid.
  double logicalPixelsForArcMin({
    required double arcMin,
    required double distanceMm,
    required double devicePixelRatio,
  }) {
    if (!valid ||
        !arcMin.isFinite ||
        !distanceMm.isFinite ||
        !devicePixelRatio.isFinite ||
        arcMin <= 0 ||
        distanceMm <= 0 ||
        devicePixelRatio <= 0) {
      return -1;
    }
    final halfAngleRad = (arcMin / 60) * (pi / 180) / 2;
    final heightMm = 2 * distanceMm * tan(halfAngleRad);
    final physicalPx = heightMm / 25.4 * ydpi;
    return physicalPx / devicePixelRatio;
  }

  static DisplayMetrics fromMap(Map? m) {
    double d(Object? v) => v is num ? v.toDouble() : 0.0;
    int i(Object? v) => v is num ? v.toInt() : 0;
    if (m == null) return const DisplayMetrics.invalid();
    return DisplayMetrics(
      xdpi: d(m['xdpi']),
      ydpi: d(m['ydpi']),
      densityDpi: i(m['densityDpi']),
      widthPx: i(m['widthPx']),
      heightPx: i(m['heightPx']),
    );
  }
}

DisplayMetrics? _cache;

/// Fetch once per session; any failure yields an invalid (falsy) result.
Future<DisplayMetrics> fetchDisplayMetrics() async {
  final hit = _cache;
  if (hit != null) return hit;
  try {
    const channel = MethodChannel('ocuscan.display/metrics');
    final m = await channel.invokeMapMethod<String, dynamic>('getMetrics');
    _cache = DisplayMetrics.fromMap(m);
  } catch (_) {
    _cache = const DisplayMetrics.invalid();
  }
  return _cache!;
}
