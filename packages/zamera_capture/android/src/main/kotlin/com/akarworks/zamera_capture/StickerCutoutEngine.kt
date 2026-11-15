package com.akarworks.zamera_capture

import kotlin.math.abs
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sqrt

/**
 * Pure-Kotlin, JVM-testable Subject Lift & Sticker Cutout Engine.
 *
 * Responsibilities (SRP):
 * 1. Select ONLY the tapped subject instance from multi-subject confidence masks (ML Kit Tier 1).
 * 2. Extract a clean connected-component sticker matte at `(focusX, focusY)` using U2-NetP saliency
 *    or SelfieMulticlass human confidence WITHOUT thin-lens DoF plane slicing (Tier 2 fallback).
 * 3. Fill enclosed interior holes, perform foreground edge RGB decontamination, tight-crop to alpha,
 *    and optionally render an anti-aliased pure white (`#FFFFFF`) sticker outline + subtle drop shadow.
 */
object StickerCutoutEngine {

    data class SubjectMaskCandidate(
        val startX: Int,
        val startY: Int,
        val width: Int,
        val height: Int,
        val mask: FloatArray
    )

    data class StickerCropBuffer(
        val pixelsArgb: IntArray,
        val width: Int,
        val height: Int
    )

    /**
     * Picks the single [SubjectMaskCandidate] containing or closest to normalized `(focusX, focusY)`,
     * returning a full `fullW * fullH` float alpha array in `[0, 1]`, or `null` if no valid subject matches.
     */
    fun selectTappedSubjectMask(
        candidates: List<SubjectMaskCandidate>,
        fullW: Int,
        fullH: Int,
        focusX: Float,
        focusY: Float
    ): FloatArray? {
        if (candidates.isEmpty() || fullW <= 0 || fullH <= 0) return null
        val tx = (focusX.coerceIn(0f, 1f) * (fullW - 1)).roundToInt().coerceIn(0, fullW - 1)
        val ty = (focusY.coerceIn(0f, 1f) * (fullH - 1)).roundToInt().coerceIn(0, fullH - 1)

        var directWinner: SubjectMaskCandidate? = null
        var directBestScore = 0.22f
        var directSmallestArea = Int.MAX_VALUE

        for (cand in candidates) {
            if (cand.width <= 0 || cand.height <= 0 || cand.mask.size < cand.width * cand.height) continue
            val lx = tx - cand.startX
            val ly = ty - cand.startY
            if (lx in 0 until cand.width && ly in 0 until cand.height) {
                val conf = sampleLocalMax(cand.mask, cand.width, cand.height, lx, ly, radius = 2)
                val area = cand.width * cand.height
                // Prefer high-confidence mask directly under tap; break ties in favor of tighter foreground object
                if (conf >= 0.22f && (conf > directBestScore + 0.08f || (abs(conf - directBestScore) <= 0.08f && area < directSmallestArea))) {
                    directWinner = cand
                    directBestScore = conf
                    directSmallestArea = area
                }
            }
        }

        val chosen = directWinner ?: run {
            val maxReachPx = 0.18f * hypot(fullW.toFloat(), fullH.toFloat())
            var nearestWinner: SubjectMaskCandidate? = null
            var bestDist = Float.MAX_VALUE
            for (cand in candidates) {
                if (cand.width <= 0 || cand.height <= 0 || cand.mask.size < cand.width * cand.height) continue
                val (cx, cy, weightSum) = computeWeightedCentroid(cand)
                if (weightSum < 8f) continue
                val distToTap = if (tx in cand.startX until (cand.startX + cand.width) &&
                    ty in cand.startY until (cand.startY + cand.height)
                ) {
                    hypot((tx - cx), (ty - cy)) * 0.55f
                } else {
                    val clampedX = tx.coerceIn(cand.startX, cand.startX + cand.width - 1).toFloat()
                    val clampedY = ty.coerceIn(cand.startY, cand.startY + cand.height - 1).toFloat()
                    hypot(tx - clampedX, ty - clampedY)
                }
                if (distToTap <= maxReachPx && distToTap < bestDist) {
                    bestDist = distToTap
                    nearestWinner = cand
                }
            }
            nearestWinner
        } ?: return null

        val out = FloatArray(fullW * fullH)
        var nonZero = 0
        for (ly in 0 until chosen.height) {
            val gy = chosen.startY + ly
            if (gy !in 0 until fullH) continue
            val srcRow = ly * chosen.width
            val dstRow = gy * fullW
            for (lx in 0 until chosen.width) {
                val gx = chosen.startX + lx
                if (gx !in 0 until fullW) continue
                val raw = chosen.mask[srcRow + lx]
                val v = if (raw.isFinite()) raw.coerceIn(0f, 1f) else 0f
                out[dstRow + gx] = v
                if (v >= 0.35f) nonZero++
            }
        }
        return if (nonZero >= max(12, (fullW * fullH) / 900)) out else null
    }

