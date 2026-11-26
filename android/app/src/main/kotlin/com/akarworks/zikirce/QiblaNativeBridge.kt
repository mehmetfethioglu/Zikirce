package com.akarworks.zikirce

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.abs
import kotlin.math.acos
import kotlin.math.atan2
import kotlin.math.sqrt

class QiblaNativeBridge(private val activity: Activity) :
    EventChannel.StreamHandler,
    SensorEventListener {

    companion object {
        private const val TAG = "ZikirceQibla"
        const val REQUEST_CODE_QIBLA_LOCATION = 4107
        private const val EMIT_INTERVAL_MS = 33L
        private const val MAX_CACHE_AGE_MS = 10 * 60 * 1000L
        private const val LOCATION_TIMEOUT_MS = 10_000L
    }

    private val mainHandler = Handler(Looper.getMainLooper())

    // Compass sensor state
    private var sensorManager: SensorManager? = null
    private var rotationSensor: Sensor? = null
    private var accelSensor: Sensor? = null
    private var magSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private var isCompassListening = false
    private var lastEmitElapsedMs = 0L

    private val rotMatrix = FloatArray(9)
    private val orientation = FloatArray(3)
    private val accelValues = FloatArray(3)
    private val magValues = FloatArray(3)
    private var hasAccel = false
    private var hasMag = false
    private var latestFieldUt = 0.0
    private var needsCalibration = false

    // Location state
    private var pendingLocationResult: MethodChannel.Result? = null
    private var locationTimeoutRunnable: Runnable? = null
    private var cancellationSignal: CancellationSignal? = null
    private var activeLocationListener: LocationListener? = null

    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
        eventSink = events
        isCompassListening = true
        lastEmitElapsedMs = 0L
        hasAccel = false
        hasMag = false
        latestFieldUt = 0.0
        needsCalibration = false

        val manager = activity.getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        sensorManager = manager
        if (manager == null) {
            events.error("UNAVAILABLE", "SensorManager unavailable", null)
            return
        }

        val rot = manager.getDefaultSensor(Sensor.TYPE_ROTATION_VECTOR)
        val mag = manager.getDefaultSensor(Sensor.TYPE_MAGNETIC_FIELD)
        val accel = manager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)

        rotationSensor = rot
        magSensor = mag
        accelSensor = accel

        if (rot != null) {
            manager.registerListener(this, rot, SensorManager.SENSOR_DELAY_GAME)
            if (mag != null) {
                manager.registerListener(this, mag, SensorManager.SENSOR_DELAY_UI)
            }
        } else if (accel != null && mag != null) {
            manager.registerListener(this, accel, SensorManager.SENSOR_DELAY_GAME)
            manager.registerListener(this, mag, SensorManager.SENSOR_DELAY_GAME)
        } else {
            events.error("UNAVAILABLE", "Required compass sensors unavailable", null)
        }
    }

    override fun onCancel(arguments: Any?) {
        stopCompassSensors()
    }

    private fun stopCompassSensors() {
        isCompassListening = false
        eventSink = null
        try {
            sensorManager?.unregisterListener(this)
        } catch (e: Exception) {
            Log.w(TAG, "unregisterListener failed: ${e.message}")
        }
        rotationSensor = null
        accelSensor = null
        magSensor = null
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        if (sensor?.type == Sensor.TYPE_MAGNETIC_FIELD || sensor?.type == Sensor.TYPE_ROTATION_VECTOR) {
            needsCalibration =
                accuracy == SensorManager.SENSOR_STATUS_UNRELIABLE ||
                accuracy == SensorManager.SENSOR_STATUS_ACCURACY_LOW
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        if (!isCompassListening || eventSink == null) return

        when (event.sensor.type) {
            Sensor.TYPE_MAGNETIC_FIELD -> {
                magValues[0] = event.values[0]
                magValues[1] = event.values[1]
                magValues[2] = event.values[2]
                hasMag = true
                val fieldUt = sqrt(
                    (magValues[0] * magValues[0] +
                        magValues[1] * magValues[1] +
                        magValues[2] * magValues[2]).toDouble()
                )
                if (fieldUt.isFinite()) {
                    latestFieldUt = fieldUt
                }
                if (rotationSensor == null && hasAccel) {
                    computeAndEmitFromAccelMag()
                }
            }
            Sensor.TYPE_ACCELEROMETER -> {
                accelValues[0] = event.values[0]
                accelValues[1] = event.values[1]
                accelValues[2] = event.values[2]
                hasAccel = true
                if (rotationSensor == null && hasMag) {
                    computeAndEmitFromAccelMag()
                }
            }
            Sensor.TYPE_ROTATION_VECTOR -> {
                val nowMs = SystemClock.elapsedRealtime()
                if (nowMs - lastEmitElapsedMs < EMIT_INTERVAL_MS) return

                SensorManager.getRotationMatrixFromVector(rotMatrix, event.values)
                emitFromRotationMatrix(nowMs)
            }
        }
    }

    private fun computeAndEmitFromAccelMag() {
        val nowMs = SystemClock.elapsedRealtime()
        if (nowMs - lastEmitElapsedMs < EMIT_INTERVAL_MS) return

        val ok = SensorManager.getRotationMatrix(rotMatrix, null, accelValues, magValues)
        if (!ok) return
        emitFromRotationMatrix(nowMs)
    }

    private fun emitFromRotationMatrix(nowMs: Long) {
        SensorManager.getOrientation(rotMatrix, orientation)
        val rawDeg = Math.toDegrees(orientation[0].toDouble())
        val headingDeg = ((rawDeg % 360.0) + 360.0) % 360.0

        val r8 = rotMatrix[8].toDouble().coerceIn(-1.0, 1.0)
        val tiltDeg = Math.toDegrees(acos(r8))
        val safeZ = if (abs(r8) < 1e-4) (if (r8 < 0) -1e-4 else 1e-4) else r8
        val pitchDeg = Math.toDegrees(atan2(rotMatrix[7].toDouble(), safeZ))
        val rollDeg = Math.toDegrees(atan2(rotMatrix[6].toDouble(), safeZ))

        if (!headingDeg.isFinite() || !tiltDeg.isFinite()) return

        lastEmitElapsedMs = nowMs
        val payload = mapOf(
            "headingDeg" to headingDeg,
            "isTrueNorth" to false,
            "accuracyDeg" to -1.0,
            "tiltDeg" to tiltDeg,
            "pitchDeg" to pitchDeg,
            "rollDeg" to rollDeg,
            "magneticFieldUt" to latestFieldUt,
            "needsCalibration" to needsCalibration
        )

        mainHandler.post {
            if (isCompassListening) {
                eventSink?.success(payload)
            }
        }
    }

    fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getCurrentLocation" -> {
                val requestPermission = call.argument<Boolean>("requestPermission") ?: true
                getCurrentLocation(requestPermission, result)
            }
            "openLocationSettings" -> {
                result.success(openLocationSettings())
            }
            else -> result.notImplemented()
        }
    }

    private fun hasLocationPermission(): Boolean {
        val fine = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        val coarse = ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.ACCESS_COARSE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun getCurrentLocation(requestPermission: Boolean, result: MethodChannel.Result) {
        if (pendingLocationResult != null) {
            resolvePendingLocation(mapOf("status" to "unavailable"))
        }

        if (!hasLocationPermission()) {
            if (!requestPermission) {
                result.success(mapOf("status" to "denied"))
                return
            }
            pendingLocationResult = result
            ActivityCompat.requestPermissions(
                activity,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                ),
                REQUEST_CODE_QIBLA_LOCATION
            )
            return
        }

        pendingLocationResult = result
        fetchLocationAfterPermission()
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_QIBLA_LOCATION) return false
        if (pendingLocationResult == null) return true

        val granted = grantResults.any { it == PackageManager.PERMISSION_GRANTED } || hasLocationPermission()
        if (granted) {
            fetchLocationAfterPermission()
        } else {
            val canAskAgain =
                ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) ||
                ActivityCompat.shouldShowRequestPermissionRationale(
                    activity,
                    Manifest.permission.ACCESS_COARSE_LOCATION
                )
            resolvePendingLocation(
                mapOf("status" to if (canAskAgain) "denied" else "deniedForever")
            )
        }
        return true
    }

    private fun isLocationEnabled(manager: LocationManager): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            manager.isLocationEnabled
        } else {
            try {
                manager.isProviderEnabled(LocationManager.GPS_PROVIDER) ||
                    manager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
            } catch (e: Exception) {
                Log.w(TAG, "isProviderEnabled check failed: ${e.message}")
                false
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun fetchLocationAfterPermission() {
        val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        if (manager == null) {
            resolvePendingLocation(mapOf("status" to "unavailable"))
            return
        }

        if (!isLocationEnabled(manager)) {
            resolvePendingLocation(mapOf("status" to "serviceDisabled"))
            return
        }

        val nowEpochMs = System.currentTimeMillis()
        val bestRecent = findBestLastKnownLocation(manager)
        if (bestRecent != null &&
            (nowEpochMs - bestRecent.time) in 0..MAX_CACHE_AGE_MS &&
            bestRecent.accuracy <= 2000f
        ) {
            resolvePendingLocation(locationPayload(bestRecent))
            return
        }

        val provider = selectBestProvider(manager)
        if (provider == null) {
            if (bestRecent != null) {
                resolvePendingLocation(locationPayload(bestRecent))
            } else {
                resolvePendingLocation(mapOf("status" to "serviceDisabled"))
            }
            return
        }

        scheduleLocationTimeout(bestRecent)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val signal = CancellationSignal()
            cancellationSignal = signal
            try {
                manager.getCurrentLocation(
                    provider,
                    signal,
                    activity.mainExecutor
                ) { location ->
                    if (location != null) {
                        resolvePendingLocation(locationPayload(location))
                    } else if (bestRecent != null) {
                        resolvePendingLocation(locationPayload(bestRecent))
                    } else {
                        resolvePendingLocation(mapOf("status" to "timeout"))
                    }
                }
            } catch (e: Exception) {
                Log.w(TAG, "getCurrentLocation failed: ${e.message}")
                if (bestRecent != null) {
                    resolvePendingLocation(locationPayload(bestRecent))
                } else {
                    resolvePendingLocation(mapOf("status" to "unavailable"))
                }
            }
        } else {
            requestLegacySingleLocation(manager, provider, bestRecent)
        }
    }

    @SuppressLint("MissingPermission")
    @Suppress("DEPRECATION")
    private fun requestLegacySingleLocation(
        manager: LocationManager,
        provider: String,
        fallback: Location?
    ) {
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                resolvePendingLocation(locationPayload(location))
            }

            @Deprecated("Deprecated in Java")
            override fun onStatusChanged(p: String?, status: Int, extras: Bundle?) {}
            override fun onProviderEnabled(p: String) {}
            override fun onProviderDisabled(p: String) {}
        }
        activeLocationListener = listener
        try {
            manager.requestSingleUpdate(provider, listener, Looper.getMainLooper())
        } catch (e: Exception) {
            Log.w(TAG, "requestSingleUpdate failed: ${e.message}")
            if (fallback != null) {
                resolvePendingLocation(locationPayload(fallback))
            } else {
                resolvePendingLocation(mapOf("status" to "unavailable"))
            }
        }
    }

    @SuppressLint("MissingPermission")
    private fun findBestLastKnownLocation(manager: LocationManager): Location? {
        val providers = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(LocationManager.FUSED_PROVIDER)
            }
            add(LocationManager.GPS_PROVIDER)
            add(LocationManager.NETWORK_PROVIDER)
            add(LocationManager.PASSIVE_PROVIDER)
        }
        var best: Location? = null
        for (provider in providers) {
            try {
                val loc = manager.getLastKnownLocation(provider) ?: continue
                if (best == null || loc.time > best.time) {
                    best = loc
                }
            } catch (e: Exception) {
                Log.d(TAG, "getLastKnownLocation skipped for $provider: ${e.message}")
            }
        }
        return best
    }

    private fun selectBestProvider(manager: LocationManager): String? {
        val candidates = buildList {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                add(LocationManager.FUSED_PROVIDER)
            }
            add(LocationManager.NETWORK_PROVIDER)
            add(LocationManager.GPS_PROVIDER)
        }
        for (candidate in candidates) {
            try {
                if (manager.isProviderEnabled(candidate)) {
                    return candidate
                }
            } catch (e: Exception) {
                Log.d(TAG, "isProviderEnabled skipped for $candidate: ${e.message}")
            }
        }
        return null
    }

    private fun scheduleLocationTimeout(fallback: Location?) {
        locationTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        val runnable = Runnable {
            if (fallback != null) {
                resolvePendingLocation(locationPayload(fallback))
            } else {
                resolvePendingLocation(mapOf("status" to "timeout"))
            }
        }
        locationTimeoutRunnable = runnable
        mainHandler.postDelayed(runnable, LOCATION_TIMEOUT_MS)
    }

    private fun locationPayload(location: Location): Map<String, Any> {
        return mapOf(
            "status" to "granted",
            "latitude" to location.latitude,
            "longitude" to location.longitude,
            "accuracyMeters" to location.accuracy.toDouble()
        )
    }

    private fun resolvePendingLocation(payload: Map<String, Any>) {
        mainHandler.post {
            locationTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
            locationTimeoutRunnable = null

            cancellationSignal?.cancel()
            cancellationSignal = null

            activeLocationListener?.let { listener ->
                try {
                    val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    manager?.removeUpdates(listener)
                } catch (e: Exception) {
                    Log.w(TAG, "removeUpdates warning: ${e.message}")
                }
            }
            activeLocationListener = null

            val callback = pendingLocationResult
            pendingLocationResult = null
            callback?.success(payload)
        }
    }

    private fun openLocationSettings(): Boolean {
        val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
        val locationDisabled = manager != null && !isLocationEnabled(manager)

        if (locationDisabled) {
            try {
                val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                activity.startActivity(intent)
                return true
            } catch (e: Exception) {
                Log.w(TAG, "ACTION_LOCATION_SOURCE_SETTINGS failed: ${e.message}")
            }
        }

        return try {
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.parse("package:${activity.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            activity.startActivity(intent)
            true
        } catch (e: Exception) {
            Log.w(TAG, "ACTION_APPLICATION_DETAILS_SETTINGS failed: ${e.message}")
            false
        }
    }

    fun dispose() {
        stopCompassSensors()
        locationTimeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        locationTimeoutRunnable = null
        cancellationSignal?.cancel()
        cancellationSignal = null
        activeLocationListener?.let { listener ->
            try {
                val manager = activity.getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                manager?.removeUpdates(listener)
            } catch (e: Exception) {
                Log.w(TAG, "dispose removeUpdates warning: ${e.message}")
            }
        }
        activeLocationListener = null
        pendingLocationResult = null
    }
}
