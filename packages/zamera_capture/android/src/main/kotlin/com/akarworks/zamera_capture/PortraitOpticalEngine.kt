package com.akarworks.zamera_capture

import java.util.concurrent.ConcurrentHashMap
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.cos
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.roundToInt
import kotlin.math.sin
import kotlin.math.sqrt

/**
 * Per-frame immutable geometric and intensity context passed to [PortraitLightingStrategy].
 */
data class PortraitLightingFrameParams(
    val width: Int,
    val height: Int,
    val focusX: Float,
    val focusY: Float,
    val intensity: Float,
    val minDim: Float = min(width, height).toFloat().coerceAtLeast(1f)
)

/**
 * Open/Closed (OCP) SAM strategy for per-pixel Portrait Studio / Gobo / Monochrome relighting.
 *
 * Receives both the original tack-sharp pixel `(sharpR, sharpG, sharpB)` and the 3D linear-sRGB
 * circular-disc bokeh pixel `(bokehR, bokehG, bokehB)` in `[0..255]` sRGB space, along with
 * calibrated foreground matte `fgAlpha ∈ [0, 1]` and 3D Circle-of-Confusion `coc ∈ [0, 1]`.
 * Returns packed `0xFFRRGGBB` pixel with zero heap allocation.
 */
fun interface PortraitLightingStrategy {
    fun applyPixel(
        x: Int,
        y: Int,
        sharpR: Float,
        sharpG: Float,
        sharpB: Float,
        bokehR: Float,
        bokehG: Float,
        bokehB: Float,
        fgAlpha: Float,
        coc: Float,
        params: PortraitLightingFrameParams
    ): Int
}

/**
 * OCP Registry of Portrait Lighting Strategies (`0..9` built-in modes, extensible at runtime).
 *
 * Optical invariants:
 * - Modes `1` (Studio) and `2` (Contour) relight ONLY the subject (`fgAlpha > 0`) and NEVER darken
 *   the background (`fgAlpha == 0` stays 100% untouched), eliminating dark cloud/halo rings.
 * - Modes `3` & `4` (Stage `#000000`) and Mode `5` (High-Key `#F7F7F9`) separate background strictly
 *   through the tightened subject matte (`tightenSubjectMatte(fgAlpha)`).
 */
object PortraitLightingRegistry {
    private const val STAGE_BLACK_R = 0f
    private const val STAGE_BLACK_G = 0f
    private const val STAGE_BLACK_B = 0f

    // #F7F7F9 Alabaster High-Key Studio Backdrop
    private const val HIGH_KEY_R = 247f
    private const val HIGH_KEY_G = 247f
    private const val HIGH_KEY_B = 249f

    private const val COS_28 = 0.8829476f
    private const val SIN_28 = 0.46947156f

    private val monoStandardLut = FloatArray(256) { v ->
        val xNorm = v / 255.0f
        val s = xNorm * xNorm * (3.0f - 2.0f * xNorm)
        val filmic = 0.28f * xNorm + 0.72f * s
        (((filmic - 0.48f) * 1.24f + 0.48f).coerceIn(0f, 1f) * 255.0f).coerceIn(0f, 255f)
    }

    private val monoHighKeyLut = FloatArray(256) { v ->
        val xNorm = v / 255.0f
        val lifted = xNorm.toDouble().pow(0.72).toFloat()
        val sCurve = lifted * lifted * (3.0f - 2.0f * lifted)
        ((0.35f * lifted + 0.65f * sCurve) * 246.0f + 6.0f).coerceIn(0f, 255f)
    }

    private val strategies = ConcurrentHashMap<Int, PortraitLightingStrategy>()

