package com.akarworks.zamera_capture

import kotlin.math.abs
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

internal class ZameraCapturePluginTest {

    @Test
    fun cocMap_groundsFocalPlaneDeadBand_andScalesInverselyWithAperture() {
        val w = 64
        val h = 16
        val n = w * h
        val focusDepth = 0.72f
        // Horizontal depth ramp from 1.0 (closest foreground) on left to 0.05 (far background) on right
        val depthMap = FloatArray(n) { idx ->
            val x = idx % w
            1.0f - (x.toFloat() / (w - 1).toFloat()) * 0.95f
        }
        val fgAlpha = FloatArray(n)

        val cocF14 = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 1.4f, fgAlpha, w, h)
        val cocF28 = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 2.8f, fgAlpha, w, h)
        val cocF56 = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 5.6f, fgAlpha, w, h)
        val cocF16 = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 16.0f, fgAlpha, w, h)

        val bandF28 = PortraitOpticalEngine.dofHalfBand(2.8f)
        var groundedCount = 0
        for (x in 0 until w) {
            val d = depthMap[x]
            if (abs(d - focusDepth) <= bandF28) {
                assertEquals(0.0f, cocF28[x], 1e-6f, "Contact surface inside DoF dead-band must have exact CoC=0")
                groundedCount++
            }
        }
        assertTrue(groundedCount >= 4, "Focal-plane dead-band must ground multiple contact pixels")

        // Progressive monotonic transition behind focal plane (far right x = w - 1 has d = 0.05)
        val midIdx = (w * 0.55f).toInt()
        val farIdx = w - 1
        assertTrue(cocF28[midIdx] > 0.0f, "Midground behind DoF band must begin gentle CoC transition")
        assertTrue(cocF28[farIdx] > cocF28[midIdx], "Far background must have larger CoC than midground")

        // Thin-lens 1/aperture scaling on far background
        assertTrue(cocF14[farIdx] > cocF28[farIdx], "f/1.4 must produce deeper CoC than f/2.8")
        assertTrue(cocF28[farIdx] > cocF56[farIdx], "f/2.8 must produce deeper CoC than f/5.6")
        assertTrue(cocF56[farIdx] > cocF16[farIdx], "f/5.6 must produce deeper CoC than f/16.0")

        // Subject matte attenuation: CoC *= (1 - fgAlpha)
        val fgWithSubject = FloatArray(n) { idx -> if (idx == farIdx) 1.0f else if (idx == farIdx - 1) 0.6f else 0.0f }
        val cocProtected = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 2.0f, fgWithSubject, w, h)
        val cocUnprotected = PortraitOpticalEngine.computeCoCMap(depthMap, focusDepth, 2.0f, null, w, h)
        assertEquals(0.0f, cocProtected[farIdx], 1e-6f, "Opaque subject pixel (fgAlpha=1) must have CoC=0")
        assertEquals(
            cocUnprotected[farIdx - 1] * 0.4f,
            cocProtected[farIdx - 1],
            1e-4f,
            "Semi-transparent edge must scale CoC by (1 - fgAlpha)"
        )
    }

    @Test
    fun focusedObjectMatte_producesZeroRadialCloudOnLowSaliency_andIsolatesConnectedPlaneObject() {
        val w = 64
        val h = 64
        val n = w * h

        // 1. Calibrated U2-NetP fusion must NEVER min-max stretch low-signal background noise
        val lowD0 = FloatArray(n) { 0.04f }
        val lowD1 = FloatArray(n) { 0.05f }
        val calibratedLow = PortraitOpticalEngine.fuseCalibratedU2NetOutputs(lowD0, lowD1)
        for (v in calibratedLow) {
            assertEquals(0.78f * 0.04f + 0.22f * 0.05f, v, 1e-5f)
        }

        // 2. Low-saliency flat scene -> 100% zero matte everywhere (zero radial cloud / zero center seed rectangle)
        val flatLuma = FloatArray(n) { 128f }
        val flatChA = FloatArray(n) { 0f }
        val flatChB = FloatArray(n) { 0f }
        val flatDepth = FloatArray(n) { 0.70f }
        val emptyMatte = PortraitOpticalEngine.extractFocusedObjectMatte(
            u2netProb = calibratedLow,
            depthMap = flatDepth,
            focusDepth = 0.70f,
            luma255 = flatLuma,
            chA = flatChA,
            chB = flatChB,
            segW = w,
            segH = h,
            focusX = 0.5f,
            focusY = 0.5f
        )
        for (i in 0 until n) {
            assertEquals(0.0f, emptyMatte[i], 1e-6f, "Low-saliency scene must emit zero artificial cloud at index $i")
        }

        // 3. Tall focused bottle reaching top/bottom borders + background object + disconnected same-depth object
        val u2 = FloatArray(n) { 0.02f }
        val depth = FloatArray(n) { 0.20f }
        val luma = FloatArray(n) { 60f }
        val chA = FloatArray(n) { -4f }
        val chB = FloatArray(n) { -6f }

        for (y in 0 until h) {
            for (x in 0 until w) {
                val i = y * w + x
                // Object A: Tall bottle at x in 27..35 spanning y in 2..61 at focusDepth = 0.78
                if (x in 27..35 && y in 2..61) {
                    u2[i] = 0.94f
                    depth[i] = 0.78f
                    luma[i] = 210f
                    chA[i] = 28f
                    chB[i] = 22f
                }
                // Object B: Salient background object at x in 6..16, y in 20..44 but far depth = 0.18
                if (x in 6..16 && y in 20..44) {
                    u2[i] = 0.96f
                    depth[i] = 0.18f
                    luma[i] = 205f
                    chA[i] = 25f
                    chB[i] = 20f
                }
                // Object C: Disconnected salient object at x in 50..58, y in 24..40 at same depth = 0.78
                if (x in 50..58 && y in 24..40) {
                    u2[i] = 0.93f
                    depth[i] = 0.78f
                    luma[i] = 200f
                    chA[i] = 24f
                    chB[i] = 18f
                }
            }
        }

        val matte = PortraitOpticalEngine.extractFocusedObjectMatte(
            u2netProb = u2,
            depthMap = depth,
            focusDepth = 0.78f,
            luma255 = luma,
            chA = chA,
            chB = chB,
            segW = w,
            segH = h,
            focusX = 31f / 63f,
            focusY = 32f / 63f
        )

        // Tall bottle preserved both at center AND near top/bottom frame edges (proves zero radial dome!)
        assertTrue(matte[32 * w + 31] > 0.92f, "Focused object center must be solid foreground")
        assertTrue(matte[4 * w + 31] > 0.85f, "Tall object top extremity must not be clipped by radial dome")
        assertTrue(matte[59 * w + 31] > 0.85f, "Tall object bottom extremity must not be clipped by radial dome")

        // Background object at depth=0.18 rejected by 3D focusDepth plane compatibility
        assertEquals(0.0f, matte[32 * w + 11], 1e-5f, "Salient object on far depth plane must be rejected")

        // Disconnected object on same depth plane rejected by 8-connected component isolation
        assertEquals(0.0f, matte[32 * w + 54], 1e-5f, "Disconnected side object must be excluded from matte")
    }

    @Test
    fun linearDiscBokeh_rendersCircularSpecularDisc_preventsForegroundBleed_andAvoidsOrtonCloud() {
        val w = 80
        val h = 80
        val n = w * h
        val darkPixel = PortraitLightingRegistry.packArgb(12f, 12f, 12f)
        val brightSpec = PortraitLightingRegistry.packArgb(255f, 255f, 255f)

        // 1. Single specular highlight point at (40, 40) with full CoC = 1.0 -> Euclidean circular bokeh disc
        val specSrc = IntArray(n) { darkPixel }
        specSrc[40 * w + 40] = brightSpec
        val fullCoC = FloatArray(n) { 1.0f }

        val renderedDisc = PortraitOpticalEngine.renderLinearDiscBokeh(
            srcPixels = specSrc,
            width = w,
            height = h,
            cocMap = fullCoC,
            fgAlphaMap = null,
            mapW = w,
            mapH = h,
            aperture = 1.4f,
            lightingMode = 0
        )

        val axialRightG = (renderedDisc[40 * w + 45] shr 8) and 0xFF   // dist = 5.0 (inside r3 = 5.5)
        val diagInsideG = (renderedDisc[43 * w + 43] shr 8) and 0xFF   // dist = 4.24 (inside r3 = 5.5)
        val cornerOutsideG = (renderedDisc[45 * w + 45] shr 8) and 0xFF // dist = 7.07 (outside r3 = 5.5)

        assertTrue(axialRightG > 36, "Axial pixel inside circular aperture disc must receive boosted specular light (got $axialRightG)")
        assertTrue(diagInsideG > 36, "Diagonal pixel inside circular aperture disc must be lit (got $diagInsideG)")
        assertEquals(12, cornerOutsideG, "Box corner outside Euclidean disc radius must remain dark (true circle, not square box)")

        // 2. Foreground occlusion weight (1 - fgAlpha)^3 prevents bright foreground bleeding into dark background
        val occSrc = IntArray(n)
        val occFg = FloatArray(n)
        val occCoC = FloatArray(n)
        for (y in 0 until h) {
            for (x in 0 until w) {
                val i = y * w + x
                if (x < 40) {
                    occSrc[i] = PortraitLightingRegistry.packArgb(255f, 0f, 0f)
                    occFg[i] = 1.0f
                    occCoC[i] = 0.0f
                } else {
                    occSrc[i] = PortraitLightingRegistry.packArgb(20f, 20f, 20f)
                    occFg[i] = 0.0f
                    occCoC[i] = 1.0f
                }
            }
        }

        val occOut = PortraitOpticalEngine.renderLinearDiscBokeh(
            srcPixels = occSrc,
            width = w,
            height = h,
            cocMap = occCoC,
            fgAlphaMap = occFg,
            mapW = w,
            mapH = h,
            aperture = 1.8f,
            lightingMode = 0
        )

        val fgPx = occOut[40 * w + 39]
        assertEquals(255, (fgPx shr 16) and 0xFF, "In-focus foreground pixel must remain 100% sharp")
        assertEquals(0, (fgPx shr 8) and 0xFF)

        val bgNearBoundary = occOut[40 * w + 41]
        assertEquals(20, (bgNearBoundary shr 16) and 0xFF, "Foreground red must have zero halo bleed into adjacent blurred background")
        assertEquals(20, (bgNearBoundary shr 8) and 0xFF)
        assertEquals(20, bgNearBoundary and 0xFF)
    }

    @Test
    fun lightingRegistry_supportsAllModes_preventsStudioContourBgDarkening_andSeparatesStageHighKey() {
        val supported = PortraitLightingRegistry.supportedModes()
        for (mode in 0..9) {
            assertTrue(supported.contains(mode), "PortraitLightingRegistry must include mode $mode")
        }

        val params = PortraitLightingFrameParams(
            width = 100,
            height = 100,
            focusX = 0.5f,
            focusY = 0.5f,
            intensity = 0.85f
        )

        // Studio (1) & Contour (2): Background (fgAlpha = 0) MUST NOT be darkened (eliminates dark cloud ring)
        val bgExpected = PortraitLightingRegistry.packArgb(140f, 150f, 160f)
        val studioBg = PortraitLightingRegistry.get(1).applyPixel(
            10, 10, 140f, 150f, 160f, 140f, 150f, 160f, 0.0f, 0.8f, params
        )
        val contourBg = PortraitLightingRegistry.get(2).applyPixel(
            10, 10, 140f, 150f, 160f, 140f, 150f, 160f, 0.0f, 0.8f, params
        )
        assertEquals(bgExpected, studioBg, "Studio Light must not darken background pixels")
        assertEquals(bgExpected, contourBg, "Contour Light must not darken background pixels")

        // Studio (1) lifts subject midtones when fgAlpha = 1
        val studioFg = PortraitLightingRegistry.get(1).applyPixel(
            50, 50, 120f, 110f, 100f, 120f, 110f, 100f, 1.0f, 0.0f, params
        )
        assertTrue(((studioFg shr 16) and 0xFF) > 120, "Studio Light must lift subject midtones")

        // Stage (3) & Stage Mono (4): Background outside tight matte is exact #000000
        val stageBg = PortraitLightingRegistry.get(3).applyPixel(
            10, 10, 180f, 180f, 180f, 180f, 180f, 180f, 0.0f, 0.9f, params
        )
        val stageMonoBg = PortraitLightingRegistry.get(4).applyPixel(
            10, 10, 180f, 180f, 180f, 180f, 180f, 180f, 0.0f, 0.9f, params
        )
        assertEquals(0xFF000000.toInt(), stageBg, "Stage Light backdrop must be exact #000000")
        assertEquals(0xFF000000.toInt(), stageMonoBg, "Stage Mono backdrop must be exact #000000")

        // High-Key Mono (5): Background outside tight matte is exact #F7F7F9
        val highKeyBg = PortraitLightingRegistry.get(5).applyPixel(
            10, 10, 80f, 80f, 80f, 80f, 80f, 80f, 0.0f, 0.9f, params
        )
        assertEquals(247, (highKeyBg shr 16) and 0xFF, "High-Key backdrop R must be 0xF7 (247)")
        assertEquals(247, (highKeyBg shr 8) and 0xFF, "High-Key backdrop G must be 0xF7 (247)")
        assertEquals(249, highKeyBg and 0xFF, "High-Key backdrop B must be 0xF9 (249)")

        // OCP runtime registration of custom lighting strategy without modifying engine
        PortraitLightingRegistry.register(77) { _, _, _, _, _, _, _, _, _, _, _ ->
            PortraitLightingRegistry.packArgb(12f, 34f, 56f)
        }
        val customOut = PortraitLightingRegistry.get(77).applyPixel(
            0, 0, 0f, 0f, 0f, 0f, 0f, 0f, 0f, 0f, params
        )
        assertEquals(PortraitLightingRegistry.packArgb(12f, 34f, 56f), customOut)

        // PortraitSessionCache LRU=1 eviction & clear() lifecycle
        val cache = PortraitSessionCache(maxEntries = 1)
        cache.put(
            PortraitSessionCache.Entry(
                sourceJpegPath = "/tmp/shot_1.jpg",
                lastModified = 100L,
                fileLength = 2048L,
                segW = 32,
                segH = 32,
                depthMap = FloatArray(32 * 32) { 0.5f }
            )
        )
        assertEquals(1, cache.size())
        cache.put(
            PortraitSessionCache.Entry(
                sourceJpegPath = "/tmp/shot_2.jpg",
                lastModified = 200L,
                fileLength = 4096L,
                segW = 32,
                segH = 32,
                depthMap = FloatArray(32 * 32) { 0.8f }
            )
        )
        assertEquals(1, cache.size(), "PortraitSessionCache must strictly enforce LRU=1 capacity")
        assertNull(cache.get("/tmp/shot_1.jpg", 100L, 2048L), "Older session entry must be evicted")
        assertTrue(cache.get("/tmp/shot_2.jpg", 200L, 4096L) != null, "Newest session entry must be retained")
        cache.clear()
        assertEquals(0, cache.size(), "clear() must release all cached tensors")
    }

    @Test
    fun isotropicLetterbox_preservesVerticalPortraitAspectRatio_andResamplesActiveRoiOnly() {
        val geom = PortraitOpticalEngine.computeIsotropicLetterbox(3072, 4096, 686, 518)
        assertEquals(389, geom.activeW)
        assertEquals(518, geom.activeH)
        assertEquals(148, geom.padX)
        assertEquals(0, geom.padY)

        // Fill padding with sentinel outlier (-500f) and active ROI with vertical gradient [10f .. 110f]
        val raw = FloatArray(686 * 518) { -500f }
        for (y in 0 until geom.activeH) {
            val v = 10f + (y.toFloat() / (geom.activeH - 1).toFloat()) * 100f
            val row = y * 686
            for (x in geom.padX until (geom.padX + geom.activeW)) {
                raw[row + x] = v
            }
        }
        val mapped = PortraitOpticalEngine.resampleLetterboxDepthRoi(raw, geom, 48, 64)!!
        assertTrue(mapped[0] < 0.05f, "Top of active ROI must map to ~0.0 without padding contamination")
        assertTrue(mapped[32 * 48 + 24] in 0.42f..0.58f, "Middle of active ROI must map to ~0.5")
        assertTrue(mapped[63 * 48 + 47] > 0.95f, "Bottom of active ROI must map to ~1.0")
    }
}
