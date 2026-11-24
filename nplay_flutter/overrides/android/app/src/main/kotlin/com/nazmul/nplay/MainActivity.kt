package com.nazmul.nplay

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import android.provider.OpenableColumns
import android.provider.Settings
import android.view.WindowManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : AudioServiceActivity() {
    private var openChannel: MethodChannel? = null

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

        // Lets a "Rescan" tap force Android's MediaStore to (re)index new
        // files, so freshly downloaded / copied videos show up right away.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nplay/mediascan")
            .setMethodCallHandler { call, result ->
                if (call.method == "scan") {
                    try {
                        val roots = listOf(
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES).path,
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS).path,
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DCIM).path,
                            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC).path,
                            Environment.getExternalStorageDirectory().path,
                        )
                        MediaScannerConnection.scanFile(applicationContext, roots.toTypedArray(), null, null)
                    } catch (e: Exception) {
                        // ignore, this is best-effort
                    }
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }

        // Handles the app being opened via "Open with" on a video/audio
        // file from another app (file manager, VidMate, etc.).
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "nplay/open")
        openChannel = ch
        ch.setMethodCallHandler { call, result ->
            if (call.method == "getInitial") {
                result.success(resolveIncomingPath(intent))
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val p = resolveIncomingPath(intent)
        if (p != null) {
            openChannel?.invokeMethod("open", p)
        }
    }

    private fun resolveIncomingPath(intent: Intent?): String? {
        if (intent == null) return null
        val action = intent.action
        if (action != Intent.ACTION_VIEW && action != Intent.ACTION_SEND) return null
        @Suppress("DEPRECATION")
        val uri: Uri = (if (action == Intent.ACTION_SEND)
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        else
            intent.data) ?: return null
        return resolvePath(uri)
    }

    private fun resolvePath(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        // Try the legacy "_data" column first (works on many devices/providers
        // without copying the file).
        try {
            contentResolver.query(uri, arrayOf("_data"), null, null, null)?.use { c ->
                val idx = c.getColumnIndex("_data")
                if (idx >= 0 && c.moveToFirst()) {
                    val p = c.getString(idx)
                    if (!p.isNullOrEmpty() && File(p).exists()) return p
                }
            }
        } catch (e: Exception) {
            // fall through to copy
        }
        // Fallback: copy the content:// stream into our cache dir so the
        // player always has a real file path to open.
        return try {
            var name = "shared_media_" + System.currentTimeMillis()
            contentResolver.query(uri, null, null, null, null)?.use { c ->
                val idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (idx >= 0 && c.moveToFirst()) {
                    c.getString(idx)?.let { name = it }
                }
            }
            val out = File(cacheDir, name)
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(out).use { output -> input.copyTo(output) }
            }
            out.path
        } catch (e: Exception) {
            null
        }
    }
}