    init {
        // 0: Natural Light — pure 3D optical disc bokeh, zero artificial grade
        register(0) { _, _, _, _, _, bokehR, bokehG, bokehB, _, _, _ ->
            packArgb(bokehR, bokehG, bokehB)
        }

        // 1: Studio Light — warm softbox fill lift strictly on subject (fgAlpha); background untouched (no dark halo ring)
        register(1) { _, _, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            if (fg <= 1e-4f) {
                packArgb(bokehR, bokehG, bokehB)
            } else {
                val amt = fg * params.intensity.coerceIn(0.15f, 1.0f)
                val r = softKneeLift(bokehR, 0.16f * amt)
                val g = softKneeLift(bokehG, 0.145f * amt)
                val b = softKneeLift(bokehB, 0.12f * amt)
                packArgb(r, g, b)
            }
        }

        // 2: Contour Light — directional facial/subject key + cheek/silhouette contour strictly on subject; background untouched
        register(2) { x, y, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            if (fg <= 1e-4f) {
                packArgb(bokehR, bokehG, bokehB)
            } else {
                val intensity = params.intensity.coerceIn(0.15f, 1.0f)
                val cx = params.width * params.focusX
                val cy = params.height * params.focusY
                val dx = (x - cx) / (params.minDim * 0.42f)
                val dy = (y - cy) / (params.minDim * 0.42f)
                val radial = sqrt(dx * dx + dy * dy).coerceIn(0f, 1.25f)
                val targetGain = (1.14f - 0.30f * radial * intensity).coerceIn(0.74f, 1.16f)
                val gain = 1.0f + fg * (targetGain - 1.0f)
                packArgb(bokehR * gain, bokehG * gain, bokehB * gain)
            }
        }

        // 3: Stage Light (#000000 pitch-black studio backdrop separated strictly by tight subject matte)
        register(3) { _, _, sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val tightFg = tightenSubjectMatte(fgAlpha)
            if (tightFg <= 1e-4f) {
                packArgb(STAGE_BLACK_R, STAGE_BLACK_G, STAGE_BLACK_B)
            } else {
                val intensity = params.intensity.coerceIn(0.15f, 1.0f)
                val (dr, dg, db) = decontaminateEdgeRgb(sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, tightFg)
                val contrast = 1.0f + 0.14f * intensity
                val litR = ((dr - 124f) * contrast + 128f).coerceIn(0f, 255f)
                val litG = ((dg - 124f) * contrast + 128f).coerceIn(0f, 255f)
                val litB = ((db - 124f) * contrast + 128f).coerceIn(0f, 255f)
                packArgb(litR * tightFg, litG * tightFg, litB * tightFg)
            }
        }

        // 4: Stage Mono (#000000 pitch-black studio backdrop + Leica panchromatic silver-gelatin subject)
        register(4) { x, y, sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val tightFg = tightenSubjectMatte(fgAlpha)
            if (tightFg <= 1e-4f) {
                packArgb(STAGE_BLACK_R, STAGE_BLACK_G, STAGE_BLACK_B)
            } else {
                val intensity = params.intensity.coerceIn(0.15f, 1.0f)
                val (dr, dg, db) = decontaminateEdgeRgb(sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, tightFg)
                val mono = applySilverGelatinMono(x, y, dr, dg, db, intensity, highKey = false)
                val toneShift = ((mono / 255.0f) - 0.5f) * 2.0f
                val mr = (mono + toneShift).coerceIn(0f, 255f)
                val mb = (mono - toneShift).coerceIn(0f, 255f)
                packArgb(mr * tightFg, mono * tightFg, mb * tightFg)
            }
        }

        // 5: High-Key Mono (#F7F7F9 alabaster white backdrop separated strictly by tight subject matte)
        register(5) { x, y, sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val tightFg = tightenSubjectMatte(fgAlpha)
            if (tightFg <= 1e-4f) {
                packArgb(HIGH_KEY_R, HIGH_KEY_G, HIGH_KEY_B)
            } else {
                val intensity = params.intensity.coerceIn(0.15f, 1.0f)
                val (dr, dg, db) = decontaminateEdgeRgb(sharpR, sharpG, sharpB, bokehR, bokehG, bokehB, tightFg)
                val mono = applySilverGelatinMono(x, y, dr, dg, db, intensity, highKey = true)
                val bgMix = 1.0f - tightFg
                val outR = mono * tightFg + HIGH_KEY_R * bgMix
                val outG = mono * tightFg + HIGH_KEY_G * bgMix
                val outB = mono * tightFg + HIGH_KEY_B * bgMix
                packArgb(outR, outG, outB)
            }
        }

        // 6: Venetian Blinds Gobo (28° window-blind slats with 3D depth/subject parallax)
        register(6) { x, y, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            val intensity = params.intensity.coerceIn(0.15f, 1.0f)
            val slat = computeVenetianSlat(x, y, fg, params)
            val shadowDepth = (0.58f * intensity).coerceIn(0.18f, 0.72f)
            val gain = (1.0f - shadowDepth) + shadowDepth * (0.34f + 0.82f * slat)
            val warm = slat * intensity * (0.4f + 0.6f * fg)
            val outR = bokehR * gain * (1.0f + 0.10f * warm)
            val outG = bokehG * gain * (1.0f + 0.04f * warm)
            val outB = bokehB * gain * (1.0f - 0.05f * warm)
            packArgb(outR, outG, outB)
        }

        // 7: Venetian Blinds Mono (28° window-blind gobo slats + silver-gelatin monochrome)
        register(7) { x, y, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            val intensity = params.intensity.coerceIn(0.15f, 1.0f)
            val slat = computeVenetianSlat(x, y, fg, params)
            val shadowDepth = (0.62f * intensity).coerceIn(0.20f, 0.76f)
            val gain = (1.0f - shadowDepth) + shadowDepth * (0.30f + 0.86f * slat)
            val mono = applySilverGelatinMono(
                x = x,
                y = y,
                r = (bokehR * gain).coerceIn(0f, 255f),
                g = (bokehG * gain).coerceIn(0f, 255f),
                b = (bokehB * gain).coerceIn(0f, 255f),
                intensity = intensity,
                highKey = false
            )
            val toneShift = ((mono / 255.0f) - 0.5f) * 2.0f
            packArgb(mono + toneShift, mono, mono - toneShift)
        }

        // 8: Golden Hour (3500K warm sunset beam + golden contour rim without background darkening)
        register(8) { x, y, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            val intensity = params.intensity.coerceIn(0.15f, 1.0f)
            val cx = params.width * params.focusX
            val cy = params.height * params.focusY
            val dx = (x - cx) / params.minDim
            val dy = (y - cy) / params.minDim
            val tBeam = dx * 0.7f + dy * 0.7f + 0.22f
            val sunBeam = (1.0f - tBeam * tBeam * 1.3f).coerceIn(0.25f, 1.0f)
            val warmSubj = intensity * sunBeam * (0.35f + 0.65f * fg)
            val edgeRim = 4.0f * fg * (1.0f - fg) * intensity
            val outR = bokehR * (1.0f + 0.18f * warmSubj) + 30f * edgeRim
            val outG = bokehG * (1.0f + 0.07f * warmSubj) + 17f * edgeRim
            val outB = bokehB * (1.0f - 0.11f * warmSubj) + 3f * edgeRim
            packArgb(outR, outG, outB)
        }

        // 9: Prism & Cinema (dual-tone Cyan/Amber silhouette rim + subtle spectral prism wave)
        register(9) { x, y, _, _, _, bokehR, bokehG, bokehB, fgAlpha, _, params ->
            val fg = fgAlpha.coerceIn(0f, 1f)
            val intensity = params.intensity.coerceIn(0.15f, 1.0f)
            val cx = params.width * params.focusX
            val edgeRim = 4.0f * fg * (1.0f - fg) * intensity
            val cyanRim = if (x < cx) edgeRim else 0f
            val amberRim = if (x >= cx) edgeRim else 0f
            val prismWave = (0.5f + 0.5f * sin(((x + y) * 0.018f).toDouble()).toFloat()) * (1.0f - fg) * intensity
            val outR = bokehR + 40f * amberRim + 18f * prismWave
            val outG = bokehG + 20f * cyanRim + 18f * amberRim + 10f * prismWave
            val outB = bokehB + 46f * cyanRim + 28f * prismWave
            packArgb(outR, outG, outB)
        }
    }

    fun register(modeId: Int, strategy: PortraitLightingStrategy) {
        strategies[modeId] = strategy
    }

    fun get(modeId: Int): PortraitLightingStrategy {
        return strategies[modeId] ?: strategies.getValue(0)
    }

    fun supportedModes(): Set<Int> = strategies.keys.toSet()

    fun tightenSubjectMatte(fgAlpha: Float): Float {
        val t = ((fgAlpha - 0.36f) / 0.48f).coerceIn(0f, 1f)
        return t * t * (3.0f - 2.0f * t)
    }

    private fun softKneeLift(c255: Float, lift: Float): Float {
        val x = (c255 / 255.0f).coerceIn(0f, 1f)
        // Lifts shadows & midtones smoothly while preserving highlight headroom (zero hard clipping)
        val lifted = x + lift * x * (1.0f - 0.65f * x)
        return (lifted.coerceIn(0f, 1f) * 255.0f)
    }

    private fun decontaminateEdgeRgb(
        sr: Float,
        sg: Float,
        sb: Float,
        br: Float,
        bg: Float,
        bb: Float,
        tightFg: Float
    ): Triple<Float, Float, Float> {
        if (tightFg <= 0.12f || tightFg >= 0.90f) {
            return Triple(sr, sg, sb)
        }
        val strength = 0.35f * (1.0f - tightFg)
        val invFg = 1.0f / tightFg.coerceAtLeast(0.32f)
        val tr = ((sr - br * (1f - tightFg)) * invFg).coerceIn(sr - 22f, sr + 22f).coerceIn(0f, 255f)
        val tg = ((sg - bg * (1f - tightFg)) * invFg).coerceIn(sg - 22f, sg + 22f).coerceIn(0f, 255f)
        val tb = ((sb - bb * (1f - tightFg)) * invFg).coerceIn(sb - 22f, sb + 22f).coerceIn(0f, 255f)
        return Triple(
            sr * (1f - strength) + tr * strength,
            sg * (1f - strength) + tg * strength,
            sb * (1f - strength) + tb * strength
        )
    }

    private fun computeVenetianSlat(
        x: Int,
        y: Int,
        fg: Float,
        params: PortraitLightingFrameParams
    ): Float {
        val cx = params.width * params.focusX
        val cy = params.height * params.focusY
        val blindFreq = (2.0 * Math.PI / (params.minDim * 0.072)).toFloat()
        val proj = (x - cx) * SIN_28 + (y - cy) * COS_28 + fg * (params.minDim * 0.022f)
        val wave = cos((proj * blindFreq).toDouble()).toFloat()
        val raw = ((wave + 0.18f) * 1.65f).coerceIn(0f, 1f)
        return raw * raw * (3.0f - 2.0f * raw)
    }

