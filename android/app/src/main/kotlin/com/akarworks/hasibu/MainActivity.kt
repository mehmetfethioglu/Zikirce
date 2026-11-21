package com.akarworks.hasibu

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val securityChannel = "com.akarworks.hasibu/security"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, securityChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "setSecureScreen") {
                    val enable = call.argument<Boolean>("secure")
                        ?: call.argument<Boolean>("enable")
                        ?: false
                    runOnUiThread {
                        try {
                            if (enable) {
                                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            } else {
                                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            }
                        } catch (e: Exception) {
                            android.util.Log.w("MainActivity", "setSecureScreen flag failed: ${e.message}")
                        }
                    }
                    result.success(true)
                } else {
                    result.notImplemented()
                }
            }
    }
}
