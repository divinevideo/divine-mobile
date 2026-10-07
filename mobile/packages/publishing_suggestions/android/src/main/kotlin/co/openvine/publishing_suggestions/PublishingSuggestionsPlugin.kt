package co.openvine.publishing_suggestions

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.Content
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

/** Device model lifetime is independent of the Flutter method channel. */
internal interface PublishingModel : AutoCloseable {
    suspend fun status(): Int
    suspend fun prepare()
    suspend fun generate(prompt: String, frames: List<Bitmap>): String?
}

private class DevicePublishingModel : PublishingModel {
    private val model = Generation.getClient()
    override suspend fun status() = model.checkStatus()
    override suspend fun prepare() {
        model.download().collect { }
        check(model.checkStatus() == FeatureStatus.AVAILABLE)
    }
    override suspend fun generate(prompt: String, frames: List<Bitmap>): String? {
        val content = Content.Builder().text(prompt)
        frames.forEach { content.image(it) }
        val request = generateContentRequest(content.build()) { maxOutputTokens = 1024 }
        return model.generateContent(request).candidates.firstOrNull()?.text
    }
    override fun close() = model.close()
}

/** Each instance owns its cancellable on-device model session. */
class PublishingSuggestionsPlugin internal constructor(
    private val createModel: () -> PublishingModel,
) : FlutterPlugin, MethodChannel.MethodCallHandler {
    constructor() : this({ DevicePublishingModel() })

    private lateinit var channel: MethodChannel
    private var scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private var generation: Job? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        channel = MethodChannel(binding.binaryMessenger, "publishing_suggestions")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        scope.cancel()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "cancel") {
            generation?.cancel()
            generation = null
            result.success(null)
            return
        }
        if (call.method !in setOf("capabilities", "prepare", "generate")) {
            result.notImplemented()
            return
        }
        // ML Kit status is device-wide, not language-specific. Keep this opt-in
        // experiment English-only until other languages receive device evaluation.
        val language = call.argument<String>("language") ?: "en"
        val supportedLanguage = Locale.forLanguageTag(language.replace('_', '-')).language == "en"
        if (!supportedLanguage && call.method != "prepare") {
            if (call.method == "capabilities") {
                result.success(mapOf("availability" to "unavailable", "images" to false))
            } else {
                result.error("unavailable", "Local suggestions are unavailable", null)
            }
            return
        }
        if (call.method == "generate" || call.method == "prepare") generation?.cancel()
        val reply = ReplyOnce(result)
        val job = scope.launch {
            try {
                createModel().use { model ->
                    when (call.method) {
                        "capabilities" -> {
                            val status = when (model.status()) {
                                FeatureStatus.AVAILABLE -> "ready"
                                FeatureStatus.DOWNLOADABLE -> "downloadable"
                                FeatureStatus.DOWNLOADING -> "preparing"
                                else -> "unavailable"
                            }
                            reply.success(mapOf("availability" to status, "images" to (status == "ready")))
                        }
                        "prepare" -> {
                            model.prepare()
                            ensureActive()
                            reply.success(null)
                        }
                        "generate" -> {
                            val prompt = call.argument<String>("prompt") ?: error("Missing prompt")
                            val images = call.argument<List<ByteArray>>("frames").orEmpty().take(3)
                            val bitmaps = mutableListOf<Bitmap>()
                            try {
                                images.forEach { bytes ->
                                    bitmaps.add(BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
                                        ?: error("Invalid frame"))
                                }
                                val content = model.generate(prompt, bitmaps)
                                ensureActive()
                                reply.success(content)
                            } finally {
                                bitmaps.forEach { it.recycle() }
                            }
                        }
                    }
                }
            } catch (_: Exception) {
                reply.unavailable()
            }
        }
        // A job cancelled before its first dispatch never enters try/finally.
        // Complete that original channel call too; the gate prevents two replies.
        job.invokeOnCompletion { if (it != null) reply.unavailable() }
        if (call.method == "generate" || call.method == "prepare") generation = job
    }

    private class ReplyOnce(private val result: MethodChannel.Result) {
        private val completed = AtomicBoolean(false)
        fun success(value: Any?) {
            if (completed.compareAndSet(false, true)) result.success(value)
        }
        fun unavailable() {
            // Model errors can contain private source text; never forward them.
            if (completed.compareAndSet(false, true)) {
                result.error("unavailable", "Local suggestions are unavailable", null)
            }
        }
    }
}