    private fun applySilverGelatinMono(
        x: Int,
        y: Int,
        r: Float,
        g: Float,
        b: Float,
        intensity: Float,
        highKey: Boolean
    ): Float {
        val panchro = (0.38f * r + 0.52f * g + 0.10f * b).roundToInt().coerceIn(0, 255)
        val curved = if (highKey) monoHighKeyLut[panchro] else monoStandardLut[panchro]
        val norm = curved / 255.0f
        val midWeight = 4.0f * norm * (1.0f - norm)
        val hash = ((x * 73856093) xor (y * 19349663)) and 0xFF
        val grain = ((hash / 127.5f) - 1.0f) * 2.4f * midWeight * intensity
        return (curved + grain).coerceIn(0f, 255f)
    }

    internal fun packArgb(r: Float, g: Float, b: Float): Int {
        val ir = r.roundToInt().coerceIn(0, 255)
        val ig = g.roundToInt().coerceIn(0, 255)
        val ib = b.roundToInt().coerceIn(0, 255)
        return (0xFF shl 24) or (ir shl 16) or (ig shl 8) or ib
    }
}

/**
 * Bounded `LRU = 1` Portrait Session Cache keyed by `sourceJpegPath`.
 *
 * Avoids re-running heavy neural inference (`DepthAnythingV2`, `SelfieMulticlass`, `MLKit`, `U²-NetP`)
 * during interactive post-capture aperture, studio lighting, and tap-to-refocus edits on the same photo,
 * while deterministically bounding memory to a single photo session.
 * Cleared explicitly in `ZameraCapturePlugin.onDetachedFromEngine`.
 */
class PortraitSessionCache(private val maxEntries: Int = 1) {
    data class Entry(
        val sourceJpegPath: String,
        val lastModified: Long = 0L,
        val fileLength: Long = 0L,
        val isFrontCamera: Boolean = false,
        val segW: Int,
        val segH: Int,
        val depthMap: FloatArray?,
        val mlSelfieMask: FloatArray? = null,
        val mlMaxConf: Float = 0f,
        val mlAreaRatio: Float = 0f,
        val humanProb: FloatArray? = null,
        val skinProb: FloatArray? = null,
        val hairProb: FloatArray? = null,
        val clothesProb: FloatArray? = null,
        val accessProb: FloatArray? = null,
        val maxHumanConf: Float = 0f,
        val humanAreaRatio: Float = 0f,
        val globalU2Net320: FloatArray? = null
    )

    private val lock = Any()
    private val cap = maxEntries.coerceAtLeast(1)
    private val map = object : LinkedHashMap<String, Entry>(cap + 1, 0.75f, true) {
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<String, Entry>?): Boolean {
            return size > cap
        }
    }

    fun get(
        sourceJpegPath: String,
        lastModified: Long = 0L,
        fileLength: Long = 0L,
        isFrontCamera: Boolean = false
    ): Entry? = synchronized(lock) {
        val hit = map[sourceJpegPath] ?: return null
        if (hit.lastModified != lastModified ||
            hit.fileLength != fileLength ||
            hit.isFrontCamera != isFrontCamera
        ) {
            map.remove(sourceJpegPath)
            return null
        }
        return hit
    }

    fun put(entry: Entry) = synchronized(lock) {
        map[entry.sourceJpegPath] = entry
    }

    fun size(): Int = synchronized(lock) { map.size }

    fun clear() = synchronized(lock) {
        map.clear()
    }
}

/**
 * Pure Computational Photography Optical Engine for Portrait Mode (Human & Object):
 * 1. Calibrated U²-NetP fusion (`0.78 * d0 + 0.22 * d1`) without low-signal min-max noise amplification.
 * 2. Isotropic edge-replicated letterbox geometry & active-ROI unmapping for `DepthAnythingV2` (`[1,3,518,686]`).
 * 3. `extractFocusedObjectMatte`: Zero radial dome / zero center-rectangle seed; combines calibrated U²-NetP
 *    probability + 3D `focusDepth` plane compatibility + photometric edge-barrier local connected component.
 * 4. `computeCoCMap`: Thin-lens `1 / aperture` 3D Circle-of-Confusion with focal-plane DoF dead-band grounding.
 * 5. `renderLinearDiscBokeh`: Linear sRGB (`c^2.2`) area-averaged downsampling + `(1 - fgAlpha)^3` occlusion-weighted
 *    circular aperture disc convolution + specular highlight bokeh boost + 3-stage (`L0 -> B1 -> B2 -> B3`) CoC
 *    interpolation (zero `fg*Sharp + (1-fg)*HeavyBlur` Orton cloud).
 */
object PortraitOpticalEngine {

    data class LetterboxGeometry(
        val dstW: Int,
        val dstH: Int,
        val activeW: Int,
        val activeH: Int,
        val padX: Int,
        val padY: Int
    )

    private const val LINEAR_LUT_STEPS = 4096

    private val srgbToLinearLut = FloatArray(256) { v ->
        (v / 255.0).pow(2.2).toFloat()
    }

    private val linearToSrgbLut = FloatArray(LINEAR_LUT_STEPS + 1) { k ->
        ((k.toDouble() / LINEAR_LUT_STEPS.toDouble()).pow(1.0 / 2.2) * 255.0).toFloat()
    }

    fun srgbByteToLinear(v: Int): Float = srgbToLinearLut[v.coerceIn(0, 255)]

    fun linearToSrgb255(lin: Float): Float {
        if (lin <= 0f) return 0f
        if (lin >= 1f) return 255f
        val scaled = lin * LINEAR_LUT_STEPS
        val idx = scaled.toInt().coerceIn(0, LINEAR_LUT_STEPS - 1)
        val frac = scaled - idx
        return linearToSrgbLut[idx] * (1.0f - frac) + linearToSrgbLut[idx + 1] * frac
    }

    /**
     * Computes isotropic letterbox placement inside `[dstW x dstH]` (default `686 x 518` for `DepthAnythingV2`).
     */
    fun computeIsotropicLetterbox(
        srcW: Int,
        srcH: Int,
        dstW: Int = 686,
        dstH: Int = 518
    ): LetterboxGeometry {
        val safeSrcW = srcW.coerceAtLeast(1)
        val safeSrcH = srcH.coerceAtLeast(1)
        val scale = min(dstW.toFloat() / safeSrcW.toFloat(), dstH.toFloat() / safeSrcH.toFloat())
        val actW = (safeSrcW * scale).roundToInt().coerceIn(1, dstW)
        val actH = (safeSrcH * scale).roundToInt().coerceIn(1, dstH)
        val padX = (dstW - actW) / 2
        val padY = (dstH - actH) / 2
        return LetterboxGeometry(
            dstW = dstW,
            dstH = dstH,
            activeW = actW,
            activeH = actH,
            padX = padX,
            padY = padY
        )
    }

