package com.ocuscan.ocuscan.vision

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * JVM tests for the native frame contract + mapping math. No device,
 * no CameraX, no ML Kit — pure validation logic only.
 */
class VisionFrameValidatorTest {

    private fun facts(
        w: Int = 640,
        h: Int = 480,
        planes: Int = 2,
        lens: IntArray = intArrayOf(640 * 480, 640 * 480 / 2),
        strides: IntArray = intArrayOf(640, 640),
        rot: Int = 0,
        ts: Long = 123L,
    ) = VisionFrameValidator.validate(w, h, planes, lens, strides, rot, ts)

    @Test
    fun `valid NV21 passes on all rotations`() {
        for (r in listOf(0, 90, 180, 270, -90, 360)) {
            assertNull("rot=$r", facts(rot = r))
        }
    }

    @Test
    fun `bad dimensions rejected`() {
        assertEquals("bad-dimensions", facts(w = 0))
        assertEquals("bad-dimensions", facts(h = -1))
    }

    @Test
    fun `absurd size refused before allocation`() {
        assertEquals("frame-too-large", facts(w = 1 shl 20, h = 1 shl 20))
    }

    @Test
    fun `plane count bounds enforced`() {
        assertEquals(
            "bad-plane-count",
            VisionFrameValidator.validate(64, 48, 0, intArrayOf(), intArrayOf(), 0, 1),
        )
        assertEquals(
            "bad-plane-count",
            VisionFrameValidator.validate(
                64, 48, 5,
                intArrayOf(1, 1, 1, 1, 1), intArrayOf(1, 1, 1, 1, 1), 0, 1,
            ),
        )
    }

    @Test
    fun `metadata length must match plane count`() {
        assertEquals(
            "plane-metadata-mismatch",
            VisionFrameValidator.validate(64, 48, 2, intArrayOf(100), intArrayOf(64, 64), 0, 1),
        )
        assertEquals(
            "plane-metadata-mismatch",
            VisionFrameValidator.validate(64, 48, 2, intArrayOf(100, 50), intArrayOf(64), 0, 1),
        )
    }

    @Test
    fun `empty plane and bad stride rejected`() {
        assertEquals(
            "empty-plane",
            VisionFrameValidator.validate(64, 48, 2, intArrayOf(0, 100), intArrayOf(64, 64), 0, 1),
        )
        assertEquals(
            "bad-stride",
            VisionFrameValidator.validate(
                64, 48, 2,
                intArrayOf(64 * 48, 64 * 48 / 2), intArrayOf(0, 64), 0, 1,
            ),
        )
    }

    @Test
    fun `bad rotation and timestamp rejected`() {
        assertEquals("bad-rotation", facts(rot = 45))
        assertEquals(
            "bad-timestamp",
            VisionFrameValidator.validate(
                64, 48, 2,
                intArrayOf(64 * 48, 64 * 48 / 2), intArrayOf(64, 64), 0, -1,
            ),
        )
    }

    @Test
    fun `normalizeBox clamps to unit range`() {
        val b = VisionFrameValidator.normalizeBox(160, 120, 480, 360, 640, 480)
        assertEquals(0.25, b["l"]!!, 1e-9)
        assertEquals(0.25, b["t"]!!, 1e-9)
        assertEquals(0.75, b["r"]!!, 1e-9)
        assertEquals(0.75, b["b"]!!, 1e-9)
        val c = VisionFrameValidator.normalizeBox(-10, -10, 9999, 9999, 640, 480)
        assertEquals(0.0, c["l"]!!, 1e-9)
        assertEquals(1.0, c["r"]!!, 1e-9)
    }

    @Test
    fun `uprightDims swaps on quarter turns`() {
        assertEquals(Pair(480, 720), VisionFrameValidator.uprightDims(720, 480, 270))
        assertEquals(Pair(720, 480), VisionFrameValidator.uprightDims(720, 480, 0))
        assertEquals(Pair(720, 480), VisionFrameValidator.uprightDims(720, 480, 180))
    }
}
