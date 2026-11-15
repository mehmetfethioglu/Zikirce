package com.akarworks.zamera_capture

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * Lightweight zero-dependency ContentProvider exposing Zamera local stickers,
 * captured video frames, and session media under `filesDir` and `cacheDir`
 * via `content://${applicationId}.zamera_provider/...` URIs.
 */
class ZameraMediaFileProvider : ContentProvider() {

    companion object {
        private const val FILES_ROOT = "files"
        private const val CACHE_ROOT = "cache"

        private val MIME_BY_EXT = mapOf(
            "png" to "image/png",
            "jpg" to "image/jpeg",
            "jpeg" to "image/jpeg",
            "dng" to "image/x-adobe-dng",
            "mp4" to "video/mp4",
            "mov" to "video/quicktime",
        )

        fun authority(context: Context): String = "${context.packageName}.zamera_provider"

        fun uriForFile(context: Context, file: File): Uri? {
            val canonicalTarget = runCatching { file.canonicalFile }.getOrNull() ?: return null
            val filesRoot = runCatching { context.filesDir.canonicalFile }.getOrNull()
            val cacheRoot = runCatching { context.cacheDir.canonicalFile }.getOrNull()

            val (rootSegment, relPath) = when {
                filesRoot != null && isDescendant(canonicalTarget, filesRoot) ->
                    FILES_ROOT to canonicalTarget.relativeTo(filesRoot).path.replace(File.separatorChar, '/')
                cacheRoot != null && isDescendant(canonicalTarget, cacheRoot) ->
                    CACHE_ROOT to canonicalTarget.relativeTo(cacheRoot).path.replace(File.separatorChar, '/')
                else -> return null
            }

            val builder = Uri.Builder()
                .scheme("content")
                .authority(authority(context))
                .appendPath(rootSegment)
            for (seg in relPath.split('/')) {
                if (seg.isNotEmpty()) builder.appendPath(seg)
            }
            return builder.build()
        }

        private fun isDescendant(target: File, root: File): Boolean {
            val rootPath = root.path.trimEnd(File.separatorChar) + File.separatorChar
            return target.path.startsWith(rootPath)
        }
    }

    override fun onCreate(): Boolean = true

    override fun getType(uri: Uri): String {
        val file = resolveSafeFile(uri)
        val ext = file?.extension?.lowercase() ?: uri.lastPathSegment?.substringAfterLast('.', "")?.lowercase().orEmpty()
        return MIME_BY_EXT[ext] ?: "application/octet-stream"
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r" && mode != "rt") {
            throw SecurityException("ZameraMediaFileProvider only supports read-only access")
        }
        val target = resolveSafeFile(uri)
            ?: throw FileNotFoundException("Invalid or missing file for URI: $uri")
        return ParcelFileDescriptor.open(target, ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?
    ): Cursor? {
        val file = resolveSafeFile(uri) ?: return null
        val cols = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val cursor = MatrixCursor(cols, 1)
        val row = Array<Any?>(cols.size) { idx ->
            when (cols[idx]) {
                OpenableColumns.DISPLAY_NAME -> file.name
                OpenableColumns.SIZE -> file.length()
                else -> null
            }
        }
        cursor.addRow(row)
        return cursor
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?
    ): Int = 0

    private fun resolveSafeFile(uri: Uri): File? {
        val ctx = context ?: return null
        val segs = uri.pathSegments
        if (segs.size < 2) return null
        val rootDir = when (segs[0]) {
            FILES_ROOT -> ctx.filesDir
            CACHE_ROOT -> ctx.cacheDir
            else -> return null
        }
        val rel = segs.drop(1).joinToString(File.separator)
        val canonicalRoot = runCatching { rootDir.canonicalFile }.getOrNull() ?: return null
        val candidate = runCatching { File(canonicalRoot, rel).canonicalFile }.getOrNull() ?: return null
        if (!isDescendant(candidate, canonicalRoot) || !candidate.exists() || !candidate.isFile) {
            return null
        }
        return candidate
    }
}