    /**
     * Normalizes (2nd..98th percentile inside active ROI only) and bilinearly resamples ONLY the active
     * letterbox ROI `[padX .. padX + activeW - 1] x [padY .. padY + activeH - 1]` onto `outW x outH`.
     */
    fun resampleLetterboxDepthRoi(
        rawDepth: FloatArray,
        geom: LetterboxGeometry,
        outW: Int,
        outH: Int
    ): FloatArray? {
        val dw = geom.dstW
        val dh = geom.dstH
        if (rawDepth.size < dw * dh || outW <= 0 || outH <= 0) return null

        val xMin = geom.padX.coerceIn(0, dw - 1)
        val xMax = (geom.padX + geom.activeW - 1).coerceIn(xMin, dw - 1)
        val yMin = geom.padY.coerceIn(0, dh - 1)
        val yMax = (geom.padY + geom.activeH - 1).coerceIn(yMin, dh - 1)

        val roiArea = (xMax - xMin + 1) * (yMax - yMin + 1)
        val step = max(1, sqrt((roiArea / 2400.0)).toInt())
        val samples = FloatArray(((yMax - yMin) / step + 2) * ((xMax - xMin) / step + 2))
        var sCnt = 0
        var ySample = yMin
        while (ySample <= yMax) {
            val rowOff = ySample * dw
            var xSample = xMin
            while (xSample <= xMax) {
                val v = rawDepth[rowOff + xSample]
                if (v.isFinite() && sCnt < samples.size) {
                    samples[sCnt++] = v
                }
                xSample += step
            }
            ySample += step
        }
        if (sCnt < 8) return null
        java.util.Arrays.sort(samples, 0, sCnt)
        val dLow = samples[(sCnt * 2) / 100]
        val dHigh = samples[(sCnt * 98) / 100]
        val dSpan = (dHigh - dLow).coerceAtLeast(1e-4f)

        val out = FloatArray(outW * outH)
        val roiSpanW = (xMax - xMin).coerceAtLeast(0).toFloat()
        val roiSpanH = (yMax - yMin).coerceAtLeast(0).toFloat()
        val denomW = (outW - 1).coerceAtLeast(1).toFloat()
        val denomH = (outH - 1).coerceAtLeast(1).toFloat()

        for (y in 0 until outH) {
            val gy = yMin + (y.toFloat() / denomH) * roiSpanH
            val y0 = gy.toInt().coerceIn(yMin, yMax)
            val y1 = (y0 + 1).coerceIn(yMin, yMax)
            val fy = (gy - y0).coerceIn(0f, 1f)
            val outRow = y * outW
            for (x in 0 until outW) {
                val gx = xMin + (x.toFloat() / denomW) * roiSpanW
                val x0 = gx.toInt().coerceIn(xMin, xMax)
                val x1 = (x0 + 1).coerceIn(xMin, xMax)
                val fx = (gx - x0).coerceIn(0f, 1f)
                val v = rawDepth[y0 * dw + x0] * (1f - fx) * (1f - fy) +
                    rawDepth[y0 * dw + x1] * fx * (1f - fy) +
                    rawDepth[y1 * dw + x0] * (1f - fx) * fy +
                    rawDepth[y1 * dw + x1] * fx * fy
                out[outRow + x] = if (v.isFinite()) ((v - dLow) / dSpan).coerceIn(0f, 1f) else 0f
            }
        }
        return out
    }

    /**
     * Fuses calibrated `u2netp.tflite` sigmoid probabilities:
     * `d0` = output index `3` (`PartitionedCall:0`), `d1` = output index `0` (`PartitionedCall:1`).
     * Strictly `0.78f * d0 + 0.22f * d1` in `[0, 1]` with ZERO min-max noise inflation on low-saliency scenes.
     */
    fun fuseCalibratedU2NetOutputs(d0: FloatArray, d1: FloatArray): FloatArray {
        val n = min(d0.size, d1.size)
        val out = FloatArray(n)
        for (i in 0 until n) {
            val v0 = if (d0[i].isFinite()) d0[i].coerceIn(0f, 1f) else 0f
            val v1 = if (d1[i].isFinite()) d1[i].coerceIn(0f, 1f) else 0f
            out[i] = (0.78f * v0 + 0.22f * v1).coerceIn(0f, 1f)
        }
        return out
    }

    /**
     * Optical Depth-of-Field (DoF) dead-band half-width around `focusDepth` as a linear function of f-stop.
     * Within `|d - focusDepth| <= dofHalfBand(aperture)`, `CoC == 0` (contact table / floor under feet is 100% sharp).
     */
    fun dofHalfBand(aperture: Float): Float {
        val fStop = aperture.coerceIn(1.4f, 16.0f)
        return (0.018f + 0.014f * fStop).coerceIn(0.035f, 0.28f)
    }

    /**
     * Computes Thin-Lens `1 / aperture` scaled 3D Circle-of-Confusion map `CoC(x, y) ∈ [0, 1]`.
     * - Inside focal-plane dead-band `|d - focusDepth| <= dofHalfBand(aperture)`: `CoC = 0.0f`.
     * - Progressive continuous transition outside dead-band scaled by `1 / aperture`.
     * - Subject protection: `CoC *= (1 - fgAlpha)`.
     */
    fun computeCoCMap(
        depthMap: FloatArray?,
        focusDepth: Float,
        aperture: Float,
        fgAlpha: FloatArray?,
        width: Int,
        height: Int
    ): FloatArray {
        val n = width * height
        val coc = FloatArray(n)
        if (n <= 0) return coc
        val fStop = aperture.coerceIn(1.4f, 16.0f)

        if (depthMap == null || depthMap.size < n) {
            if (fgAlpha == null || fgAlpha.size < n) return coc
            var maxFg = 0f
            for (i in 0 until n) {
                if (fgAlpha[i] > maxFg) maxFg = fgAlpha[i]
            }
            if (maxFg < 0.35f) return coc
            val fallbackBlur = (1.8f / fStop).coerceIn(0.10f, 1.0f)
            for (i in 0 until n) {
                val fg = fgAlpha[i].coerceIn(0f, 1f)
                coc[i] = (fallbackBlur * (1.0f - fg)).coerceIn(0f, 1f)
            }
            return coc
        }

        val clampedFocus = focusDepth.coerceIn(0f, 1f)
        val halfBand = dofHalfBand(fStop)
        val invApertureScale = 3.6f / fStop

        for (i in 0 until n) {
            val d = if (depthMap[i].isFinite()) depthMap[i].coerceIn(0f, 1f) else clampedFocus
            val delta = abs(d - clampedFocus)
            val rawCoC = if (delta <= halfBand) {
                0.0f
            } else {
                val excess = delta - halfBand
                val lin = (excess * invApertureScale).coerceIn(0f, 1f)
                (lin * (0.40f + 0.60f * lin * (3.0f - 2.0f * lin))).coerceIn(0f, 1f)
            }
            val fg = if (fgAlpha != null && i < fgAlpha.size) fgAlpha[i].coerceIn(0f, 1f) else 0f
            coc[i] = (rawCoC * (1.0f - fg)).coerceIn(0f, 1f)
        }
        return coc
    }

