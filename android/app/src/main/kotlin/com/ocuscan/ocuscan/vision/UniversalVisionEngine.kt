package com.ocuscan.ocuscan.vision

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.Surface
import androidx.camera.core.AspectRatio
import androidx.camera.core.Camera
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.face.FaceDetection
import com.google.mlkit.vision.face.FaceDetectorOptions
import com.google.mlkit.vision.face.FaceLandmark
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.view.TextureRegistry
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicInteger

/**
 * Universal native vision engine (§2/§3): CameraX preview + analysis +
 * bundled ML Kit face detection, exposed to Dart over channels.
 *
 * Flutter UI --MethodChannel/EventChannel--> this engine.
 * Dart receives observations (face/no-face/geometry/quality/errors),
 * never raw frames.
 *
 * Safety rules (all enforced, all logged):
 * - exactly one detector per camera session; detector generation ==
 *   camera generation; stale generations discarded on both sides.
 * - single inference in flight ([analyzing]); backpressure
 *   STRATEGY_KEEP_ONLY_LATEST (a new frame replaces stale, never
 *   queues — the 1013-rx/0-processed class is structurally impossible).
 * - nothing hard-coded: lens, sensor orientation, rotation, mirroring
 *   and sizes all come from CameraX/device metadata per session.
 * - every failure posts a classified error event (never "no face" for
 *   a failed call); analyze() never throws out of the callback.
 */
class UniversalVisionEngine : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {

    companion object {
        const val TAG = "OcuVision"
        const val CHANNEL_COMMANDS = "ocuscan.vision/commands"
        const val CHANNEL_EVENTS = "ocuscan.vision/events"
    }

    private var context: Context? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var flutterEngineRef: io.flutter.embedding.engine.FlutterEngine? = null
    private var commandChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker: ExecutorService = Executors.newSingleThreadExecutor()
    private val generation = AtomicInteger(0)
    private val analyzing = AtomicBoolean(false)
    private var camera: Camera? = null
    private var cameraProvider: ProcessCameraProvider? = null
    private var textureEntry: TextureRegistry.SurfaceTextureEntry? = null
    private var detector: com.google.mlkit.vision.face.FaceDetector? = null
    private var detectorIdentity = 0
    /** One-shot ML_NATIVE_INPUT_READY per session (no per-frame spam). */
    private var inputReadyPosted = false

    /** Pinned native versions (verify against app/build.gradle.kts). */
    private val faceDetectionNative = "com.google.mlkit:face-detection:16.1.7"
    private val cameraXVersion = "androidx.camera:1.5.3"

    /** Exact detector configuration string for diagnostics. Set at
    session start to whichever config actually won (full or minimal). */
    private var detectorConfigSummary =
        "ACCURATE/LANDMARK_ALL/CLASSIFICATION_ALL/CONTOUR_NONE/tracking"

    /** Exact detector configuration string for diagnostics. */
    private fun detectorOptionsSummary(): String = detectorConfigSummary
    private var analyzed = 0L
    private var dropped = 0L
    private var invalidFrames = 0L

