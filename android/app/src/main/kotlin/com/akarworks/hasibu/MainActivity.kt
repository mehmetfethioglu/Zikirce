package com.akarworks.hasibu

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.print.PrintAttributes
import android.print.PrintManager
import android.view.WindowManager
import android.webkit.MimeTypeMap
import android.webkit.WebView
import android.webkit.WebViewClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val securityChannel = "com.akarworks.hasibu/security"
    private val printChannel = "com.akarworks.hasibu/print"
    private val filesChannel = "com.akarworks.hasibu/files"
    private val requestPickImage = 43701
    private var activePrintWebView: WebView? = null
    private var pendingImagePickResult: MethodChannel.Result? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, printChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "printHtml") {
                    val html = call.argument<String>("html")
                    val jobName = call.argument<String>("jobName") ?: "Hasibu_Belge"
                    val landscape = call.argument<Boolean>("landscape") ?: false
                    if (html.isNullOrBlank()) {
                        result.error("PRINT_ERROR", "Yazdırılacak HTML içeriği boş.", null)
                        return@setMethodCallHandler
                    }
                    runOnUiThread {
                        try {
                            val webView = WebView(this)
                            activePrintWebView = webView
                            webView.webViewClient = object : WebViewClient() {
                                override fun onPageFinished(view: WebView?, url: String?) {
                                    if (view == null) {
                                        activePrintWebView = null
                                        return
                                    }
                                    try {
                                        val printManager =
                                            getSystemService(Context.PRINT_SERVICE) as? PrintManager
                                        if (printManager != null) {
                                            val adapter = view.createPrintDocumentAdapter(jobName)
                                            val mediaSize = if (landscape) {
                                                PrintAttributes.MediaSize.ISO_A4.asLandscape()
                                            } else {
                                                PrintAttributes.MediaSize.ISO_A4
                                            }
                                            val attrs = PrintAttributes.Builder()
                                                .setMediaSize(mediaSize)
                                                .build()
                                            printManager.print(jobName, adapter, attrs)
                                        }
                                    } catch (e: Exception) {
                                        android.util.Log.w("MainActivity", "PrintManager failed: ${e.message}")
                                    } finally {
                                        activePrintWebView = null
                                    }
                                }
                            }
                            webView.loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
                            result.success(true)
                        } catch (e: Exception) {
                            activePrintWebView = null
                            result.error("PRINT_ERROR", e.message, null)
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, filesChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "pickImageFile") {
                    if (pendingImagePickResult != null) {
                        result.error("PICK_IN_PROGRESS", "Zaten bir dosya seçici açık.", null)
                        return@setMethodCallHandler
                    }
                    try {
                        pendingImagePickResult = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "image/*"
                        }
                        startActivityForResult(intent, requestPickImage)
                    } catch (e: Exception) {
                        pendingImagePickResult = null
                        result.error("PICK_ERROR", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != requestPickImage) return
        val pending = pendingImagePickResult
        pendingImagePickResult = null
        if (pending == null) return

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.success(null)
            return
        }

        val uri = data.data!!
        try {
            val mime = contentResolver.getType(uri)
            val ext = MimeTypeMap.getSingleton().getExtensionFromMimeType(mime) ?: "png"
            val outFile = File(cacheDir, "hasibu_picked_logo_${System.currentTimeMillis()}.$ext")
            contentResolver.openInputStream(uri)?.use { input ->
                FileOutputStream(outFile).use { output ->
                    input.copyTo(output)
                }
            } ?: run {
                pending.success(null)
                return
            }
            pending.success(outFile.absolutePath)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "pickImageFile copy failed: ${e.message}")
            pending.error("PICK_ERROR", e.message, null)
        }
    }
}