    /**
     * Extracts a focused non-human object matte around `(focusX, focusY)` WITHOUT any radial dome penalty
     * and WITHOUT any unconditional center-rectangle seed:
     * 1. Rejects low-saliency scenes (`u2netProb == null` or low calibrated peak/contrast) -> returns all `0.0f`
     *    so optical bokeh relies purely on 3D `DepthAnythingV2` DoF with zero artificial cloud.
     * 2. Gates calibrated U²-NetP probability by 3D `focusDepth` plane compatibility (`depthAffinity`).
     * 3. Extracts ONLY the 8-connected local component anchored to high-confidence salient seeds at `(focusX, focusY)`,
     *    snapped to physical object borders via photometric edge-barrier Chamfer geodesics.
     */
    fun extractFocusedObjectMatte(
        u2netProb: FloatArray?,
        depthMap: FloatArray?,
        focusDepth: Float,
        luma255: FloatArray,
        chA: FloatArray,
        chB: FloatArray,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float
    ): FloatArray {
        val n = segW * segH
        val emptyMatte = FloatArray(n)
        if (n <= 0 || segW < 4 || segH < 4 || u2netProb == null || u2netProb.size < n) {
            return emptyMatte
        }

        val cx = (focusX.coerceIn(0f, 1f) * (segW - 1)).roundToInt().coerceIn(0, segW - 1)
        val cy = (focusY.coerceIn(0f, 1f) * (segH - 1)).roundToInt().coerceIn(0, segH - 1)

        // 1. Compute 3D focusDepth plane compatibility & joint calibrated object probability (zero radial bias!)
        val hasDepth = depthMap != null && depthMap.size >= n
        val clampedFocusDepth = focusDepth.coerceIn(0f, 1f)
        val frontTol = 0.18f
        val rearTol = 0.13f
        val depthAffinity = FloatArray(n)
        val jointProb = FloatArray(n)

        for (i in 0 until n) {
            val u = if (u2netProb[i].isFinite()) u2netProb[i].coerceIn(0f, 1f) else 0f
            val dAff = if (hasDepth) {
                val d = if (depthMap!![i].isFinite()) depthMap[i].coerceIn(0f, 1f) else clampedFocusDepth
                val normDist = if (d >= clampedFocusDepth) {
                    (d - clampedFocusDepth) / frontTol
                } else {
                    (clampedFocusDepth - d) / rearTol
                }
                1.0f - smoothstep(0.65f, 1.35f, normDist)
            } else {
                1.0f
            }
            depthAffinity[i] = dAff
            jointProb[i] = u * dAff
        }

        // 2. Low-saliency & contrast guard: check calibrated saliency at tap probe vs frame perimeter
        val probeR = (min(segW, segH) * 0.08f).roundToInt().coerceIn(2, max(2, min(segW, segH) / 4))
        var localPeak = 0f
        for (y in (cy - probeR).coerceAtLeast(0)..(cy + probeR).coerceAtMost(segH - 1)) {
            val row = y * segW
            for (x in (cx - probeR).coerceAtLeast(0)..(cx + probeR).coerceAtMost(segW - 1)) {
                val jp = jointProb[row + x]
                if (jp > localPeak) localPeak = jp
            }
        }
        if (localPeak < 0.34f) {
            return emptyMatte
        }

        var borderSum = 0f
        var borderCnt = 0
        val borderBand = max(1, min(segW, segH) / 24)
        for (y in 0 until segH) {
            val row = y * segW
            val isTopBot = y < borderBand || y >= segH - borderBand
            if (isTopBot) {
                for (x in 0 until segW step 2) {
                    borderSum += u2netProb[row + x].coerceIn(0f, 1f)
                    borderCnt++
                }
            } else {
                for (x in 0 until borderBand) {
                    borderSum += u2netProb[row + x].coerceIn(0f, 1f)
                    borderSum += u2netProb[row + (segW - 1 - x)].coerceIn(0f, 1f)
                    borderCnt += 2
                }
            }
        }
        val borderMean = if (borderCnt > 0) borderSum / borderCnt else 0f
        if (localPeak - borderMean < 0.14f && borderMean > 0.45f) {
            return emptyMatte
        }

        // 3. Photometric + saliency gradient barrier (strictly local edges — zero radial term)
        val edgeGrad = FloatArray(n)
        val hasPhoto = luma255.size >= n && chA.size >= n && chB.size >= n
        if (hasPhoto) {
            for (y in 1 until segH - 1) {
                val row = y * segW
                for (x in 1 until segW - 1) {
                    val i = row + x
                    val dl = abs(luma255[i + 1] - luma255[i - 1]) + abs(luma255[i + segW] - luma255[i - segW])
                    val da = abs(chA[i + 1] - chA[i - 1]) + abs(chA[i + segW] - chA[i - segW])
                    val db = abs(chB[i + 1] - chB[i - 1]) + abs(chB[i + segW] - chB[i - segW])
                    val du = abs(jointProb[i + 1] - jointProb[i - 1]) + abs(jointProb[i + segW] - jointProb[i - segW])
                    edgeGrad[i] = 0.55f * dl + 1.35f * da + 1.15f * db + 24.0f * du
                }
            }
        }

        // 4. Seed ONLY genuine high-confidence salient pixels near (cx, cy) and flood 8-connected component
        val seedThresh = max(0.42f, localPeak * 0.62f)
        val reachable = BooleanArray(n)
        val queue = IntArray(n)
        var qHead = 0
        var qTail = 0

        for (y in (cy - probeR).coerceAtLeast(0)..(cy + probeR).coerceAtMost(segH - 1)) {
            val row = y * segW
            for (x in (cx - probeR).coerceAtLeast(0)..(cx + probeR).coerceAtMost(segW - 1)) {
                val idx = row + x
                if (jointProb[idx] >= seedThresh && !reachable[idx]) {
                    reachable[idx] = true
                    queue[qTail++] = idx
                }
            }
        }
        if (qTail == 0) {
            return emptyMatte
        }

        val reachFloor = 0.18f
        while (qHead < qTail) {
            val cur = queue[qHead++]
            val curX = cur % segW
            val curY = cur / segW
            val curP = jointProb[cur]

            val y0 = max(0, curY - 1)
            val y1 = min(segH - 1, curY + 1)
            val x0 = max(0, curX - 1)
            val x1 = min(segW - 1, curX + 1)
            for (ny in y0..y1) {
                val nRow = ny * segW
                for (nx in x0..x1) {
                    val nb = nRow + nx
                    if (reachable[nb]) continue
                    val nbP = jointProb[nb]
                    if (nbP < reachFloor) continue
                    // Hard photometric cliff with sharp saliency drop blocks leaking across touching background edges
                    if (edgeGrad[nb] > 42.0f && nbP < 0.36f && (curP - nbP) > 0.22f) continue
                    reachable[nb] = true
                    queue[qTail++] = nb
                }
            }
        }

        if (qTail < 6) {
            return emptyMatte
        }

        // 5. Edge-barrier Chamfer geodesic boundary refinement on the connected component (zero radial penalty!)
        val coreThresh = max(0.45f, localPeak * 0.72f)
        val distFg = FloatArray(n) { 1e6f }
        val distBg = FloatArray(n) { 1e6f }
        val stepCost = FloatArray(n)

        for (i in 0 until n) {
            stepCost[i] = 1.0f + 1.45f * edgeGrad[i]
            if (reachable[i] && jointProb[i] >= coreThresh) {
                distFg[i] = 0f
            }
            if (!reachable[i] || jointProb[i] <= 0.12f) {
                distBg[i] = 0f
            }
        }

        val diag = 1.4142135f
        repeat(4) {
            for (y in 1 until segH - 1) {
                val row = y * segW
                for (x in 1 until segW - 1) {
                    val i = row + x
                    val c = stepCost[i]
                    val mf = min(
                        min(distFg[i - 1] + c, distFg[i - segW] + c),
                        min(distFg[i - segW - 1] + c * diag, distFg[i - segW + 1] + c * diag)
                    )
                    if (mf < distFg[i]) distFg[i] = mf

                    val mb = min(
                        min(distBg[i - 1] + c, distBg[i - segW] + c),
                        min(distBg[i - segW - 1] + c * diag, distBg[i - segW + 1] + c * diag)
                    )
                    if (mb < distBg[i]) distBg[i] = mb
                }
            }
            for (y in segH - 2 downTo 1) {
                val row = y * segW
                for (x in segW - 2 downTo 1) {
                    val i = row + x
                    val c = stepCost[i]
                    val mf = min(
                        min(distFg[i + 1] + c, distFg[i + segW] + c),
                        min(distFg[i + segW + 1] + c * diag, distFg[i + segW - 1] + c * diag)
                    )
                    if (mf < distFg[i]) distFg[i] = mf

                    val mb = min(
                        min(distBg[i + 1] + c, distBg[i + segW] + c),
                        min(distBg[i + segW + 1] + c * diag, distBg[i + segW - 1] + c * diag)
                    )
                    if (mb < distBg[i]) distBg[i] = mb
                }
            }
        }

        val matte = FloatArray(n)
        for (i in 0 until n) {
            if (!reachable[i]) {
                matte[i] = 0f
                continue
            }
            val geoRatio = distBg[i] / (distFg[i] + distBg[i] + 1e-4f)
            val geoAlpha = smoothstep(0.35f, 0.65f, geoRatio)
            val calAlpha = smoothstep(0.22f, 0.72f, jointProb[i])
            val combined = ((0.55f * calAlpha + 0.45f * geoAlpha) * depthAffinity[i]).coerceIn(0f, 1f)
            matte[i] = when {
                combined >= 0.94f -> 1.0f
                combined <= 0.03f -> 0.0f
                else -> combined
            }
        }
        return matte
    }