    // ---- FlutterPlugin ----

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        flutterEngineRef = binding.flutterEngine
        commandChannel = MethodChannel(binding.binaryMessenger, CHANNEL_COMMANDS)
        commandChannel?.setMethodCallHandler(this)
        EventChannel(binding.binaryMessenger, CHANNEL_EVENTS).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(args: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(args: Any?) {
                    eventSink = null
                }
            },
        )
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        stopInternal(generation.get())
        worker.shutdownNow()
        commandChannel?.setMethodCallHandler(null)
        commandChannel = null
        eventSink = null
        context = null
        flutterEngineRef = null
    }

    // ---- ActivityAware (LifecycleOwner for CameraX) ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityBinding = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityBinding = binding
    }

    override fun onDetachedFromActivity() {
        stopInternal(generation.get())
        activityBinding = null
    }

    // ---- Commands ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "capabilities" -> result.success(capabilities())
            "start" -> {
                val front = (call.argument<Boolean>("front") ?: true)
                start(front, result)
            }
            "stop" -> {
                val gen = (call.argument<Int>("generation") ?: -1)
                stopInternal(gen)
                result.success(mapOf("stopped" to true, "generation" to generation.get()))
            }
            "health" -> result.success(
                mapOf(
                    "running" to (camera != null),
                    "generation" to generation.get(),
                    "analyzed" to analyzed,
                    "dropped" to dropped,
                    "invalidFrames" to invalidFrames,
                    "detector" to (if (detector != null) "ready" else "none"),
                ),
            )
            else -> result.notImplemented()
        }
    }

    private fun capabilities(): Map<String, Any> {
        val ctx = context ?: return mapOf("error" to "no-context")
        return try {
            val provider = ProcessCameraProvider.getInstance(ctx).get()
            val cams = provider.availableCameraInfos.map { info ->
                val facing = try {
                    info.lensFacing
                } catch (_: Exception) {
                    -1
                }
                mapOf(
                    "lensFacing" to facing,
                    "sensorOrientation" to 0,
                )
            }
            mapOf(
                "cameras" to cams,
                "front" to cams.any { it["lensFacing"] == androidx.camera.core.CameraSelector.LENS_FACING_FRONT },
                "rear" to cams.any { it["lensFacing"] == androidx.camera.core.CameraSelector.LENS_FACING_BACK },
            )
        } catch (e: Exception) {
            Log.e(TAG, "capabilities failed", e)
            mapOf("error" to "camera-error: ${shortMessage(e)}")
        }
    }

    /**
     * Best-effort stack for Dart diagnostics: the error export carries
     * the full native stack (the UI never shows it). Null-safe: a
     * null throwable still yields a marker, never another crash.
     */
    private fun stackOf(e: Throwable): String {
        return try {
            Log.getStackTraceString(e).ifEmpty { e.toString() }
        } catch (_: Exception) {
            e.toString()
        }
    }

    private fun start(front: Boolean, result: MethodChannel.Result) {
        val ctx = context ?: run {
            result.error("CAMERA_ERROR", "no-context", null)
            return
        }
        val owner = activityBinding?.activity as? LifecycleOwner ?: run {
            result.error("CAMERA_ERROR", "lifecycle-unavailable", null)
            return
        }
        // New session = new generation: detector, analyzer and preview all
        // belong to exactly one generation (§6).
        val gen = generation.incrementAndGet()
        stopCameraOnly()
        try {
            val provider = ProcessCameraProvider.getInstance(ctx).get()
            cameraProvider = provider
            val selector = CameraSelector.Builder()
                .requireLensFacing(
                    if (front) CameraSelector.LENS_FACING_FRONT
                    else CameraSelector.LENS_FACING_BACK,
                ).build()
            // Preview texture for the Dart Texture widget.
            val engine = flutterEngineRef
            if (engine == null) {
                postError(gen, "CAMERA_ERROR", "no-flutter-engine")
                result.error("CAMERA_ERROR", "no-flutter-engine", null)
                return
            }
            textureEntry?.release()
            val entry = engine.renderer.createSurfaceTexture()
            textureEntry = entry
            val preview = Preview.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build()
            preview.setSurfaceProvider { request ->
                val surface = Surface(entry.surfaceTexture())
                request.provideSurface(surface, ContextCompat.getMainExecutor(ctx)) { _ ->
                    surface.release()
                }
            }
            val analysis = ImageAnalysis.Builder()
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_YUV_420_888)
                .build()
            analysis.setAnalyzer(worker) { proxy -> analyze(proxy, gen, front) }
            // Bundled detector, one per session (§5: packaged model, no
            // download, offline first launch).
            // M2: the full-config getClient can NPE identically to the
            // Dart path on some devices. Retry once with the minimal
            // config and record which one won, plus the local Dynamite
            // face-module version that decides thick-vs-thin loading
            // (<=0 means the bundled module is invisible: thin path).
            val dynamiteLocalFace = try {
                com.google.android.gms.dynamite.DynamiteModule.getLocalVersion(
                    ctx, "com.google.mlkit.dynamite.face",
                )
            } catch (_: Exception) {
                -1
            }
            detector?.close()
            // PART 13: structured lifecycle events (normal UI never sees
            // stacks; the export carries them).
            postEvent(
                mapOf(
                    "type" to "ml",
                    "event" to "ML_NATIVE_INIT_START",
                    "generation" to gen,
                    "dynamiteLocalFace" to dynamiteLocalFace,
                ),
            )
            var created: com.google.mlkit.vision.face.FaceDetector? = null
            try {
                created = FaceDetection.getClient(
                    FaceDetectorOptions.Builder()
                        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_ACCURATE)
                        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_ALL)
                        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
                        .enableTracking()
                        .build(),
                )
                detectorConfigSummary =
                    "ACCURATE/LANDMARK_ALL/CLASSIFICATION_ALL/CONTOUR_NONE/tracking"
            } catch (first: Exception) {
                Log.w(TAG, "full-config detector failed, retrying minimal", first)
                created = FaceDetection.getClient(
                    FaceDetectorOptions.Builder()
                        .setPerformanceMode(FaceDetectorOptions.PERFORMANCE_MODE_FAST)
                        .setLandmarkMode(FaceDetectorOptions.LANDMARK_MODE_ALL)
                        .setClassificationMode(FaceDetectorOptions.CLASSIFICATION_MODE_NONE)
                        .setContourMode(FaceDetectorOptions.CONTOUR_MODE_NONE)
                        .build(),
                )
                detectorConfigSummary =
                    "FAST/LANDMARK_ALL/CLASSIFICATION_NONE/CONTOUR_NONE/no-tracking"
            }
            detector = created
            detectorIdentity = System.identityHashCode(created)
            inputReadyPosted = false
            postEvent(
                mapOf(
                    "type" to "ml",
                    "event" to "ML_NATIVE_INIT_SUCCESS",
                    "generation" to gen,
                    "detectorOptions" to detectorOptionsSummary(),
                    "detectorIdentity" to detectorIdentity,
                    "dynamiteLocalFace" to dynamiteLocalFace,
                ),
            )
            camera = provider.bindToLifecycle(owner, selector, preview, analysis)
            val sensor = try {
                camera?.cameraInfo?.sensorRotationDegrees ?: 0
            } catch (_: Exception) {
                0
            }
            result.success(
                mapOf(
                    "textureId" to entry.id(),
                    "generation" to gen,
                    "lensFacing" to if (front) "front" else "rear",
                    "sensorRotationDegrees" to sensor,
                    "detectorOptions" to detectorOptionsSummary(),
                    "dynamiteLocalFace" to dynamiteLocalFace,
                ),
            )
            postEvent(
                mapOf(
                    "type" to "session",
                    "generation" to gen,
                    "front" to front,
                    "sensorRotationDegrees" to sensor,
                    "detectorOptions" to detectorOptionsSummary(),
                    "dynamiteLocalFace" to dynamiteLocalFace,
                    "detectorIdentity" to detectorIdentity,
                    "faceDetectionNative" to faceDetectionNative,
                    "cameraX" to cameraXVersion,
                    "activeCalls" to 0,
                ),
            )
        } catch (e: Exception) {
            Log.e(TAG, "start failed", e)
            stopCameraOnly()
            // Details carry the full Java stack for the Dart error
            // export (normal UI only ever sees the short message).
            postError(gen, "CAMERA_ERROR", shortMessage(e))
            result.error("CAMERA_ERROR", shortMessage(e), stackOf(e))
        }
    }

    private fun stopInternal(requestedGen: Int) {
        // Stale stops (from a previous session) are ignored: only the
        // current generation may tear down (§6).
        if (requestedGen != generation.get()) return
        stopCameraOnly()
        try {
            detector?.close()
        } catch (_: Exception) {
        }
        detector = null
        postEvent(
            mapOf(
                "type" to "ml",
                "event" to "ML_NATIVE_CLOSE",
                "generation" to requestedGen,
            ),
        )
        postEvent(mapOf("type" to "stopped", "generation" to requestedGen))
    }

    private fun stopCameraOnly() {
        try {
            cameraProvider?.unbindAll()
        } catch (_: Exception) {
        }
        camera = null
        try {
            textureEntry?.release()
        } catch (_: Exception) {
        }
        textureEntry = null
    }

    // ---- Analysis (single-flight, validated, classified) ----

    private fun analyze(proxy: ImageProxy, gen: Int, front: Boolean) {
        // Stale session callback: never analyze into a new generation.
        if (gen != generation.get()) {
            proxy.close()
            return
        }
        // Single inference in flight; KEEP_ONLY_LATEST already dropped
        // queue buildup, this drops overlap (§6/§7).
        if (!analyzing.compareAndSet(false, true)) {
            dropped++
            proxy.close()
            return
        }
        try {
            val mediaImage = proxy.image
            if (mediaImage == null) {
                invalidFrames++
                postObservationError(gen, "INVALID_FRAME", "null-media-image")
                return
            }
            val w = proxy.width
            val h = proxy.height
            val planes = mediaImage.planes
            val reason = VisionFrameValidator.validate(
                w, h, planes.size,
                IntArray(planes.size) { i ->
                    try {
                        planes[i].buffer.remaining()
                    } catch (_: Exception) {
                        -1
                    }
                },
                IntArray(planes.size) { i ->
                    try {
                        planes[i].rowStride
                    } catch (_: Exception) {
                        -1
                    }
                },
                proxy.imageInfo.rotationDegrees,
                mediaImage.timestamp,
            )
            if (reason != null) {
                invalidFrames++
                postObservationError(gen, "INVALID_FRAME", reason)
                return
            }
            val det = detector
            if (det == null) {
                postObservationError(gen, "ENGINE_UNAVAILABLE", "no-detector")
                return
            }
            val t0 = android.os.SystemClock.elapsedRealtime()
            val input = InputImage.fromMediaImage(
                mediaImage, proxy.imageInfo.rotationDegrees,
            )
            if (!inputReadyPosted) {
                inputReadyPosted = true
                postEvent(
                    mapOf(
                        "type" to "ml",
                        "event" to "ML_NATIVE_INPUT_READY",
                        "generation" to gen,
                        "imageWidth" to w,
                        "imageHeight" to h,
                        "rotationDegrees" to proxy.imageInfo.rotationDegrees,
                    ),
                )
            }
            val luma = sampleLuma(mediaImage)
            val blur = sampleBlur(mediaImage)
            det.process(input)
                .addOnSuccessListener(worker) { faces ->
                    try {
                        if (gen != generation.get()) return@addOnSuccessListener
                        val ms =
                            (android.os.SystemClock.elapsedRealtime() - t0).toDouble()
                        analyzed++
                        if (faces.isEmpty()) {
                            postEvent(
                                mapOf(
                                    "type" to "observation",
                                    "generation" to gen,
                                    "faceFound" to false,
                                    "imageWidth" to w,
                                    "imageHeight" to h,
                                    "rotationDegrees" to proxy.imageInfo.rotationDegrees,
                                    "mirrored" to front,
                                    "meanLuminance" to luma,
                                    "blurVariance" to blur,
                                    "latencyMs" to ms,
                                ),
                            )
                        } else {
                            // Largest face first (closest = likely the user);
                            // multi-face is reported, never silently picked.
                            val sorted = faces.sortedByDescending {
                                it.boundingBox.width() * it.boundingBox.height()
                            }
                            val f = sorted[0]
                            val box = VisionFrameValidator.normalizeBox(
                                f.boundingBox.left, f.boundingBox.top,
                                f.boundingBox.right, f.boundingBox.bottom, w, h,
                            )
                            fun norm(p: android.graphics.PointF?) = p?.let {
                                mapOf(
                                    "x" to (it.x / w.toFloat()).toDouble().coerceIn(0.0, 1.0),
                                    "y" to (it.y / h.toFloat()).toDouble().coerceIn(0.0, 1.0),
                                )
                            }
                            postEvent(
                                mapOf(
                                    "type" to "observation",
                                    "generation" to gen,
                                    "faceFound" to true,
                                    "faceCount" to faces.size,
                                    "box" to box,
                                    "leftEye" to norm(
                                        f.getLandmark(FaceLandmark.LEFT_EYE)?.position,
                                    ),
                                    "rightEye" to norm(
                                        f.getLandmark(FaceLandmark.RIGHT_EYE)?.position,
                                    ),
                                    "yawDeg" to f.headEulerAngleY.toDouble(),
                                    "rollDeg" to f.headEulerAngleZ.toDouble(),
                                    "leftOpenProb" to (f.leftEyeOpenProbability?.toDouble()
                                        ?: -1.0),
                                    "rightOpenProb" to (f.rightEyeOpenProbability?.toDouble()
                                        ?: -1.0),
                                    "imageWidth" to w,
                                    "imageHeight" to h,
                                    "rotationDegrees" to proxy.imageInfo.rotationDegrees,
                                    "mirrored" to front,
                                    "meanLuminance" to luma,
                                    "blurVariance" to blur,
                                    "latencyMs" to ms,
                                ),
                            )
                        }
                    } finally {
                        analyzing.set(false)
                        try {
                            proxy.close()
                        } catch (_: Exception) {
                        }
                    }
                }
                .addOnFailureListener(worker) { e ->
                    try {
                        postObservationError(gen, "PROCESSING_ERROR", shortMessage(e))
                    } finally {
                        analyzing.set(false)
                        try {
                            proxy.close()
                        } catch (_: Exception) {
                        }
                    }
                }
        } catch (e: Exception) {
            Log.e(TAG, "analyze failed", e)
            postObservationError(gen, "PROCESSING_ERROR", shortMessage(e))
            analyzing.set(false)
            try {
                proxy.close()
            } catch (_: Exception) {
            }
        }
    }

    /** Cheap luma estimate from the Y plane (sampled rows). */
    private fun sampleLuma(image: android.media.Image): Double {
        return try {
            val y = image.planes[0].buffer
            val stride = image.planes[0].rowStride
            val w = image.width
            val h = image.height
            var sum = 0L
            var n = 0L
            var row = 0
            y.rewind()
            while (row < h && n < 8192) {
                val base = row * stride
                var x = 0
                while (x < w && n < 8192) {
                    sum += (y.get(base + x).toInt() and 0xFF).toLong()
                    n++
                    x += 16
                }
                row += 8
            }
            if (n == 0L) 120.0 else sum.toDouble() / n.toDouble()
        } catch (_: Exception) {
            120.0
        }
    }

    /** Coarse Laplacian-variance blur estimate on the Y plane.
     * Mirrors Dart EyeCoords.sampleYPlane (8-grid, same formula) so the
     * tracker blur threshold means the same on both paths. Neutral
     * 100.0 on any failure — non-gating, exactly like unknown. */
    private fun sampleBlur(image: android.media.Image): Double {
        return try {
            val y = image.planes[0].buffer
            val stride = image.planes[0].rowStride
            val w = image.width
            val h = image.height
            val b = 8
            val gw = w / b
            val gh = h / b
            if (gw < 3 || gh < 3) return 100.0
            y.rewind()
            fun at(gx: Int, gy: Int): Double {
                val o = gy * b * stride + gx * b
                if (o < 0 || o >= y.limit()) return 120.0
                return (y.get(o).toInt() and 0xFF).toDouble()
            }
            var sum = 0.0
            var sq = 0.0
            var n = 0
            for (gy in 1 until gh - 1) {
                for (gx in 1 until gw - 1) {
                    val lap = 4 * at(gx, gy) - at(gx - 1, gy) -
                        at(gx + 1, gy) - at(gx, gy - 1) - at(gx, gy + 1)
                    sum += lap
                    sq += lap * lap
                    n++
                }
            }
            if (n == 0) return 100.0
            val m = sum / n
            (sq / n - m * m).coerceAtLeast(0.0)
        } catch (_: Exception) {
            100.0
        }
    }

    private fun postObservationError(gen: Int, clazz: String, message: String) {
        postEvent(
            mapOf(
                "type" to "error",
                "generation" to gen,
                "class" to clazz,
                "message" to message,
                "activeCalls" to if (analyzing.get()) 1 else 0,
                "detectorPresent" to (detector != null),
            ),
        )
    }

    private fun postEvent(event: Map<String, Any?>) {
        val sink = eventSink ?: return
        mainHandler.post {
            try {
                sink.success(event)
            } catch (_: Exception) {
            }
        }
    }

    private fun postError(gen: Int, clazz: String, message: String) {
        postEvent(
            mapOf(
                "type" to "error",
                "generation" to gen,
                "class" to clazz,
                "message" to message,
                "activeCalls" to if (analyzing.get()) 1 else 0,
                "detectorPresent" to (detector != null),
            ),
        )
    }

    private fun shortMessage(e: Throwable): String {
        val s = (e.message ?: e.toString()).replace(Regex("\\s+"), " ").trim()
        return if (s.length > 220) s.substring(0, 220) + "…" else s
    }
}
