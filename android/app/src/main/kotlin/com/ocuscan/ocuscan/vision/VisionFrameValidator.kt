package com.ocuscan.ocuscan.vision

/**
 * Pure frame-facts validation for the native vision engine (§4/§15).
 *
 * A frame is usable for ML ONLY when its observed facts satisfy an
 * explicit contract. Anything else is INVALID_FRAME with a stable
 * reason code — never a guess, never silent truncation.
 *
 * Zero Android dependencies: JVM unit-tested.
 */
object VisionFrameValidator {
    const val MAX_PIXELS: Long = 16L * 1024L * 1024L

    /**
     * Validate structural facts. Returns null when valid, else a stable
     * reason code: bad-dimensions | frame-too-large | bad-plane-count |
     * plane-metadata-mismatch | empty-plane | bad-stride | bad-rotation |
     * bad-timestamp.
     */
    @JvmStatic
    fun validate(
        width: Int,
        height: Int,
        planeCount: Int,
        planeLengths: IntArray,
        rowStrides: IntArray,
        rotationDeg: Int,
        timestampMs: Long,
    ): String? {
        if (width <= 0 || height <= 0) return "bad-dimensions"
        if (width.toLong() * height.toLong() > MAX_PIXELS) return "frame-too-large"
        if (planeCount <= 0 || planeCount > 4) return "bad-plane-count"
        if (planeLengths.size != planeCount || rowStrides.size != planeCount) {
            return "plane-metadata-mismatch"
        }
        for (i in 0 until planeCount) {
            if (planeLengths[i] <= 0) return "empty-plane"
            if (rowStrides[i] <= 0) return "bad-stride"
        }
        val r = ((rotationDeg % 360) + 360) % 360
        if (r != 0 && r != 90 && r != 180 && r != 270) return "bad-rotation"
        if (timestampMs < 0) return "bad-timestamp"
        return null
    }

    /**
     * Normalize an image-space pixel box to 0..1 fractions for the Dart
     * overlay mapper. Pure arithmetic; out-of-range inputs clamp.
     */
    @JvmStatic
    fun normalizeBox(
        left: Int,
        top: Int,
        right: Int,
        bottom: Int,
        width: Int,
        height: Int,
    ): Map<String, Double> {
        if (width <= 0 || height <= 0) {
            return mapOf("l" to 0.0, "t" to 0.0, "r" to 0.0, "b" to 0.0)
        }
        fun n(v: Int, m: Int) = (v.toDouble() / m.toDouble()).coerceIn(0.0, 1.0)
        return mapOf(
            "l" to n(left, width),
            "t" to n(top, height),
            "r" to n(right, width),
            "b" to n(bottom, height),
        )
    }

    /**
     * Upright (display-order) dimensions after clockwise rotation.
     * Returns Pair(uprightWidth, uprightHeight).
     */
    @JvmStatic
    fun uprightDims(width: Int, height: Int, rotationDeg: Int): Pair<Int, Int> {
        val r = ((rotationDeg % 360) + 360) % 360
        return if (r == 90 || r == 270) Pair(height, width) else Pair(width, height)
    }
}