    /**
     * Renders true 3D Optical Linear-sRGB Circular-Disc Bokeh + Studio Relighting:
     * - Area-averages `srcPixels` in Linear sRGB (`c^2.2`) onto a resolution-invariant bokeh grid.
     * - Weights each background sample by `(1 - fgAlpha)^3` occlusion rejection (zero foreground color bleed)
     *   multiplied by linear-luminance specular highlight bokeh boost (luminous round specular bokeh balls).
     * - Convolves 3 progressive Euclidean circular aperture disc kernels (`B1` thin, `B2` medium, `B3` deep)
     *   in exact `O(R)` per pixel via horizontal chord prefix-sums.
     * - Interpolates progressively in linear light (`L0 -> B1 -> B2 -> B3`) driven by per-pixel `CoC(x, y)`
     *   — NEVER blending `fg * Sharp + (1 - fg) * HeavyBlur` (zero Orton glow cloud!).
     * - Applies [PortraitLightingRegistry] strategy for `lightingMode`.
     */
    fun renderLinearDiscBokeh(
        srcPixels: IntArray,
        width: Int,
        height: Int,
        cocMap: FloatArray,
        fgAlphaMap: FloatArray?,
        mapW: Int,
        mapH: Int,
        aperture: Float,
        lightingMode: Int = 0,
        lightIntensity: Float = 0.80f,
        focusX: Float = 0.5f,
        focusY: Float = 0.5f,
        meanA: FloatArray? = null,
        meanB: FloatArray? = null,
        invertFocusPlane: Boolean = false,
        rowExecutor: (Int, (Int, Int) -> Unit) -> Unit = { h, worker -> worker(0, h) }
    ): IntArray {
        val totalPx = width * height
        if (totalPx <= 0 || srcPixels.size < totalPx || mapW <= 0 || mapH <= 0 || cocMap.size < mapW * mapH) {
            return srcPixels.copyOf()
        }

        val step = (min(width, height) / 480).coerceIn(1, 6)
        val bw = ((width + step - 1) / step).coerceAtLeast(4)
        val bh = ((height + step - 1) / step).coerceAtLeast(4)
        val bn = bw * bh

        val gridLinR = FloatArray(bn)
        val gridLinG = FloatArray(bn)
        val gridLinB = FloatArray(bn)
        val weightedR = FloatArray(bn)
        val weightedG = FloatArray(bn)
        val weightedB = FloatArray(bn)
        val sampleW = FloatArray(bn)

        val useGuidedFullRes = meanA != null && meanB != null &&
            meanA.size >= mapW * mapH && meanB.size >= mapW * mapH

        // 1. Area-averaged downsampling in Linear sRGB (c^2.2) + (1 - fgAlpha)^3 occlusion + Specular highlight boost
        val denomBw = (bw - 1).coerceAtLeast(1).toFloat()
        val denomBh = (bh - 1).coerceAtLeast(1).toFloat()
        rowExecutor(bh) { byStart, byEnd ->
            for (by in byStart until byEnd) {
                val y0Src = by * step
                val y1Src = min(height, y0Src + step)
                val gy = (by.toFloat() / denomBh) * (mapH - 1).coerceAtLeast(0)
                val bRow = by * bw

                for (bx in 0 until bw) {
                    val x0Src = bx * step
                    val x1Src = min(width, x0Src + step)
                    var sumLinR = 0f
                    var sumLinG = 0f
                    var sumLinB = 0f
                    var sumSrgbLum = 0f
                    var count = 0

                    for (sy in y0Src until y1Src) {
                        val sRow = sy * width
                        for (sx in x0Src until x1Src) {
                            val sp = srcPixels[sRow + sx]
                            val r8 = (sp shr 16) and 0xFF
                            val g8 = (sp shr 8) and 0xFF
                            val b8 = sp and 0xFF
                            sumLinR += srgbToLinearLut[r8]
                            sumLinG += srgbToLinearLut[g8]
                            sumLinB += srgbToLinearLut[b8]
                            sumSrgbLum += (0.299f * r8 + 0.587f * g8 + 0.114f * b8) * (1.0f / 255.0f)
                            count++
                        }
                    }

                    val invCnt = 1.0f / count.coerceAtLeast(1).toFloat()
                    val linR = sumLinR * invCnt
                    val linG = sumLinG * invCnt
                    val linB = sumLinB * invCnt
                    val lumNorm = sumSrgbLum * invCnt

                    val gx = (bx.toFloat() / denomBw) * (mapW - 1).coerceAtLeast(0)
                    val fg = if (useGuidedFullRes) {
                        val aVal = sampleBilinear(meanA!!, mapW, mapH, gx, gy)
                        val bVal = sampleBilinear(meanB!!, mapW, mapH, gx, gy)
                        val cleanFg = smoothstep(0.24f, 0.78f, (aVal * lumNorm + bVal).coerceIn(0f, 1f))
                        if (invertFocusPlane) (1.0f - cleanFg) else cleanFg
                    } else if (fgAlphaMap != null && fgAlphaMap.size >= mapW * mapH) {
                        val rawFg = sampleBilinear(fgAlphaMap, mapW, mapH, gx, gy).coerceIn(0f, 1f)
                        if (invertFocusPlane) (1.0f - rawFg) else rawFg
                    } else {
                        0f
                    }

                    val baseCoC = sampleBilinear(cocMap, mapW, mapH, gx, gy).coerceIn(0f, 1f)
                    val blockCoC = if (useGuidedFullRes) (baseCoC * (1.0f - fg)).coerceIn(0f, 1f) else baseCoC

                    // Strict (1 - fgAlpha)^3 foreground occlusion weight — zero foreground bleed into bokeh discs
                    val oneMinusFg = (1.0f - fg).coerceIn(0f, 1f)
                    val occW = oneMinusFg * oneMinusFg * oneMinusFg

                    // Specular highlight bokeh boost in linear luminance space
                    val linY = 0.2126f * linR + 0.7152f * linG + 0.0722f * linB
                    val specExcess = ((linY - 0.52f) / 0.48f).coerceIn(0f, 1f)
                    val specBoost = 1.0f + 3.4f * specExcess * specExcess * blockCoC
                    val w = occW * specBoost

                    val bi = bRow + bx
                    gridLinR[bi] = linR
                    gridLinG[bi] = linG
                    gridLinB[bi] = linB
                    weightedR[bi] = linR * w
                    weightedG[bi] = linG * w
                    weightedB[bi] = linB * w
                    sampleW[bi] = w
                }
            }
        }

        // 2. Build exact Double-precision horizontal row prefix-sums once, reused across B1, B2, and B3 discs
        val strideP = bw + 1
        val prefN = bh * strideP
        val prefR = DoubleArray(prefN)
        val prefG = DoubleArray(prefN)
        val prefB = DoubleArray(prefN)
        val prefW = DoubleArray(prefN)

        rowExecutor(bh) { byStart, byEnd ->
            for (by in byStart until byEnd) {
                val srcRow = by * bw
                val pRow = by * strideP
                var sr = 0.0
                var sg = 0.0
                var sb = 0.0
                var sw = 0.0
                for (bx in 0 until bw) {
                    val idx = srcRow + bx
                    sr += weightedR[idx].toDouble()
                    sg += weightedG[idx].toDouble()
                    sb += weightedB[idx].toDouble()
                    sw += sampleW[idx].toDouble()
                    val pIdx = pRow + bx + 1
                    prefR[pIdx] = sr
                    prefG[pIdx] = sg
                    prefB[pIdx] = sb
                    prefW[pIdx] = sw
                }
            }
        }

        // 3. Convolve 3 progressive circular aperture disc strata: B1 (thin), B2 (medium), B3 (deep)
        val shortEdge = min(bw, bh).toFloat()
        val fStopScale = (2.8f / aperture.coerceIn(1.4f, 16.0f)).coerceIn(0.45f, 1.35f)
        val r1 = (shortEdge * 0.0065f * max(0.85f, fStopScale * 0.85f)).coerceIn(1.5f, 4.5f)
        val r2 = (shortEdge * 0.0155f * max(0.85f, fStopScale * 0.92f)).coerceIn(3.2f, 9.5f)
        val r3 = (shortEdge * 0.0310f * max(0.85f, fStopScale)).coerceIn(5.5f, 17.5f)

        val b1R = FloatArray(bn); val b1G = FloatArray(bn); val b1B = FloatArray(bn)
        val b2R = FloatArray(bn); val b2G = FloatArray(bn); val b2B = FloatArray(bn)
        val b3R = FloatArray(bn); val b3G = FloatArray(bn); val b3B = FloatArray(bn)

        convolveCircularDiscFromPrefix(
            prefR, prefG, prefB, prefW, gridLinR, gridLinG, gridLinB,
            bw, bh, r1, b1R, b1G, b1B, rowExecutor
        )
        convolveCircularDiscFromPrefix(
            prefR, prefG, prefB, prefW, gridLinR, gridLinG, gridLinB,
            bw, bh, r2, b2R, b2G, b2B, rowExecutor
        )
        convolveCircularDiscFromPrefix(
            prefR, prefG, prefB, prefW, gridLinR, gridLinG, gridLinB,
            bw, bh, r3, b3R, b3G, b3B, rowExecutor
        )

        // 4. Full-resolution progressive 3-stage CoC interpolation (L0 -> B1 -> B2 -> B3) + OCP Lighting Strategy
        val outPixels = IntArray(totalPx)
        val lightingStrategy = PortraitLightingRegistry.get(lightingMode)
        val lightingParams = PortraitLightingFrameParams(
            width = width,
            height = height,
            focusX = focusX.coerceIn(0f, 1f),
            focusY = focusY.coerceIn(0f, 1f),
            intensity = lightIntensity.coerceIn(0.15f, 1.0f)
        )

        val denomW = (width - 1).coerceAtLeast(1).toFloat()
        val denomH = (height - 1).coerceAtLeast(1).toFloat()
        val invStep = 1.0f / step.toFloat()
        val maxBx = (bw - 1).coerceAtLeast(0).toFloat()
        val maxBy = (bh - 1).coerceAtLeast(0).toFloat()

        rowExecutor(height) { startY, endY ->
            for (y in startY until endY) {
                val gy = (y.toFloat() / denomH) * (mapH - 1).coerceAtLeast(0)
                val byCoord = ((y + 0.5f) * invStep - 0.5f).coerceIn(0f, maxBy)
                val rowOff = y * width

                for (x in 0 until width) {
                    val gx = (x.toFloat() / denomW) * (mapW - 1).coerceAtLeast(0)
                    val bxCoord = ((x + 0.5f) * invStep - 0.5f).coerceIn(0f, maxBx)

                    val idx = rowOff + x
                    val sp = srcPixels[idx]
                    val r8 = (sp shr 16) and 0xFF
                    val g8 = (sp shr 8) and 0xFF
                    val b8 = sp and 0xFF
                    val sharpR = r8.toFloat()
                    val sharpG = g8.toFloat()
                    val sharpB = b8.toFloat()

                    val fg = if (useGuidedFullRes) {
                        val lumNorm = (0.299f * sharpR + 0.587f * sharpG + 0.114f * sharpB) * (1.0f / 255.0f)
                        val aVal = sampleBilinear(meanA!!, mapW, mapH, gx, gy)
                        val bVal = sampleBilinear(meanB!!, mapW, mapH, gx, gy)
                        val cleanFg = smoothstep(0.24f, 0.78f, (aVal * lumNorm + bVal).coerceIn(0f, 1f))
                        if (invertFocusPlane) (1.0f - cleanFg) else cleanFg
                    } else if (fgAlphaMap != null && fgAlphaMap.size >= mapW * mapH) {
                        val rawFg = sampleBilinear(fgAlphaMap, mapW, mapH, gx, gy).coerceIn(0f, 1f)
                        if (invertFocusPlane) (1.0f - rawFg) else rawFg
                    } else {
                        0f
                    }

                    val sampledCoC = sampleBilinear(cocMap, mapW, mapH, gx, gy).coerceIn(0f, 1f)
                    val coc = if (useGuidedFullRes) {
                        (sampledCoC * (1.0f - fg)).coerceIn(0f, 1f)
                    } else {
                        sampledCoC
                    }

                    val bokehR: Float
                    val bokehG: Float
                    val bokehB: Float

                    if (coc <= 1e-4f) {
                        bokehR = sharpR
                        bokehG = sharpG
                        bokehB = sharpB
                    } else {
                        val l0R = srgbToLinearLut[r8]
                        val l0G = srgbToLinearLut[g8]
                        val l0B = srgbToLinearLut[b8]

                        val linOutR: Float
                        val linOutG: Float
                        val linOutB: Float

                        if (coc <= 0.33f) {
                            val t = coc / 0.33f
                            val k1R = sampleBilinear(b1R, bw, bh, bxCoord, byCoord)
                            val k1G = sampleBilinear(b1G, bw, bh, bxCoord, byCoord)
                            val k1B = sampleBilinear(b1B, bw, bh, bxCoord, byCoord)
                            linOutR = l0R + (k1R - l0R) * t
                            linOutG = l0G + (k1G - l0G) * t
                            linOutB = l0B + (k1B - l0B) * t
                        } else if (coc <= 0.67f) {
                            val t = (coc - 0.33f) / 0.34f
                            val k1R = sampleBilinear(b1R, bw, bh, bxCoord, byCoord)
                            val k1G = sampleBilinear(b1G, bw, bh, bxCoord, byCoord)
                            val k1B = sampleBilinear(b1B, bw, bh, bxCoord, byCoord)
                            val k2R = sampleBilinear(b2R, bw, bh, bxCoord, byCoord)
                            val k2G = sampleBilinear(b2G, bw, bh, bxCoord, byCoord)
                            val k2B = sampleBilinear(b2B, bw, bh, bxCoord, byCoord)
                            linOutR = k1R + (k2R - k1R) * t
                            linOutG = k1G + (k2G - k1G) * t
                            linOutB = k1B + (k2B - k1B) * t
                        } else {
                            val t = ((coc - 0.67f) / 0.33f).coerceIn(0f, 1f)
                            val k2R = sampleBilinear(b2R, bw, bh, bxCoord, byCoord)
                            val k2G = sampleBilinear(b2G, bw, bh, bxCoord, byCoord)
                            val k2B = sampleBilinear(b2B, bw, bh, bxCoord, byCoord)
                            val k3R = sampleBilinear(b3R, bw, bh, bxCoord, byCoord)
                            val k3G = sampleBilinear(b3G, bw, bh, bxCoord, byCoord)
                            val k3B = sampleBilinear(b3B, bw, bh, bxCoord, byCoord)
                            linOutR = k2R + (k3R - k2R) * t
                            linOutG = k2G + (k3G - k2G) * t
                            linOutB = k2B + (k3B - k2B) * t
                        }

                        bokehR = linearToSrgb255(linOutR)
                        bokehG = linearToSrgb255(linOutG)
                        bokehB = linearToSrgb255(linOutB)
                    }

                    outPixels[idx] = lightingStrategy.applyPixel(
                        x = x,
                        y = y,
                        sharpR = sharpR,
                        sharpG = sharpG,
                        sharpB = sharpB,
                        bokehR = bokehR,
                        bokehG = bokehG,
                        bokehB = bokehB,
                        fgAlpha = fg,
                        coc = coc,
                        params = lightingParams
                    )
                }
            }
        }
        return outPixels
    }

