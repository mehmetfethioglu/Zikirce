package com.akarworks.cuedeck

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.speech.RecognizerIntent
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.interfaces.RSAPrivateKey
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

class MainActivity : FlutterActivity() {
    private val voiceChannelName = "com.akarworks.cuedeck/voice"
    private val storageChannelName = "com.akarworks.cuedeck/storage"
    private val notificationChannelName = "com.akarworks.cuedeck/notifications"

    private val speechRequestCode = 4041
    private val saveBackupRequestCode = 4042
    private val pickBackupRequestCode = 4043
    private val notificationPermissionRequestCode = 4044

    private val keyStoreProvider = "AndroidKeyStore"
    private val masterKeyAlias = "CueDeck_Master_AES_Key"
    private val adbRsaVaultFileName = "cuedeck_adb_rsa.vault"
    private val maxBackupBytes = 2 * 1024 * 1024 // 2 MB DoS guard

    private var pendingVoiceResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveContent: String? = null
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingNotificationPermResult: MethodChannel.Result? = null
    private var pendingImmediateNotification: Map<String, Any?>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 1. Voice Recognition Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            voiceChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVoiceRecognition" -> {
                    if (pendingVoiceResult != null) {
                        result.error("BUSY", "Ses tanıma zaten aktif", null)
                        return@setMethodCallHandler
                    }
                    val locale = call.argument<String>("locale") ?: "tr-TR"
                    try {
                        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                            putExtra(
                                RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                                RecognizerIntent.LANGUAGE_MODEL_FREE_FORM
                            )
                            putExtra(RecognizerIntent.EXTRA_LANGUAGE, locale)
                            putExtra(
                                RecognizerIntent.EXTRA_PROMPT,
                                "TV için sesli komut veya arama söyleyin..."
                            )
                            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
                        }
                        pendingVoiceResult = result
                        startActivityForResult(intent, speechRequestCode)
                    } catch (e: Exception) {
                        pendingVoiceResult = null
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 2. Secure KeyStore, ADB RSA-2048 Vault & SAF Backup Storage Channel
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            storageChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "encryptSecret" -> {
                    val plainText = call.argument<String>("plainText")
                    if (plainText.isNullOrEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(encryptWithKeyStore(plainText))
                }
                "decryptSecret" -> {
                    val cipherText = call.argument<String>("cipherText")
                    if (cipherText.isNullOrEmpty()) {
                        result.success(null)
                        return@setMethodCallHandler
                    }
                    result.success(decryptWithKeyStore(cipherText))
                }
                "getOrCreateAdbRsaKeyPair" -> {
                    result.success(getOrCreateAdbRsaKeyPair())
                }
                "getAppDocsPath" -> {
                    result.success(filesDir.absolutePath)
                }
                "saveBackupFile" -> {
                    if (pendingSaveResult != null) {
                        result.error("BUSY", "Dosya kaydetme işlemi zaten aktif", null)
                        return@setMethodCallHandler
                    }
                    val rawName = call.argument<String>("fileName") ?: "CueDeck_Backup.json"
                    val safeName = rawName.replace(Regex("[^a-zA-Z0-9._-]"), "_")
                    val content = call.argument<String>("content") ?: ""
                    val contentBytes = content.toByteArray(Charsets.UTF_8)
                    if (contentBytes.size > maxBackupBytes) {
                        result.error(
                            "PAYLOAD_TOO_LARGE",
                            "Yedek verisi 2 MB güvenlik sınırını aşıyor.",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    // Always keep a copy in app-private filesDir
                    try {
                        File(filesDir, safeName).writeBytes(contentBytes)
                    } catch (_: Exception) {
                    }

                    try {
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, safeName)
                        }
                        pendingSaveContent = content
                        pendingSaveResult = result
                        startActivityForResult(intent, saveBackupRequestCode)
                    } catch (e: Exception) {
                        pendingSaveContent = null
                        pendingSaveResult = null
                        result.success(File(filesDir, safeName).absolutePath)
                    }
                }
                "pickBackupFile" -> {
                    if (pendingPickResult != null) {
                        result.error("BUSY", "Dosya seçme işlemi zaten aktif", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(
                                Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/plain", "application/octet-stream")
                            )
                        }
                        pendingPickResult = result
                        startActivityForResult(intent, pickBackupRequestCode)
                    } catch (e: Exception) {
                        pendingPickResult = null
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Real Android OS Notifications & Scheduled Watch Alarms Channel
        CueDeckNotificationHelper.ensureChannel(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            notificationChannelName
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= 33) {
                        if (CueDeckNotificationHelper.hasNotificationPermission(this)) {
                            result.success(true)
                        } else {
                            pendingNotificationPermResult = result
                            requestPermissions(
                                arrayOf("android.permission.POST_NOTIFICATIONS"),
                                notificationPermissionRequestCode
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                "showNotificationNow" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: 2001
                    val title = call.argument<String>("title") ?: "CueDeck İzleme Vakti"
                    val body = call.argument<String>("body") ?: ""
                    val subText = call.argument<String>("subText")
                    val cueId = call.argument<String>("cueId")

                    if (Build.VERSION.SDK_INT >= 33 &&
                        !CueDeckNotificationHelper.hasNotificationPermission(this)
                    ) {
                        pendingImmediateNotification = mapOf(
                            "notificationId" to notificationId,
                            "title" to title,
                            "body" to body,
                            "subText" to subText,
                            "cueId" to cueId
                        )
                        pendingNotificationPermResult = result
                        requestPermissions(
                            arrayOf("android.permission.POST_NOTIFICATIONS"),
                            notificationPermissionRequestCode
                        )
                    } else {
                        val ok = CueDeckNotificationHelper.showSystemNotification(
                            context = applicationContext,
                            notificationId = notificationId,
                            title = title,
                            body = body,
                            subText = subText,
                            cueId = cueId
                        )
                        result.success(ok)
                    }
                }
                "syncScheduledNotifications" -> {
                    val rawAlarms = call.argument<List<Map<String, Any?>>>("alarms") ?: emptyList()
                    val count = CueDeckNotificationHelper.syncScheduledAlarms(
                        applicationContext,
                        rawAlarms
                    )
                    result.success(count)
                }
                "cancelAllNotifications" -> {
                    CueDeckNotificationHelper.cancelPersistedAlarms(applicationContext)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getOrCreateAdbRsaKeyPair(): Map<String, String>? {
        return try {
            val vaultFile = File(filesDir, adbRsaVaultFileName)
            if (vaultFile.exists()) {
                val encrypted = vaultFile.readText(Charsets.UTF_8).trim()
                val decrypted = decryptWithKeyStore(encrypted)
                if (!decrypted.isNullOrEmpty() && decrypted.contains(":")) {
                    val parts = decrypted.split(":")
                    if (parts.size == 2 && parts[0].isNotEmpty() && parts[1].isNotEmpty()) {
                        return mapOf("nHex" to parts[0], "dHex" to parts[1])
                    }
                }
            }

            val kpg = KeyPairGenerator.getInstance("RSA")
            kpg.initialize(2048)
            val keyPair = kpg.genKeyPair()
            val privKey = keyPair.private as RSAPrivateKey
            val nHex = privKey.modulus.toString(16)
            val dHex = privKey.privateExponent.toString(16)

            val encryptedPayload = encryptWithKeyStore("$nHex:$dHex")
            if (!encryptedPayload.isNullOrEmpty()) {
                vaultFile.writeText(encryptedPayload, Charsets.UTF_8)
            }
            mapOf("nHex" to nHex, "dHex" to dHex)
        } catch (_: Exception) {
            null
        }
    }

    private fun getOrCreateSecretKey(): SecretKey {
        val keyStore = KeyStore.getInstance(keyStoreProvider).apply { load(null) }
        val existingEntry = keyStore.getEntry(masterKeyAlias, null) as? KeyStore.SecretKeyEntry
        if (existingEntry != null) {
            return existingEntry.secretKey
        }
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES,
            keyStoreProvider
        )
        val spec = KeyGenParameterSpec.Builder(
            masterKeyAlias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        keyGenerator.init(spec)
        return keyGenerator.generateKey()
    }

    private fun encryptWithKeyStore(plainText: String): String? {
        return try {
            val secretKey = getOrCreateSecretKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.ENCRYPT_MODE, secretKey)
            val iv = cipher.iv
            val cipherBytes = cipher.doFinal(plainText.toByteArray(Charsets.UTF_8))
            val combined = ByteArray(1 + iv.size + cipherBytes.size)
            combined[0] = iv.size.toByte()
            System.arraycopy(iv, 0, combined, 1, iv.size)
            System.arraycopy(cipherBytes, 0, combined, 1 + iv.size, cipherBytes.size)
            Base64.encodeToString(combined, Base64.NO_WRAP)
        } catch (_: Exception) {
            null
        }
    }

    private fun decryptWithKeyStore(cipherText: String): String? {
        return try {
            val combined = Base64.decode(cipherText, Base64.NO_WRAP)
            if (combined.size < 14) return null
            val ivSize = combined[0].toInt() and 0xFF
            if (ivSize < 12 || ivSize > 16 || combined.size <= 1 + ivSize) return null
            val iv = combined.copyOfRange(1, 1 + ivSize)
            val cipherBytes = combined.copyOfRange(1 + ivSize, combined.size)
            val secretKey = getOrCreateSecretKey()
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, secretKey, GCMParameterSpec(128, iv))
            val plainBytes = cipher.doFinal(cipherBytes)
            String(plainBytes, Charsets.UTF_8)
        } catch (_: Exception) {
            null
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            speechRequestCode -> {
                val callback = pendingVoiceResult
                pendingVoiceResult = null
                if (callback != null) {
                    if (resultCode == Activity.RESULT_OK && data != null) {
                        val matches = data.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                        val firstMatch = matches?.firstOrNull()?.trim()
                        callback.success(if (firstMatch.isNullOrEmpty()) null else firstMatch)
                    } else {
                        callback.success(null)
                    }
                }
            }
            saveBackupRequestCode -> {
                val callback = pendingSaveResult
                val content = pendingSaveContent
                pendingSaveResult = null
                pendingSaveContent = null
                if (callback != null) {
                    if (resultCode == Activity.RESULT_OK && data?.data != null && content != null) {
                        val uri = data.data!!
                        try {
                            contentResolver.openOutputStream(uri)?.use { out ->
                                out.write(content.toByteArray(Charsets.UTF_8))
                                out.flush()
                            }
                            callback.success(uri.toString())
                        } catch (e: Exception) {
                            callback.success(null)
                        }
                    } else {
                        callback.success(null)
                    }
                }
            }
            pickBackupRequestCode -> {
                val callback = pendingPickResult
                pendingPickResult = null
                if (callback != null) {
                    if (resultCode == Activity.RESULT_OK && data?.data != null) {
                        val uri = data.data!!
                        try {
                            contentResolver.openInputStream(uri)?.use { input ->
                                val buffer = ByteArrayOutputStream()
                                val chunk = ByteArray(8192)
                                var total = 0
                                var read: Int
                                while (input.read(chunk).also { read = it } != -1) {
                                    total += read
                                    if (total > maxBackupBytes) {
                                        callback.error(
                                            "FILE_TOO_LARGE",
                                            "Yedek dosyası 2 MB sınırını aşıyor.",
                                            null
                                        )
                                        return
                                    }
                                    buffer.write(chunk, 0, read)
                                }
                                val text = buffer.toString(Charsets.UTF_8.name())
                                callback.success(text)
                            } ?: callback.success(null)
                        } catch (e: Exception) {
                            callback.success(null)
                        }
                    } else {
                        callback.success(null)
                    }
                }
            }
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == notificationPermissionRequestCode) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == PackageManager.PERMISSION_GRANTED
            val callback = pendingNotificationPermResult
            val pendingNotif = pendingImmediateNotification
            pendingNotificationPermResult = null
            pendingImmediateNotification = null

            if (granted && pendingNotif != null) {
                val shown = CueDeckNotificationHelper.showSystemNotification(
                    context = applicationContext,
                    notificationId = (pendingNotif["notificationId"] as? Int) ?: 2001,
                    title = (pendingNotif["title"] as? String) ?: "CueDeck İzleme Vakti",
                    body = (pendingNotif["body"] as? String) ?: "",
                    subText = pendingNotif["subText"] as? String,
                    cueId = pendingNotif["cueId"] as? String
                )
                callback?.success(shown)
            } else {
                callback?.success(granted)
            }
        }
    }
}
