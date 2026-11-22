package com.nazmul.nplay

import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nplay/brightness")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "get" -> {
                        val w = window.attributes.screenBrightness
                        if (w >= 0f) {
                            result.success(w.toDouble())
                        } else {
                            val s = try {
                                Settings.System.getInt(contentResolver, Settings.System.SCREEN_BRIGHTNESS) / 255.0
                            } catch (e: Exception) {
                                0.5
                            }
                            result.success(s)
                        }
                    }
                    "set" -> {
                        val v = (call.argument<Double>("v") ?: 0.5).toFloat().coerceIn(0.02f, 1.0f)
                        val lp = window.attributes
                        lp.screenBrightness = v
                        window.attributes = lp
                        result.success(null)
                    }
                    "reset" -> {
                        val lp = window.attributes
                        lp.screenBrightness = WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
                        window.attributes = lp
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