    /**
     * Exact Euclidean circular aperture disc convolution `dx^2 + dy^2 <= radius^2` in `O(radius)` per pixel
     * using precomputed horizontal row prefix-sums with anti-aliased chord endpoints.
     */
    private fun convolveCircularDiscFromPrefix(
        prefR: DoubleArray,
        prefG: DoubleArray,
        prefB: DoubleArray,
        prefW: DoubleArray,
        fallbackR: FloatArray,
        fallbackG: FloatArray,
        fallbackB: FloatArray,
        bw: Int,
        bh: Int,
        radius: Float,
        outR: FloatArray,
        outG: FloatArray,
        outB: FloatArray,
        rowExecutor: (Int, (Int, Int) -> Unit) -> Unit
    ) {
        val rInt = ceil(radius.toDouble()).toInt().coerceAtLeast(1)
        val rSq = radius * radius
        val chordInt = IntArray(2 * rInt + 1)
        val chordFrac = FloatArray(2 * rInt + 1)

        for (dy in -rInt..rInt) {
            val idx = dy + rInt
            val dySq = (dy * dy).toFloat()
            if (dySq >= rSq) {
                chordInt[idx] = -1
                chordFrac[idx] = 0f
            } else {
                val halfSpan = sqrt((rSq - dySq).toDouble()).toFloat()
                val ci = halfSpan.toInt()
                chordInt[idx] = ci
                chordFrac[idx] = (halfSpan - ci).coerceIn(0f, 1f)
            }
        }

        val strideP = bw + 1
        rowExecutor(bh) { byStart, byEnd ->
            for (by in byStart until byEnd) {
                val outRow = by * bw
                val dyMin = max(-rInt, -by)
                val dyMax = min(rInt, bh - 1 - by)

                for (bx in 0 until bw) {
                    var sumR = 0.0
                    var sumG = 0.0
                    var sumB = 0.0
                    var sumW = 0.0

                    for (dy in dyMin..dyMax) {
                        val cIdx = dy + rInt
                        val ci = chordInt[cIdx]
                        if (ci < 0) continue

                        val ny = by + dy
                        val pRow = ny * strideP
                        val xl = max(0, bx - ci)
                        val xr = min(bw - 1, bx + ci) + 1

                        sumR += prefR[pRow + xr] - prefR[pRow + xl]
                        sumG += prefG[pRow + xr] - prefG[pRow + xl]
                        sumB += prefB[pRow + xr] - prefB[pRow + xl]
                        sumW += prefW[pRow + xr] - prefW[pRow + xl]

                        // Smooth fractional anti-aliasing at circular rim endpoints
                        val frac = chordFrac[cIdx].toDouble()
                        if (frac > 1e-3) {
                            val leftEdge = bx - ci - 1
                            if (leftEdge >= 0) {
                                val lp = pRow + leftEdge
                                sumR += (prefR[lp + 1] - prefR[lp]) * frac
                                sumG += (prefG[lp + 1] - prefG[lp]) * frac
                                sumB += (prefB[lp + 1] - prefB[lp]) * frac
                                sumW += (prefW[lp + 1] - prefW[lp]) * frac
                            }
                            val rightEdge = bx + ci + 1
                            if (rightEdge < bw) {
                                val rp = pRow + rightEdge
                                sumR += (prefR[rp + 1] - prefR[rp]) * frac
                                sumG += (prefG[rp + 1] - prefG[rp]) * frac
                                sumB += (prefB[rp + 1] - prefB[rp]) * frac
                                sumW += (prefW[rp + 1] - prefW[rp]) * frac
                            }
                        }
                    }

                    val bi = outRow + bx
                    if (sumW > 1e-6) {
                        val invW = 1.0 / sumW
                        outR[bi] = (sumR * invW).toFloat().coerceIn(0f, 1f)
                        outG[bi] = (sumG * invW).toFloat().coerceIn(0f, 1f)
                        outB[bi] = (sumB * invW).toFloat().coerceIn(0f, 1f)
                    } else {
                        outR[bi] = fallbackR[bi]
                        outG[bi] = fallbackG[bi]
                        outB[bi] = fallbackB[bi]
                    }
                }
            }
        }
    }

