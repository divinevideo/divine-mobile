// ABOUTME: Opens the system document picker for one audio file and returns a cached copy.
// ABOUTME: Streams the copy to disk, so a picked file of any size never enters the Java heap.

package co.openvine.app

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.DocumentsContract
import android.provider.OpenableColumns
import android.util.Log
import android.webkit.MimeTypeMap
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.IOException
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The Android audio picker behind `AudioFilePickerService` (#10065).
 *
 * `file_selector_android` reads every picked file into a `byte[]` and sends
 * those bytes over the platform channel, which runs a 256 MB heap out of
 * memory on a file of roughly 150 MB. The app only ever needs a path and a
 * name, so this picker sends the same intent but copies the pick to the cache
 * with a stream, off the main thread, and replies with the copy's path.
 */
class AudioFilePickerPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val CHANNEL = "divine/audio_file_picker"
        private const val TAG = "AudioFilePicker"

        // FragmentActivity only accepts request codes in the lower 16 bits.
        private const val REQUEST_CODE_PICK_AUDIO = 7461

        // Holds the latest pick only: every caller copies the pick into
        // library storage straight away, so the previous one is cleared
        // before the next is written.
        private const val PICKS_DIR = "audio_picks"
        private const val FALLBACK_BASE_NAME = "audio"
    }

    private var channel: MethodChannel? = null
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingResult: MethodChannel.Result? = null
    private var copyExecutor: ExecutorService? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        copyExecutor = Executors.newSingleThreadExecutor()
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        pendingResult = null
        copyExecutor?.shutdown()
        copyExecutor = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    // A pick survives a configuration change: the result reaches the
    // recreated activity, which re-registers this listener.
    override fun onDetachedFromActivityForConfigChanges() = releaseActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        releaseActivity()
        // No activity is left to deliver the result, so the pick ends unchosen
        // rather than blocking every later pick with `already_active`.
        pendingResult?.success(null)
        pendingResult = null
    }

    private fun releaseActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickAudioFile") {
            result.notImplemented()
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "No activity is available to open the picker.", null)
            return
        }
        if (pendingResult != null) {
            result.error("already_active", "An audio pick is already in progress.", null)
            return
        }

        val intent = buildPickIntent(
            mimeTypes = call.argument<List<String>>("mimeTypes").orEmpty(),
            extensions = call.argument<List<String>>("extensions").orEmpty(),
            initialUri = call.argument<String>("initialUri"),
        )
        pendingResult = result
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_CODE_PICK_AUDIO)
        } catch (e: ActivityNotFoundException) {
            pendingResult = null
            result.error("no_picker", e.message, null)
        }
    }

    // Sends what `file_selector_android` sends: the MIME types plus those of
    // the extensions, as a `String[]` extra under a wildcard type. A plain
    // `String` extra reads as "accept everything" to the system picker.
    private fun buildPickIntent(
        mimeTypes: List<String>,
        extensions: List<String>,
        initialUri: String?,
    ): Intent {
        val mimeTypeMap = MimeTypeMap.getSingleton()
        val allMimeTypes = (mimeTypes + extensions.mapNotNull(mimeTypeMap::getMimeTypeFromExtension))
            .toSet()

        return Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            when (allMimeTypes.size) {
                0 -> type = "*/*"
                1 -> type = allMimeTypes.first()
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, allMimeTypes.toTypedArray())
                }
            }
            if (initialUri != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                putExtra(DocumentsContract.EXTRA_INITIAL_URI, Uri.parse(initialUri))
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_PICK_AUDIO) return false
        val result = pendingResult ?: return true
        pendingResult = null

        val uri = data?.data
        val context = activityBinding?.activity?.applicationContext
        val executor = copyExecutor
        if (resultCode != Activity.RESULT_OK || uri == null || context == null || executor == null) {
            result.success(null)
            return true
        }

        executor.execute {
            try {
                val picked = copyToCache(context, uri)
                postReply { result.success(picked) }
            } catch (e: Exception) {
                // IOException for a failed copy, SecurityException when a provider
                // refuses the stream (flutter/flutter#100025).
                Log.w(TAG, "Copying the picked audio file failed", e)
                postReply { result.error("copy_failed", e.message, null) }
            }
        }
        return true
    }

    /** Replies on the main thread, unless the engine detached during the copy. */
    private fun postReply(reply: () -> Unit) {
        mainHandler.post {
            if (channel != null) reply()
        }
    }

    /** Copies the picked document into [PICKS_DIR] and returns the copy's path. */
    private fun copyToCache(context: Context, uri: Uri): String {
        val resolver = context.contentResolver
        val displayName = resolver.query(
            uri,
            arrayOf(OpenableColumns.DISPLAY_NAME),
            null,
            null,
            null,
        )?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null
        }
        val mimeExtension = MimeTypeMap.getSingleton()
            .getExtensionFromMimeType(resolver.getType(uri))
            ?.takeIf { it.matches(Regex("[A-Za-z0-9]+")) }

        val directory = File(context.cacheDir, PICKS_DIR)
        directory.deleteRecursively()
        if (!directory.isDirectory && !directory.mkdirs()) {
            throw IOException("Could not create ${directory.path}")
        }
        val target = File(directory, pickedFileName(displayName, mimeExtension))
        if (target.canonicalFile.parentFile != directory.canonicalFile) {
            throw IOException("The picked file name leaves ${directory.path}")
        }

        try {
            val input = resolver.openInputStream(uri)
                ?: throw IOException("The content provider returned no stream for the picked file.")
            input.use { source ->
                target.outputStream().use { sink -> source.copyTo(sink) }
            }
        } catch (e: Exception) {
            // A partial copy of a large file is not worth keeping until the next pick.
            target.delete()
            throw e
        }
        return target.path
    }

    /**
     * Names the copy the way `file_selector_android` does: the display name
     * with its extension replaced by the MIME type's.
     *
     * Callers read the file's type and title from this name (`XFile.name` is
     * the path's last segment), and some providers name audio by its title,
     * without an extension. Any path in the untrusted display name is dropped.
     */
    private fun pickedFileName(displayName: String?, mimeExtension: String?): String {
        val name = displayName?.substringAfterLast('/')?.replace("..", "_")
        if (name.isNullOrBlank()) {
            return if (mimeExtension == null) FALLBACK_BASE_NAME else "$FALLBACK_BASE_NAME.$mimeExtension"
        }
        if (mimeExtension == null) return name
        return "${name.substringBeforeLast('.')}.$mimeExtension"
    }
}
