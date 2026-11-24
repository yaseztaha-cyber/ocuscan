package com.ocuscan.ocuscan

import com.ocuscan.ocuscan.vision.UniversalVisionEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-local native vision engine (CameraX + bundled ML Kit).
        // Registered manually: it is not a pub plugin.
        flutterEngine.plugins.add(UniversalVisionEngine())
        // Physical display metrics for true optotype sizing in Vision Lab.
        // Uses application resources metrics (correct for phones; external
        // displays may differ and are then labeled uncalibrated client-side
        // when xdpi/ydpi are missing or non-positive).
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ocuscan.display/metrics",
        ).setMethodCallHandler { call, result ->
            if (call.method == "getMetrics") {
                try {
                    val dm = applicationContext.resources.displayMetrics
                    result.success(
                        mapOf(
                            "xdpi" to dm.xdpi.toDouble(),
                            "ydpi" to dm.ydpi.toDouble(),
                            "densityDpi" to dm.densityDpi,
                            "widthPx" to dm.widthPixels,
                            "heightPx" to dm.heightPixels,
                        ),
                    )
                } catch (e: Exception) {
                    result.error("METRICS", e.toString(), null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}