    private fun sampleBilinear(grid: FloatArray, w: Int, h: Int, gx: Float, gy: Float): Float {
        if (w <= 1 && h <= 1) return grid[0]
        val cx = gx.coerceIn(0f, (w - 1).coerceAtLeast(0).toFloat())
        val cy = gy.coerceIn(0f, (h - 1).coerceAtLeast(0).toFloat())
        val x0 = cx.toInt().coerceIn(0, (w - 1).coerceAtLeast(0))
        val y0 = cy.toInt().coerceIn(0, (h - 1).coerceAtLeast(0))
        val x1 = (x0 + 1).coerceAtMost(w - 1)
        val y1 = (y0 + 1).coerceAtMost(h - 1)
        val fx = cx - x0
        val fy = cy - y0
        val r0 = y0 * w
        val r1 = y1 * w
        return grid[r0 + x0] * (1f - fx) * (1f - fy) +
            grid[r0 + x1] * fx * (1f - fy) +
            grid[r1 + x0] * (1f - fx) * fy +
            grid[r1 + x1] * fx * fy
    }

    internal fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        val span = (edge1 - edge0).coerceAtLeast(1e-5f)
        val t = ((x - edge0) / span).coerceIn(0f, 1f)
        return t * t * (3.0f - 2.0f * t)
    }
}