    /**
     * Tier 2 fallback matte extractor at `(segW x segH)`:
     * Uses [humanProb] ONLY when human confidence directly under `(focusX, focusY)` is `>= 0.45f`;
     * otherwise extracts the 8-connected salient object from [saliencyProb] WITHOUT DoF plane slicing,
     * fills enclosed interior pockets, and snaps boundaries using 3-channel `(luma, chA, chB)` edges.
     */
    fun extractTappedStickerMatte(
        saliencyProb: FloatArray?,
        humanProb: FloatArray?,
        luma255: FloatArray,
        chA: FloatArray,
        chB: FloatArray,
        segW: Int,
        segH: Int,
        focusX: Float,
        focusY: Float
    ): FloatArray? {
        val n = segW * segH
        if (n <= 0 || segW < 4 || segH < 4) return null

        val cx = (focusX.coerceIn(0f, 1f) * (segW - 1)).roundToInt().coerceIn(0, segW - 1)
        val cy = (focusY.coerceIn(0f, 1f) * (segH - 1)).roundToInt().coerceIn(0, segH - 1)
        val probeR = (min(segW, segH) * 0.06f).roundToInt().coerceIn(2, max(2, min(segW, segH) / 5))

        val humanTapPeak = if (humanProb != null && humanProb.size >= n) {
            sampleWindowPeak(humanProb, segW, segH, cx, cy, probeR)
        } else {
            0f
        }
        val saliencyTapPeak = if (saliencyProb != null && saliencyProb.size >= n) {
            sampleWindowPeak(saliencyProb, segW, segH, cx, cy, probeR)
        } else {
            0f
        }

        val activeProb: FloatArray
        val localPeak: Float
        if (humanProb != null && humanProb.size >= n && humanTapPeak >= 0.45f) {
            activeProb = humanProb
            localPeak = humanTapPeak
        } else if (saliencyProb != null && saliencyProb.size >= n && saliencyTapPeak >= 0.34f) {
            activeProb = saliencyProb
            localPeak = saliencyTapPeak
        } else {
            return null
        }

        // Guard against completely washed-out uniform high probability across all borders
        var borderSum = 0f
        var borderCnt = 0
        val borderBand = max(1, min(segW, segH) / 24)
        for (y in 0 until segH) {
            val row = y * segW
            val isTopBot = y < borderBand || y >= segH - borderBand
            if (isTopBot) {
                for (x in 0 until segW step 2) {
                    borderSum += activeProb[row + x].coerceIn(0f, 1f)
                    borderCnt++
                }
            } else {
                for (x in 0 until borderBand) {
                    borderSum += activeProb[row + x].coerceIn(0f, 1f)
                    borderSum += activeProb[row + (segW - 1 - x)].coerceIn(0f, 1f)
                    borderCnt += 2
                }
            }
        }
        val borderMean = if (borderCnt > 0) borderSum / borderCnt else 0f
        if (localPeak - borderMean < 0.14f && borderMean > 0.55f) {
            return null
        }

        val hasPhoto = luma255.size >= n && chA.size >= n && chB.size >= n
        val edgeGrad = FloatArray(n)
        if (hasPhoto) {
            for (y in 1 until segH - 1) {
                val row = y * segW
                for (x in 1 until segW - 1) {
                    val i = row + x
                    val dl = abs(luma255[i + 1] - luma255[i - 1]) + abs(luma255[i + segW] - luma255[i - segW])
                    val da = abs(chA[i + 1] - chA[i - 1]) + abs(chA[i + segW] - chA[i - segW])
                    val db = abs(chB[i + 1] - chB[i - 1]) + abs(chB[i + segW] - chB[i - segW])
                    val dp = abs(activeProb[i + 1] - activeProb[i - 1]) + abs(activeProb[i + segW] - activeProb[i - segW])
                    edgeGrad[i] = 0.55f * dl + 1.35f * da + 1.15f * db + 24.0f * dp
                }
            }
        }

        // Single 8-connected component flood anchored strictly around (cx, cy)
        val seedThresh = max(0.38f, localPeak * 0.58f)
        val reachable = BooleanArray(n)
        val queue = IntArray(n)
        var qHead = 0
        var qTail = 0
        for (y in (cy - probeR).coerceAtLeast(0)..(cy + probeR).coerceAtMost(segH - 1)) {
            val row = y * segW
            for (x in (cx - probeR).coerceAtLeast(0)..(cx + probeR).coerceAtMost(segW - 1)) {
                val idx = row + x
                val p = activeProb[idx].coerceIn(0f, 1f)
                if (p >= seedThresh && !reachable[idx]) {
                    reachable[idx] = true
                    queue[qTail++] = idx
                }
            }
        }
        if (qTail == 0) return null

        val reachFloor = 0.16f
        while (qHead < qTail) {
            val cur = queue[qHead++]
            val curX = cur % segW
            val curY = cur / segW
            val curP = activeProb[cur].coerceIn(0f, 1f)
            val y0 = max(0, curY - 1)
            val y1 = min(segH - 1, curY + 1)
            val x0 = max(0, curX - 1)
            val x1 = min(segW - 1, curX + 1)
            for (ny in y0..y1) {
                val nRow = ny * segW
                for (nx in x0..x1) {
                    val nb = nRow + nx
                    if (reachable[nb]) continue
                    val nbP = activeProb[nb].coerceIn(0f, 1f)
                    if (nbP < reachFloor) continue
                    if (edgeGrad[nb] > 42.0f && nbP < 0.36f && (curP - nbP) > 0.22f) continue
                    reachable[nb] = true
                    queue[qTail++] = nb
                }
            }
        }

        val minPixels = max(12, n / 650)
        if (qTail < minPixels) return null

        // Fill enclosed interior pockets (flood exterior background from frame borders)
        val exteriorBg = BooleanArray(n)
        var bgHead = 0
        var bgTail = 0
        val bgQueue = IntArray(n)
        for (x in 0 until segW) {
            val top = x
            if (!reachable[top] && activeProb[top] < 0.22f && !exteriorBg[top]) {
                exteriorBg[top] = true
                bgQueue[bgTail++] = top
            }
            val bot = (segH - 1) * segW + x
            if (!reachable[bot] && activeProb[bot] < 0.22f && !exteriorBg[bot]) {
                exteriorBg[bot] = true
                bgQueue[bgTail++] = bot
            }
        }
        for (y in 0 until segH) {
            val left = y * segW
            if (!reachable[left] && activeProb[left] < 0.22f && !exteriorBg[left]) {
                exteriorBg[left] = true
                bgQueue[bgTail++] = left
            }
            val right = y * segW + (segW - 1)
            if (!reachable[right] && activeProb[right] < 0.22f && !exteriorBg[right]) {
                exteriorBg[right] = true
                bgQueue[bgTail++] = right
            }
        }
        while (bgHead < bgTail) {
            val cur = bgQueue[bgHead++]
            val curX = cur % segW
            val curY = cur / segW
            val y0 = max(0, curY - 1)
            val y1 = min(segH - 1, curY + 1)
            val x0 = max(0, curX - 1)
            val x1 = min(segW - 1, curX + 1)
            for (ny in y0..y1) {
                val nRow = ny * segW
                for (nx in x0..x1) {
                    val nb = nRow + nx
                    if (!exteriorBg[nb] && !reachable[nb]) {
                        exteriorBg[nb] = true
                        bgQueue[bgTail++] = nb
                    }
                }
            }
        }

        // Edge-barrier Chamfer geodesics for crisp silhouette snapping
        val coreThresh = max(0.46f, localPeak * 0.70f)
        val distFg = FloatArray(n) { 1e6f }
        val distBg = FloatArray(n) { 1e6f }
        val stepCost = FloatArray(n)
        for (i in 0 until n) {
            stepCost[i] = 1.0f + 1.40f * edgeGrad[i]
            val p = activeProb[i].coerceIn(0f, 1f)
            if (!exteriorBg[i] && (!reachable[i] || p >= coreThresh)) {
                distFg[i] = 0f
            }
            if (exteriorBg[i] || (reachable[i] && p <= 0.14f)) {
                distBg[i] = 0f
            }
        }

        val diag = 1.4142135f
        repeat(3) {
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

        val rawMatte = FloatArray(n)
        var fgCount = 0
        for (i in 0 until n) {
            if (exteriorBg[i] && !reachable[i]) {
                rawMatte[i] = 0f
                continue
            }
            if (!exteriorBg[i] && !reachable[i]) {
                // Interior hole enclosed inside the connected object
                rawMatte[i] = 0.96f
                fgCount++
                continue
            }
            val geoRatio = distBg[i] / (distFg[i] + distBg[i] + 1e-4f)
            val geoAlpha = smoothstep(0.35f, 0.65f, geoRatio)
            val calAlpha = smoothstep(0.22f, 0.72f, activeProb[i].coerceIn(0f, 1f))
            val combined = (0.55f * calAlpha + 0.45f * geoAlpha).coerceIn(0f, 1f)
            rawMatte[i] = when {
                combined >= 0.90f -> 1.0f
                combined <= 0.10f -> 0.0f
                else -> combined
            }
            if (rawMatte[i] >= 0.50f) fgCount++
        }
        if (fgCount < minPixels) return null

        // 3-channel (L, A, B) joint bilateral refinement on boundary band only
        if (!hasPhoto) return rawMatte
        val refined = rawMatte.copyOf()
        val invColorSigma2 = 1.0f / (2.0f * 26.0f * 26.0f)
        for (y in 2 until segH - 2) {
            val row = y * segW
            for (x in 2 until segW - 2) {
                val i = row + x
                val cAlpha = rawMatte[i]
                if (cAlpha <= 0.01f || cAlpha >= 0.99f) continue
                val l0 = luma255[i]
                val a0 = chA[i]
                val b0 = chB[i]
                var wSum = 0f
                var vSum = 0f
                for (dy in -2..2) {
                    val nRow = (y + dy) * segW
                    for (dx in -2..2) {
                        val ni = nRow + (x + dx)
                        val dl = luma255[ni] - l0
                        val da = chA[ni] - a0
                        val db = chB[ni] - b0
                        val colorDistSq = dl * dl + 1.4f * da * da + 1.4f * db * db
                        val w = kotlin.math.exp(-colorDistSq * invColorSigma2)
                        wSum += w
                        vSum += w * rawMatte[ni]
                    }
                }
                if (wSum > 1e-5f) {
                    refined[i] = (vSum / wSum).coerceIn(0f, 1f)
                }
            }
        }
        return refined
    }

    /**
     * Composes the final tightly cropped ARGB_8888 pixel array with true `0x00000000` background,
     * foreground RGB edge decontamination, and optional smooth white sticker contour + soft shadow.
     */
    fun composeStickerRgbaCrop(
        srcArgb: IntArray,
        srcW: Int,
        srcH: Int,
        fullAlpha01: FloatArray,
        addWhiteOutline: Boolean,
        outlineRadiusPx: Int = 0
    ): StickerCropBuffer? {
        val total = srcW * srcH
        if (srcW <= 0 || srcH <= 0 || srcArgb.size < total || fullAlpha01.size < total) {
            return null
        }

        val alphaInt = IntArray(total)
        var minX = srcW
        var minY = srcH
        var maxX = -1
        var maxY = -1
        var corePixels = 0

        for (y in 0 until srcH) {
            val rowOff = y * srcW
            for (x in 0 until srcW) {
                val idx = rowOff + x
                val raw = fullAlpha01[idx]
                val clamped = if (raw.isFinite()) raw.coerceIn(0f, 1f) else 0f
                val tFg = ((clamped - 0.18f) / 0.68f).coerceIn(0f, 1f)
                val smooth = tFg * tFg * (3.0f - 2.0f * tFg)
                val a = (smooth * 255.0f).roundToInt().coerceIn(0, 255)
                if (a > 12) {
                    alphaInt[idx] = a
                    if (a > 24) {
                        corePixels++
                        if (x < minX) minX = x
                        if (x > maxX) maxX = x
                        if (y < minY) minY = y
                        if (y > maxY) maxY = y
                    }
                } else {
                    alphaInt[idx] = 0
                }
            }
        }

        if (corePixels < 8 || maxX < minX || maxY < minY) {
            return null
        }

        val bboxSpanMin = min(maxX - minX + 1, maxY - minY + 1)
        val effectiveOutline = if (addWhiteOutline) {
            if (outlineRadiusPx > 0) outlineRadiusPx else max(6, (bboxSpanMin * 0.028f).roundToInt()).coerceAtMost(36)
        } else {
            0
        }
        val shadowExtra = if (addWhiteOutline) 6 else 0
        val pad = 12 + effectiveOutline + shadowExtra

        val cMinX = (minX - pad).coerceAtLeast(0)
        val cMinY = (minY - pad).coerceAtLeast(0)
        val cMaxX = (maxX + pad).coerceAtMost(srcW - 1)
        val cMaxY = (maxY + pad).coerceAtMost(srcH - 1)
        val cropW = (cMaxX - cMinX + 1).coerceAtLeast(1)
        val cropH = (cMaxY - cMinY + 1).coerceAtLeast(1)
        val cropN = cropW * cropH

        val cropAlpha = IntArray(cropN)
        val cropRgb = IntArray(cropN)
        for (cy in 0 until cropH) {
            val srcRow = (cMinY + cy) * srcW + cMinX
            val dstRow = cy * cropW
            for (cx in 0 until cropW) {
                cropAlpha[dstRow + cx] = alphaInt[srcRow + cx]
                cropRgb[dstRow + cx] = srcArgb[srcRow + cx]
            }
        }

        // Foreground RGB color decontamination along semi-transparent edges (eliminates dark/color halos)
        val outPixels = IntArray(cropN)
        for (cy in 0 until cropH) {
            val rowOff = cy * cropW
            for (cx in 0 until cropW) {
                val i = rowOff + cx
                val a = cropAlpha[i]
                if (a <= 12) {
                    outPixels[i] = 0x00000000
                    continue
                }
                val sp = cropRgb[i]
                var r = (sp shr 16) and 0xFF
                var g = (sp shr 8) and 0xFF
                var b = sp and 0xFF
                if (a < 242) {
                    var sumR = 0
                    var sumG = 0
                    var sumB = 0
                    var cnt = 0
                    for (dy in -2..2) {
                        val ny = cy + dy
                        if (ny !in 0 until cropH) continue
                        val nRow = ny * cropW
                        for (dx in -2..2) {
                            val nx = cx + dx
                            if (nx !in 0 until cropW) continue
                            val ni = nRow + nx
                            if (cropAlpha[ni] >= 242) {
                                val np = cropRgb[ni]
                                sumR += (np shr 16) and 0xFF
                                sumG += (np shr 8) and 0xFF
                                sumB += np and 0xFF
                                cnt++
                            }
                        }
                    }
                    if (cnt > 0) {
                        val fgR = sumR / cnt
                        val fgG = sumG / cnt
                        val fgB = sumB / cnt
                        val blend = ((242 - a) / 230.0f).coerceIn(0f, 1f)
                        r = (r * (1f - blend) + fgR * blend).roundToInt().coerceIn(0, 255)
                        g = (g * (1f - blend) + fgG * blend).roundToInt().coerceIn(0, 255)
                        b = (b * (1f - blend) + fgB * blend).roundToInt().coerceIn(0, 255)
                    }
                }
                outPixels[i] = (a shl 24) or (r shl 16) or (g shl 8) or b
            }
        }

        if (!addWhiteOutline || effectiveOutline <= 0) {
            return StickerCropBuffer(outPixels, cropW, cropH)
        }

        // Exact 2D Chamfer Euclidean Distance Transform (O(W*H)) for smooth white sticker border + soft shadow
        val dist = FloatArray(cropN) { idx -> if (cropAlpha[idx] >= 122) 0f else 1e6f }
        val diag = 1.4142135f
        for (y in 0 until cropH) {
            val row = y * cropW
            for (x in 0 until cropW) {
                val i = row + x
                if (dist[i] == 0f) continue
                var m = dist[i]
                if (x > 0) m = min(m, dist[i - 1] + 1f)
                if (y > 0) {
                    m = min(m, dist[i - cropW] + 1f)
                    if (x > 0) m = min(m, dist[i - cropW - 1] + diag)
                    if (x + 1 < cropW) m = min(m, dist[i - cropW + 1] + diag)
                }
                dist[i] = m
            }
        }
        for (y in cropH - 1 downTo 0) {
            val row = y * cropW
            for (x in cropW - 1 downTo 0) {
                val i = row + x
                if (dist[i] == 0f) continue
                var m = dist[i]
                if (x + 1 < cropW) m = min(m, dist[i + 1] + 1f)
                if (y + 1 < cropH) {
                    m = min(m, dist[i + cropW] + 1f)
                    if (x + 1 < cropW) m = min(m, dist[i + cropW + 1] + diag)
                    if (x > 0) m = min(m, dist[i + cropW - 1] + diag)
                }
                dist[i] = m
            }
        }

        val outlineR = effectiveOutline.toFloat()
        val shadowEnd = outlineR + 4.5f
        val finalPixels = IntArray(cropN)

        for (y in 0 until cropH) {
            val row = y * cropW
            for (x in 0 until cropW) {
                val i = row + x
                val fgP = outPixels[i]
                val fgA = (fgP ushr 24) and 0xFF
                val d = dist[i]

                // White contour band with anti-aliased outer edge
                val borderAlphaF = when {
                    d <= outlineR - 0.8f -> 1.0f
                    d < outlineR + 1.0f -> 1.0f - smoothstep(outlineR - 0.8f, outlineR + 1.0f, d)
                    else -> 0.0f
                }

                // Subtle soft drop shadow beneath sticker border (offset +2px downward)
                val shadowDist = if (y >= 2) dist[(y - 2) * cropW + x] else d
                val shadowAlphaF = if (shadowDist > outlineR - 0.5f && shadowDist < shadowEnd) {
                    0.18f * (1.0f - smoothstep(outlineR, shadowEnd, shadowDist))
                } else {
                    0.0f
                }

                // Underlay compositing: shadow -> white border -> foreground subject
                var bgA = shadowAlphaF
                var bgR = 0f
                var bgG = 0f
                var bgB = 0f

                if (borderAlphaF > 0f) {
                    val outA = borderAlphaF + bgA * (1f - borderAlphaF)
                    if (outA > 1e-5f) {
                        bgR = (255f * borderAlphaF + bgR * bgA * (1f - borderAlphaF)) / outA
                        bgG = (255f * borderAlphaF + bgG * bgA * (1f - borderAlphaF)) / outA
                        bgB = (255f * borderAlphaF + bgB * bgA * (1f - borderAlphaF)) / outA
                    }
                    bgA = outA
                }

                val fgAF = fgA / 255.0f
                val outAF = (fgAF + bgA * (1f - fgAF)).coerceIn(0f, 1f)
                val outAInt = (outAF * 255.0f).roundToInt().coerceIn(0, 255)
                if (outAInt <= 1) {
                    finalPixels[i] = 0x00000000
                } else {
                    val fgR = ((fgP shr 16) and 0xFF).toFloat()
                    val fgG = ((fgP shr 8) and 0xFF).toFloat()
                    val fgB = (fgP and 0xFF).toFloat()
                    val mix = 1f - fgAF
                    val r = ((fgR * fgAF + bgR * bgA * mix) / outAF).roundToInt().coerceIn(0, 255)
                    val g = ((fgG * fgAF + bgG * bgA * mix) / outAF).roundToInt().coerceIn(0, 255)
                    val b = ((fgB * fgAF + bgB * bgA * mix) / outAF).roundToInt().coerceIn(0, 255)
                    finalPixels[i] = (outAInt shl 24) or (r shl 16) or (g shl 8) or b
                }
            }
        }
        return StickerCropBuffer(finalPixels, cropW, cropH)
    }

    private fun computeWeightedCentroid(cand: SubjectMaskCandidate): Triple<Float, Float, Float> {
        var sumX = 0f
        var sumY = 0f
        var wSum = 0f
        for (y in 0 until cand.height) {
            val row = y * cand.width
            for (x in 0 until cand.width) {
                val v = cand.mask[row + x]
                if (v.isFinite() && v >= 0.25f) {
                    sumX += (cand.startX + x) * v
                    sumY += (cand.startY + y) * v
                    wSum += v
                }
            }
        }
        return if (wSum > 0f) Triple(sumX / wSum, sumY / wSum, wSum) else Triple(0f, 0f, 0f)
    }

    private fun sampleLocalMax(
        mask: FloatArray,
        w: Int,
        h: Int,
        cx: Int,
        cy: Int,
        radius: Int
    ): Float {
        var best = 0f
        for (y in (cy - radius).coerceAtLeast(0)..(cy + radius).coerceAtMost(h - 1)) {
            val row = y * w
            for (x in (cx - radius).coerceAtLeast(0)..(cx + radius).coerceAtMost(w - 1)) {
                val v = mask[row + x]
                if (v.isFinite() && v > best) best = v
            }
        }
        return best
    }

    private fun sampleWindowPeak(
        arr: FloatArray,
        w: Int,
        h: Int,
        cx: Int,
        cy: Int,
        radius: Int
    ): Float {
        var best = 0f
        for (y in (cy - radius).coerceAtLeast(0)..(cy + radius).coerceAtMost(h - 1)) {
            val row = y * w
            for (x in (cx - radius).coerceAtLeast(0)..(cx + radius).coerceAtMost(w - 1)) {
                val v = arr[row + x]
                if (v.isFinite() && v > best) best = v
            }
        }
        return best
    }

    private fun smoothstep(edge0: Float, edge1: Float, x: Float): Float {
        val span = (edge1 - edge0).coerceAtLeast(1e-5f)
        val t = ((x - edge0) / span).coerceIn(0f, 1f)
        return t * t * (3.0f - 2.0f * t)
    }
}
